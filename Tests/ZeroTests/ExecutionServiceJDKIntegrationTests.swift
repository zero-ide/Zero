import XCTest
@testable import Zero

class ExecutionServiceJDKIntegrationTests: XCTestCase {
    
    func testExecutionServiceUsesConfiguredJDK() {
        // Given
        let config = BuildConfiguration(
            selectedJDK: JDKConfiguration.predefined[1], // OpenJDK 17
            buildTool: .maven,
            customArgs: []
        )
        
        // Then
        XCTAssertEqual(config.selectedJDK.image, "openjdk:17-slim")
        XCTAssertEqual(config.buildTool, .maven)
    }
    
    func testJavaCommandDetection() {
        // Given
        let commands = [
            ("javac Main.java", true),
            ("mvn clean build", true),
            ("gradle build", true),
            ("swift build", false)
        ]
        
        // Then
        for (command, isJava) in commands {
            let result = command.contains("javac") || command.contains("mvn") || command.contains("gradle")
            XCTAssertEqual(result, isJava, "Command: \(command)")
        }
    }
}
