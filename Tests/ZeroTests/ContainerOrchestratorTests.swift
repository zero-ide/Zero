import XCTest
@testable import Zero

// Mock implementations for testing
class MockDockerService: DockerServiceProtocol {
    var didRunContainer = false
    var lastContainerName: String?
    var lastImageName: String?
    var executedScripts: [String] = []
    
    // 호환성을 위한 계산 속성
    var executedScript: String? {
        return executedScripts.last
    }
    
    func checkInstallation() throws -> Bool { return true }
    
    func executeCommand(container: String, command: String) throws -> String {
        return "mock output"
    }
    
    func executeShell(container: String, script: String) throws -> String {
        executedScripts.append(script)
        return "mock shell output"
    }
    
    func runContainer(image: String, name: String) throws -> String {
        didRunContainer = true
        lastContainerName = name
        lastImageName = image
        return "container-id-123"
    }
    
    func listFiles(container: String, path: String) throws -> String { return "" }
    func readFile(container: String, path: String) throws -> String { return "" }
    func writeFile(container: String, path: String, content: String) throws {}
    func stopContainer(name: String) throws {}
    func removeContainer(name: String) throws {}
    func fileExists(container: String, path: String) throws -> Bool { return true }
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
        XCTAssertEqual(mockDocker.lastImageName, "alpine:latest")
        
        // Git 설치 확인 (Alpine: apk add)
        XCTAssertTrue(mockDocker.executedScripts.contains { $0.contains("apk add --no-cache git") })
        
        XCTAssertNotNil(session)
        XCTAssertEqual(session.repoURL, repo.cloneURL)
        
        // Session should be saved
        let sessions = try sessionManager.loadSessions()
        XCTAssertEqual(sessions.count, 1)
    }
}
