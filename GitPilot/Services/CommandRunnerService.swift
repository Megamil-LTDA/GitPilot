//
//  CommandRunnerService.swift
//  GitPilot
//
//  Copyright (c) 2024 Megamil
//  Contact: eduardo@megamil.com.br
//

import Foundation

/// Service for running shell commands with streaming output support
actor CommandRunnerService {
    static let shared = CommandRunnerService()
    
    private var runningProcesses: [UUID: Process] = [:]
    
    private init() {}
    
    /// Run a shell command with streaming output callback
    func run(command: String, at workingDirectory: String, timeout: TimeInterval = 3600, onOutput: ((String) -> Void)? = nil) async throws -> CommandResult {
        let processId = UUID()
        
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        // Use login shell (-l) to load user's .zshrc/.zprofile with all PATH and aliases
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", command]
        process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        // Inherit full environment from user
        var environment = ProcessInfo.processInfo.environment
        
        // Ensure critical paths are present
        let homePath = environment["HOME"] ?? "/Users/\(NSUserName())"
        
        // Force common paths to be available even if shell init fails to set them
        var currentPath = environment["PATH"] ?? ""
        let requiredPaths = [
            // Flutter / FVM
            "\(homePath)/fvm/default/bin",
            "\(homePath)/.pub-cache/bin",
            "\(homePath)/flutter/bin",
            "\(homePath)/development/flutter/bin",
            "/opt/flutter/bin",
            // Homebrew
            "/opt/homebrew/bin",
            "/opt/homebrew/sbin",
            "/usr/local/bin",
            // System
            "/usr/bin",
            "/bin",  
            "/usr/sbin",
            "/sbin",
            // Other tools
            "\(homePath)/.bun/bin",
            "\(homePath)/.cargo/bin",
            "\(homePath)/.rbenv/shims",
            "\(homePath)/.gem/ruby/3.0.0/bin",
            "/usr/local/opt/ruby/bin"
        ]
        
        for path in requiredPaths {
            if !currentPath.contains(path) {
                currentPath = path + ":" + currentPath
            }
        }
        environment["PATH"] = currentPath
        
        // Pass SSH_AUTH_SOCK to allow git operations using SSH agent if available in env
        // (Note: MacOS apps started from Finder often don't inherit this, running from terminal helps)
        if environment["SSH_AUTH_SOCK"] == nil {
            // Try common locations? No, usually useless.
        }
    
        process.environment = environment
        
        runningProcesses[processId] = process
        
        defer {
            runningProcesses.removeValue(forKey: processId)
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            var outputData = Data()
            var errorData = Data()
            
            // Queue for thread-safe data access
            let dataQueue = DispatchQueue(label: "com.megamil.gitpilot.command.output", qos: .userInitiated)
            
            // Read output asynchronously with streaming
            outputPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty {
                    dataQueue.async {
                        outputData.append(data)
                        // Stream to callback on main thread
                        if let callback = onOutput, let text = String(data: data, encoding: .utf8) {
                            DispatchQueue.main.async { callback(text) }
                        }
                    }
                }
            }
            
            errorPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty {
                    dataQueue.async {
                        errorData.append(data)
                        // Stream errors too
                        if let callback = onOutput, let text = String(data: data, encoding: .utf8) {
                            DispatchQueue.main.async { callback(text) }
                        }
                    }
                }
            }
            
            process.terminationHandler = { [weak self] _ in
                // Stop handlers first
                outputPipe.fileHandleForReading.readabilityHandler = nil
                errorPipe.fileHandleForReading.readabilityHandler = nil
                
                // Read remaining data in background to avoid blocking
                DispatchQueue.global(qos: .userInitiated).async {
                    // Small delay to let handlers finish processing
                    Thread.sleep(forTimeInterval: 0.1)
                    
                    let remainingOutput = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let remainingError = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    
                    dataQueue.async {
                        outputData.append(remainingOutput)
                        errorData.append(remainingError)
                        
                        // Stream remaining output (but don't overwhelm main thread)
                        if let callback = onOutput {
                            if let text = String(data: remainingOutput, encoding: .utf8), !text.isEmpty {
                                DispatchQueue.main.async { callback(text) }
                            }
                            if let text = String(data: remainingError, encoding: .utf8), !text.isEmpty {
                                DispatchQueue.main.async { callback(text) }
                            }
                        }
                        
                        let output = String(data: outputData, encoding: .utf8) ?? ""
                        let error = String(data: errorData, encoding: .utf8) ?? ""
                        
                        let fullOutput = (output + (error.isEmpty ? "" : "\nError Output:\n" + error)).trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        let finalOutput = fullOutput.isEmpty ? "[No output captured]" : fullOutput
                        
                        let result = CommandResult(
                            output: finalOutput,
                            exitCode: Int(process.terminationStatus)
                        )
                        
                        continuation.resume(returning: result)
                    }
                }
            }
            
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: CommandError.launchFailed(error.localizedDescription))
            }
        }
    }
    
    /// Cancel a running process
    func cancel(processId: UUID) {
        runningProcesses[processId]?.terminate()
    }
    
    /// Cancel all running processes
    func cancelAll() {
        for (_, process) in runningProcesses {
            process.terminate()
        }
        runningProcesses.removeAll()
    }
}

/// Result of a command execution
struct CommandResult {
    let output: String
    let exitCode: Int
    
    var isSuccess: Bool { exitCode == 0 }
}

/// Command execution errors
enum CommandError: LocalizedError {
    case launchFailed(String)
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .launchFailed(let reason):
            return "Failed to launch command: \(reason)"
        case .timeout:
            return "Command timed out"
        }
    }
}
