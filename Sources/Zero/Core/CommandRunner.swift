import Foundation

enum CommandRunnerError: LocalizedError {
    case commandFailed(command: String, arguments: [String], exitCode: Int, output: String)

    var errorDescription: String? {
        switch self {
        case .commandFailed(_, _, let exitCode, let output):
            let trimmedOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedOutput.isEmpty {
                return "Command failed with exit code \(exitCode)."
            }
            return trimmedOutput
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
        let pipe = Pipe()
        let dataLock = NSLock()
        var outputData = Data()
        
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe

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

        let fileHandle = pipe.fileHandleForReading
        fileHandle.readabilityHandler = { handle in
            let chunkData = handle.availableData
            guard !chunkData.isEmpty else { return }

            dataLock.lock()
            outputData.append(chunkData)
            dataLock.unlock()

            if let chunk = String(data: chunkData, encoding: .utf8), !chunk.isEmpty {
                onOutput(chunk)
            }
        }
        
        try process.run()
        process.waitUntilExit()

        fileHandle.readabilityHandler = nil

        let trailingData = fileHandle.readDataToEndOfFile()
        if !trailingData.isEmpty {
            dataLock.lock()
            outputData.append(trailingData)
            dataLock.unlock()

            if let trailingChunk = String(data: trailingData, encoding: .utf8), !trailingChunk.isEmpty {
                onOutput(trailingChunk)
            }
        }
        
        let output = String(data: outputData, encoding: .utf8) ?? ""
        
        if process.terminationStatus != 0 {
            throw CommandRunnerError.commandFailed(
                command: command,
                arguments: arguments,
                exitCode: Int(process.terminationStatus),
                output: output
            )
        }
        
        return output
    }

    func cancelCurrentCommand() {
        processLock.lock()
        let process = currentProcess
        processLock.unlock()

        process?.terminate()
    }
}
