import XCTest
@testable import Zero

// Mock implementations for testing
class MockDockerService: DockerRunning, ContainerRunning {
    var didRunContainer = false
    var lastContainerName: String?
    
    func executeCommand(container: String, command: String) throws -> String {
        return "mock output"
    }
    
    func executeShell(container: String, script: String) throws -> String {
        return "mock shell output"
    }
    
    func runContainer(image: String, name: String) throws -> String {
        didRunContainer = true
        lastContainerName = name
        return "container-id-123"
    }
}

final class ContainerOrchestratorTests: XCTestCase {
    
    var testStoreURL: URL!
    
    override func setUp() {
        super.setUp()
        testStoreURL = FileManager.default.temporaryDirectory.appendingPathComponent("orchestrator_test.json")
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: testStoreURL)
        super.tearDown()
    }
    
    func testStartSessionCreatesContainerAndClonesRepo() async throws {
        // Given
        let mockDocker = MockDockerService()
        let sessionManager = SessionManager(storeURL: testStoreURL)
        let orchestrator = ContainerOrchestrator(
            dockerService: mockDocker,
            sessionManager: sessionManager
        )
        
        let repo = Repository(
            id: 1,
            name: "test-repo",
            fullName: "user/test-repo",
            isPrivate: false,
            htmlURL: URL(string: "https://github.com/user/test-repo")!,
            cloneURL: URL(string: "https://github.com/user/test-repo.git")!
        )
        let token = "ghp_test_token"
        
        // When
        let session = try await orchestrator.startSession(repo: repo, token: token)
        
        // Then
        XCTAssertTrue(mockDocker.didRunContainer)
        XCTAssertNotNil(session)
        XCTAssertEqual(session.repoURL, repo.cloneURL)
        
        // Session should be saved
        let sessions = try sessionManager.loadSessions()
        XCTAssertEqual(sessions.count, 1)
    }
}
