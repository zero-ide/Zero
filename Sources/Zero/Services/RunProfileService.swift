import Foundation

protocol RunProfileService {
    func save(command: String, for repositoryURL: URL) throws
    func loadCommand(for repositoryURL: URL) throws -> String?
    func removeCommand(for repositoryURL: URL) throws
}

enum RunProfileServiceError: Error {
    case encodingFailed
    case decodingFailed
}

private struct RunProfileStore: Codable {
    let commandsByRepository: [String: String]
}

class FileBasedRunProfileService: RunProfileService {
    private let configPath: String

    init(configPath: String = "~/.zero/run-profiles.json") {
        self.configPath = (configPath as NSString).expandingTildeInPath
    }

    func save(command: String, for repositoryURL: URL) throws {
        var commands = try loadCommands()
        commands[repositoryKey(for: repositoryURL)] = command
        try writeCommands(commands)
    }

    func loadCommand(for repositoryURL: URL) throws -> String? {
        let commands = try loadCommands()
        return commands[repositoryKey(for: repositoryURL)]
    }

    func removeCommand(for repositoryURL: URL) throws {
        var commands = try loadCommands()
        commands.removeValue(forKey: repositoryKey(for: repositoryURL))
        try writeCommands(commands)
    }

    private func loadCommands() throws -> [String: String] {
        let url = URL(fileURLWithPath: configPath)

        guard FileManager.default.fileExists(atPath: configPath) else {
            return [:]
        }

        let data = try Data(contentsOf: url)
        guard !data.isEmpty else {
            return [:]
        }

        guard let store = try? JSONDecoder().decode(RunProfileStore.self, from: data) else {
            throw RunProfileServiceError.decodingFailed
        }

        return store.commandsByRepository
    }

    private func writeCommands(_ commands: [String: String]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        guard let data = try? encoder.encode(RunProfileStore(commandsByRepository: commands)) else {
            throw RunProfileServiceError.encodingFailed
        }

        let url = URL(fileURLWithPath: configPath)
        let directory = url.deletingLastPathComponent()

        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        try data.write(to: url)
    }

    private func repositoryKey(for repositoryURL: URL) -> String {
        repositoryURL.absoluteString
    }
}
