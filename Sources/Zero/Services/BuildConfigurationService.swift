import Foundation

protocol BuildConfigurationService {
    func save(_ config: BuildConfiguration) throws
    func load() throws -> BuildConfiguration
    func reset() throws
}

enum BuildConfigurationError: Error {
    case encodingFailed
    case decodingFailed
    case saveFailed
    case loadFailed
}

class FileBasedBuildConfigurationService: BuildConfigurationService {
    private let configPath: String
    
    init(configPath: String = "~/.zero/build-config.json") {
        self.configPath = (configPath as NSString).expandingTildeInPath
    }
    
    func save(_ config: BuildConfiguration) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        guard let data = try? encoder.encode(config) else {
            throw BuildConfigurationError.encodingFailed
        }
        
        let url = URL(fileURLWithPath: configPath)
        let directory = url.deletingLastPathComponent()
        
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        
        try data.write(to: url)
    }
    
    func load() throws -> BuildConfiguration {
        let url = URL(fileURLWithPath: configPath)
        
        guard FileManager.default.fileExists(atPath: configPath),
              let data = try? Data(contentsOf: url) else {
            return .default
        }
        
        guard let config = try? JSONDecoder().decode(BuildConfiguration.self, from: data) else {
            throw BuildConfigurationError.decodingFailed
        }
        
        return config
    }
    
    func reset() throws {
        try save(.default)
    }
}
