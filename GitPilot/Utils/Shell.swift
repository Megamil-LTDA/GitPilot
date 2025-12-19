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
    static func run(_ command: String, at path: String? = nil, timeout: TimeInterval = 30) async throws -> ShellResult {
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
            var outputData = Data()
            var errorData = Data()
            var hasResumed = false
            let lock = NSLock()
            
            // Use non-blocking reading to avoid hangs
            let dataQueue = DispatchQueue(label: "com.megamil.gitpilot.shell.data", qos: .userInitiated)
            
            outputPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty {
                    dataQueue.sync { outputData.append(data) }
                }
            }
            
            errorPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty {
                    dataQueue.sync { errorData.append(data) }
                }
            }
            
            process.terminationHandler = { _ in
                // Stop reading handlers
                outputPipe.fileHandleForReading.readabilityHandler = nil
                errorPipe.fileHandleForReading.readabilityHandler = nil
                
                // Small delay then read remaining data
                dataQueue.asyncAfter(deadline: .now() + 0.05) {
                    // Safely read remaining - with very short timeout approach
                    if let remainingOutput = try? outputPipe.fileHandleForReading.availableData, !remainingOutput.isEmpty {
                        outputData.append(remainingOutput)
                    }
                    if let remainingError = try? errorPipe.fileHandleForReading.availableData, !remainingError.isEmpty {
                        errorData.append(remainingError)
                    }
                    
                    let result = ShellResult(
                        output: String(data: outputData, encoding: .utf8) ?? "",
                        error: String(data: errorData, encoding: .utf8) ?? "",
                        exitCode: Int(process.terminationStatus)
                    )
                    
                    lock.lock()
                    if !hasResumed {
                        hasResumed = true
                        lock.unlock()
                        continuation.resume(returning: result)
                    } else {
                        lock.unlock()
                    }
                }
            }
            
            // Timeout to prevent infinite hangs
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                lock.lock()
                if !hasResumed && process.isRunning {
                    hasResumed = true
                    lock.unlock()
                    process.terminate()
                    continuation.resume(throwing: ShellError.timeout)
                } else {
                    lock.unlock()
                }
            }
            
            do {
                try process.run()
            } catch {
                lock.lock()
                if !hasResumed {
                    hasResumed = true
                    lock.unlock()
                    continuation.resume(throwing: ShellError.launchFailed(error.localizedDescription))
                } else {
                    lock.unlock()
                }
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
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .launchFailed(let reason):
            return "Failed to launch shell: \(reason)"
        case .timeout:
            return "Command timed out"
        }
    }
}
