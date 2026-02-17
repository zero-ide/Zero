import XCTest
@testable import Zero

// Mock implementations for testing
class MockDockerService: DockerServiceProtocol {
    var didRunContainer = false
    var lastContainerName: String?
    var lastImageName: String?
    var executedScripts: [String] = []
    var shellErrorsByCommandSubstring: [String: Error] = [:]
    
    // 호환성을 위한 계산 속성
    var executedScript: String? {
        return executedScripts.last
    }
    
    func checkInstallation() throws -> Bool { return true }
    
    func executeCommand(container: String, command: String) throws -> String {
        return "mock output"
    }
    
    func executeShell(container: String, script: String) throws -> String {
        if let match = shellErrorsByCommandSubstring.first(where: { script.contains($0.key) }) {
            throw match.value
        }
        executedScripts.append(script)
        return "mock shell output"
    }

    func executeShellStreaming(container: String, script: String, onOutput: @escaping (String) -> Void) throws -> String {
        if let match = shellErrorsByCommandSubstring.first(where: { script.contains($0.key) }) {
            throw match.value
        }
        executedScripts.append(script)
        let output = "mock shell output"
        onOutput(output)
        return output
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
    func ensureDirectory(container: String, path: String) throws {}
    func rename(container: String, from: String, to: String) throws {}
    func remove(container: String, path: String, recursive: Bool) throws {}
    func stopContainer(name: String) throws {}
    func removeContainer(name: String) throws {}
    func fileExists(container: String, path: String) throws -> Bool { return true }
    func cancelCurrentExecution() {}
}

final class ContainerOrchestratorTests: XCTestCase {
    
    var testStoreURL: URL!
    
    override func setUp() {
        super.setUp()
        testStoreURL = FileManager.default.temporaryDirectory.appendingPathComponent("orchestrator_test.json")
        AppLogStore.shared.clear()
    }
    
    override func tearDown() {
        AppLogStore.shared.clear()
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

    func testStartSessionLogsGitInstallFailureAndContinues() async throws {
        // Given
        let mockDocker = MockDockerService()
        mockDocker.shellErrorsByCommandSubstring["apk add --no-cache git"] = NSError(
            domain: "docker",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "apk failed: temporary network error"]
        )
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

        // When
        let session = try await orchestrator.startSession(repo: repo, token: "ghp_test_token")

        // Then
        XCTAssertEqual(session.repoURL, repo.cloneURL)
        let logs = AppLogStore.shared.recentEntries()
        XCTAssertTrue(logs.contains { entry in
            entry.contains("ContainerOrchestrator git install failed") && entry.contains("apk failed")
        })
    }
}
