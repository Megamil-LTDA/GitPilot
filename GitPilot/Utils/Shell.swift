//
//  Shell.swift
//  GitPilot
//
//  Created with ❤️ for the open-source community
//  Licensed under MIT License
//

import Foundation

/// Utility for running shell commands
enum Shell {
    
    /// Run a shell command and return the result
    static func run(_ command: String, at path: String? = nil) async throws -> ShellResult {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        
        if let path = path {
            process.currentDirectoryURL = URL(fileURLWithPath: path)
        }
        
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        // Set up environment with common paths
        var environment = ProcessInfo.processInfo.environment
        let additionalPaths = [
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin",
            "/opt/homebrew/bin",
            "/opt/homebrew/sbin"
        ]
        let existingPath = environment["PATH"] ?? ""
        environment["PATH"] = (additionalPaths + [existingPath]).joined(separator: ":")
        process.environment = environment
        
        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { _ in
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                
                let output = String(data: outputData, encoding: .utf8) ?? ""
                let error = String(data: errorData, encoding: .utf8) ?? ""
                
                let result = ShellResult(
                    output: output,
                    error: error,
                    exitCode: Int(process.terminationStatus)
                )
                
                continuation.resume(returning: result)
            }
            
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: ShellError.launchFailed(error.localizedDescription))
            }
        }
    }
    
    /// Run a command synchronously (blocking)
    static func runSync(_ command: String, at path: String? = nil) throws -> ShellResult {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        
        if let path = path {
            process.currentDirectoryURL = URL(fileURLWithPath: path)
        }
        
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        try process.run()
        process.waitUntilExit()
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        
        return ShellResult(
            output: String(data: outputData, encoding: .utf8) ?? "",
            error: String(data: errorData, encoding: .utf8) ?? "",
            exitCode: Int(process.terminationStatus)
        )
    }
    
    /// Check if a command exists
    static func commandExists(_ command: String) async -> Bool {
        do {
            let result = try await run("which \(command)")
            return result.exitCode == 0
        } catch {
            return false
        }
    }
}

/// Result of a shell command
struct ShellResult {
    let output: String
    let error: String
    let exitCode: Int
    
    var isSuccess: Bool { exitCode == 0 }
    
    var combinedOutput: String {
        if error.isEmpty {
            return output
        } else if output.isEmpty {
            return error
        } else {
            return output + "\n" + error
        }
    }
}

/// Shell execution errors
enum ShellError: LocalizedError {
    case launchFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .launchFailed(let reason):
            return "Failed to launch shell: \(reason)"
        }
    }
}
