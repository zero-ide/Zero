import Foundation

struct JDKConfiguration: Codable, Identifiable, Equatable {
    let id: UUID
    let name: String
    let image: String
    let version: String
    let isCustom: Bool
    
    init(id: UUID, name: String, image: String, version: String, isCustom: Bool) {
        self.id = id
        self.name = name
        self.image = image
        self.version = version
        self.isCustom = isCustom
    }
}

extension JDKConfiguration {
    static let predefined: [JDKConfiguration] = [
        JDKConfiguration(id: UUID(), name: "OpenJDK 21", image: "openjdk:21-slim", version: "21", isCustom: false),
        JDKConfiguration(id: UUID(), name: "OpenJDK 17", image: "openjdk:17-slim", version: "17", isCustom: false),
        JDKConfiguration(id: UUID(), name: "OpenJDK 11", image: "openjdk:11-slim", version: "11", isCustom: false),
        JDKConfiguration(id: UUID(), name: "Eclipse Temurin 21", image: "eclipse-temurin:21-jdk", version: "21", isCustom: false),
        JDKConfiguration(id: UUID(), name: "Amazon Corretto 21", image: "amazoncorretto:21", version: "21", isCustom: false),
    ]
}

struct BuildConfiguration: Codable, Equatable {
    var selectedJDK: JDKConfiguration
    var buildTool: BuildTool
    var customArgs: [String]
    
    enum BuildTool: String, Codable, Equatable {
        case javac, maven, gradle
    }
    
    init(selectedJDK: JDKConfiguration, buildTool: BuildTool, customArgs: [String]) {
        self.selectedJDK = selectedJDK
        self.buildTool = buildTool
        self.customArgs = customArgs
    }
}

extension BuildConfiguration {
    static var `default`: BuildConfiguration {
        BuildConfiguration(
            selectedJDK: JDKConfiguration.predefined[0],
            buildTool: .javac,
            customArgs: []
        )
    }
}
