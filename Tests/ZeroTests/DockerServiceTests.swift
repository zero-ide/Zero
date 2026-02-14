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

    func executeStreaming(command: String, arguments: [String], onOutput: @escaping (String) -> Void) throws -> String {
        self.executedCommand = command
        self.executedArguments = arguments
        onOutput(mockOutput)
        return mockOutput
    }

    func cancelCurrentCommand() {}
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
        // 컨테이너가 계속 살아있도록 keep-alive 명령어 필요
        XCTAssertTrue(mockRunner.executedArguments!.contains("tail"))
        XCTAssertTrue(mockRunner.executedArguments!.contains("-f"))
        XCTAssertTrue(mockRunner.executedArguments!.contains("/dev/null"))
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

    func testExecuteShell() throws {
        // Given
        let mockRunner = MockCommandRunner()
        mockRunner.mockOutput = "success"
        let service = DockerService(runner: mockRunner)
        
        // When
        let script = "mkdir -p /workspace && cd /workspace"
        _ = try service.executeShell(container: "zero-dev", script: script)
        
        // Then
        // ["exec", "zero-dev", "sh", "-c", "mkdir -p /workspace && cd /workspace"]
        XCTAssertEqual(mockRunner.executedArguments?[0], "exec")
        XCTAssertEqual(mockRunner.executedArguments?[1], "zero-dev")
        XCTAssertEqual(mockRunner.executedArguments?[2], "sh")
        XCTAssertEqual(mockRunner.executedArguments?[3], "-c")
        XCTAssertEqual(mockRunner.executedArguments?[4], script)
    }
}
