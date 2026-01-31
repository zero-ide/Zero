import XCTest
@testable import Zero

class JDKConfigurationTests: XCTestCase {
    
    func testJDKConfigurationInitialization() {
        // Given
        let id = UUID()
        let name = "OpenJDK 21"
        let image = "openjdk:21-slim"
        let version = "21"
        
        // When
        let config = JDKConfiguration(
            id: id,
            name: name,
            image: image,
            version: version,
            isCustom: false
        )
        
        // Then
        XCTAssertEqual(config.id, id)
        XCTAssertEqual(config.name, name)
        XCTAssertEqual(config.image, image)
        XCTAssertEqual(config.version, version)
        XCTAssertFalse(config.isCustom)
    }
    
    func testJDKConfigurationPredefined() {
        // When
        let predefined = JDKConfiguration.predefined
        
        // Then
        XCTAssertFalse(predefined.isEmpty)
        XCTAssertTrue(predefined.contains { $0.name == "OpenJDK 21" })
        XCTAssertTrue(predefined.contains { $0.name == "OpenJDK 17" })
        XCTAssertTrue(predefined.contains { $0.name == "Eclipse Temurin 21" })
    }
    
    func testJDKConfigurationCodable() throws {
        // Given
        let config = JDKConfiguration(
            id: UUID(),
            name: "Test JDK",
            image: "test:21",
            version: "21",
            isCustom: true
        )
        
        // When
        let encoded = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(JDKConfiguration.self, from: encoded)
        
        // Then
        XCTAssertEqual(config.id, decoded.id)
        XCTAssertEqual(config.name, decoded.name)
        XCTAssertEqual(config.image, decoded.image)
        XCTAssertEqual(config.version, decoded.version)
        XCTAssertEqual(config.isCustom, decoded.isCustom)
    }
}

class BuildConfigurationTests: XCTestCase {
    
    func testBuildConfigurationInitialization() {
        // Given
        let jdk = JDKConfiguration.predefined[0]
        
        // When
        let config = BuildConfiguration(
            selectedJDK: jdk,
            buildTool: .maven,
            customArgs: ["-Xmx2g"]
        )
        
        // Then
        XCTAssertEqual(config.selectedJDK.id, jdk.id)
        XCTAssertEqual(config.buildTool, .maven)
        XCTAssertEqual(config.customArgs, ["-Xmx2g"])
    }
    
    func testBuildConfigurationDefault() {
        // When
        let config = BuildConfiguration.default
        
        // Then
        XCTAssertEqual(config.buildTool, .javac)
        XCTAssertTrue(config.customArgs.isEmpty)
    }
    
    func testBuildConfigurationCodable() throws {
        // Given
        let config = BuildConfiguration(
            selectedJDK: JDKConfiguration.predefined[0],
            buildTool: .gradle,
            customArgs: []
        )
        
        // When
        let encoded = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(BuildConfiguration.self, from: encoded)
        
        // Then
        XCTAssertEqual(config.selectedJDK.id, decoded.selectedJDK.id)
        XCTAssertEqual(config.buildTool, decoded.buildTool)
        XCTAssertEqual(config.customArgs, decoded.customArgs)
    }
}
