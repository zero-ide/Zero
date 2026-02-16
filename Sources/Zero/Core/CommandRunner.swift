import Foundation

enum CommandRunnerError: LocalizedError {
    case commandFailed(command: String, arguments: [String], exitCode: Int, stdout: String, stderr: String)

    var errorDescription: String? {
        switch self {
        case .commandFailed(_, _, let exitCode, let stdout, let stderr):
            let trimmedStderr = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedStderr.isEmpty {
                return trimmedStderr
            }

            let trimmedStdout = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedStdout.isEmpty {
                return "Command failed with exit code \(exitCode)."
            }
            return trimmedStdout
        }
    }
}

protocol CommandRunning {
    func execute(command: String, arguments: [String]) throws -> String
    func executeStreaming(command: String, arguments: [String], onOutput: @escaping (String) -> Void) throws -> String
    func cancelCurrentCommand()
}

final class CommandRunner: CommandRunning {
    private let processLock = NSLock()
    private var currentProcess: Process?

    func execute(command: String, arguments: [String] = []) throws -> String {
        try executeStreaming(command: command, arguments: arguments) { _ in }
    }

    func executeStreaming(command: String, arguments: [String] = [], onOutput: @escaping (String) -> Void) throws -> String {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        let dataLock = NSLock()
        var stdoutData = Data()
        var stderrData = Data()
        
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        processLock.lock()
        currentProcess = process
        processLock.unlock()
        defer {
            processLock.lock()
            if currentProcess === process {
                currentProcess = nil
            }
            processLock.unlock()
        }

        let stdoutHandle = stdoutPipe.fileHandleForReading
        let stderrHandle = stderrPipe.fileHandleForReading

        stdoutHandle.readabilityHandler = { handle in
            let chunkData = handle.availableData
            guard !chunkData.isEmpty else { return }

            dataLock.lock()
            stdoutData.append(chunkData)
            dataLock.unlock()

            if let chunk = String(data: chunkData, encoding: .utf8), !chunk.isEmpty {
                onOutput(chunk)
            }
        }

        stderrHandle.readabilityHandler = { handle in
            let chunkData = handle.availableData
            guard !chunkData.isEmpty else { return }

            dataLock.lock()
            stderrData.append(chunkData)
            dataLock.unlock()

            if let chunk = String(data: chunkData, encoding: .utf8), !chunk.isEmpty {
                onOutput(chunk)
            }
        }
        
        try process.run()
        process.waitUntilExit()

        stdoutHandle.readabilityHandler = nil
        stderrHandle.readabilityHandler = nil

        let trailingStdout = stdoutHandle.readDataToEndOfFile()
        if !trailingStdout.isEmpty {
            dataLock.lock()
            stdoutData.append(trailingStdout)
            dataLock.unlock()

            if let trailingChunk = String(data: trailingStdout, encoding: .utf8), !trailingChunk.isEmpty {
                onOutput(trailingChunk)
            }
        }

        let trailingStderr = stderrHandle.readDataToEndOfFile()
        if !trailingStderr.isEmpty {
            dataLock.lock()
            stderrData.append(trailingStderr)
            dataLock.unlock()

            if let trailingChunk = String(data: trailingStderr, encoding: .utf8), !trailingChunk.isEmpty {
                onOutput(trailingChunk)
            }
        }
        
        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""
        
        if process.terminationStatus != 0 {
            throw CommandRunnerError.commandFailed(
                command: command,
                arguments: arguments,
                exitCode: Int(process.terminationStatus),
                stdout: stdout,
                stderr: stderr
            )
        }
        
        return stdout + stderr
    }

    func cancelCurrentCommand() {
        processLock.lock()
        let process = currentProcess
        processLock.unlock()

        process?.terminate()
    }
}
