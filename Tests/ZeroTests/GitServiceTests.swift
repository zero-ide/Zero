import XCTest
@testable import Zero

// Mock for DockerService (Dependency Injection)
class MockContainerRunner: ContainerRunning {
    var executedContainer: String?
    var executedCommand: String?
    var executedScript: String?
    
    func executeCommand(container: String, command: String) throws -> String {
        self.executedContainer = container
        self.executedCommand = command
        return "Cloning into..."
    }
    
    func executeShell(container: String, script: String) throws -> String {
        self.executedContainer = container
        self.executedScript = script
        return "Shell script executed"
    }
}

final class GitServiceTests: XCTestCase {
    func testCloneRepository() throws {
        // Given
        let mockRunner = MockContainerRunner()
        let service = GitService(runner: mockRunner)
        let repoURL = URL(string: "https://github.com/zero-ide/Zero.git")!
        let token = "ghp_secret_token"
        let containerName = "zero-dev-container"
        
        // When
        try service.clone(repoURL: repoURL, token: token, to: containerName)
        
        // Then
        XCTAssertEqual(mockRunner.executedContainer, containerName)
        
        // 토큰이 포함된 URL이 명령어로 전달되었는지 확인
        let command = mockRunner.executedScript ?? ""
        XCTAssertTrue(command.contains("x-access-token:ghp_secret_token@github.com/zero-ide/Zero.git"))
        
        // /workspace 디렉토리에 clone되는지 확인
        XCTAssertTrue(command.contains("/workspace"), "Clone should target /workspace directory")
        XCTAssertTrue(command.contains("mkdir -p /workspace"), "Should create directory")
    }
}
