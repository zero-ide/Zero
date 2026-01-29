import XCTest
@testable import Zero

// Mock for DockerService (Dependency Injection)
class MockContainerRunner: ContainerRunning {
    var executedContainer: String?
    var executedCommand: String?
    
    func executeCommand(container: String, command: String) throws -> String {
        self.executedContainer = container
        self.executedCommand = command
        return "Cloning into..."
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
        // https://x-access-token:ghp_secret_token@github.com/zero-ide/Zero.git
        let expectedCommandStart = "git clone https://x-access-token:ghp_secret_token@github.com/zero-ide/Zero.git"
        XCTAssertTrue(mockRunner.executedCommand?.starts(with: expectedCommandStart) ?? false)
    }
}
