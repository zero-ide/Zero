import XCTest
@testable import Zero

// Mock 객체
class MockCommandRunner: CommandRunning {
    var executedCommand: String?
    var executedArguments: [String]?
    var mockOutput: String = ""
    
    func execute(command: String, arguments: [String]) throws -> String {
        self.executedCommand = command
        self.executedArguments = arguments
        return mockOutput
    }
}

final class DockerServiceTests: XCTestCase {
    
    func testCheckDockerInstallation() throws {
        // Given
        let mockRunner = MockCommandRunner()
        mockRunner.mockOutput = "Docker version 20.10.12, build e91ed57"
        let service = DockerService(runner: mockRunner)
        
        // When
        let isInstalled = try service.checkInstallation()
        
        // Then
        XCTAssertTrue(isInstalled)
        XCTAssertEqual(mockRunner.executedCommand, "/usr/local/bin/docker")
        XCTAssertEqual(mockRunner.executedArguments, ["--version"])
    }
    
    func testRunContainer() throws {
        // Given
        let mockRunner = MockCommandRunner()
        mockRunner.mockOutput = "container-id-12345"
        let service = DockerService(runner: mockRunner)
        
        // When
        let containerID = try service.runContainer(image: "ubuntu:latest", name: "zero-dev")
        
        // Then
        XCTAssertEqual(containerID.trimmingCharacters(in: .whitespacesAndNewlines), "container-id-12345")
        XCTAssertEqual(mockRunner.executedArguments?.first, "run")
        XCTAssertTrue(mockRunner.executedArguments!.contains("--rm")) // 휘발성 확인
        XCTAssertTrue(mockRunner.executedArguments!.contains("zero-dev"))
        XCTAssertTrue(mockRunner.executedArguments!.contains("ubuntu:latest"))
    }
}
