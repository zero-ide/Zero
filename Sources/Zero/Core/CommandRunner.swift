import Foundation

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
            // 에러 발생 시 throw
            throw NSError(domain: "CommandRunner", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: output])
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
