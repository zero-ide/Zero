import Foundation

protocol CommandRunning {
    func execute(command: String, arguments: [String]) throws -> String
    func cancelCurrentCommand()
}

final class CommandRunner: CommandRunning {
    private let processLock = NSLock()
    private var currentProcess: Process?

    func execute(command: String, arguments: [String] = []) throws -> String {
        let process = Process()
        let pipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments
        process.standardOutput = pipe

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
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
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
