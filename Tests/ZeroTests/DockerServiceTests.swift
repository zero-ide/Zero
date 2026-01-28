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
    
    func testExecuteCommand() throws {
        // Given
        let mockRunner = MockCommandRunner()
        mockRunner.mockOutput = "git version 2.39.0"
        let service = DockerService(runner: mockRunner)
        
        // When
        let output = try service.executeCommand(container: "zero-dev", command: "git --version")
        
        // Then
        XCTAssertEqual(output, "git version 2.39.0")
        XCTAssertEqual(mockRunner.executedArguments?[0], "exec")
        XCTAssertEqual(mockRunner.executedArguments?[1], "zero-dev")
        // "git --version"이 하나의 인자로 전달되는지, 분리되는지는 구현에 따라 다름 (여기선 sh -c 로 감싸거나 직접 전달)
        // 일단 단순 전달 가정
    }
}
