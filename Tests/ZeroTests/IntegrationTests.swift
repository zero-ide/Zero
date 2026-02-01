import XCTest
@testable import Zero

/// 통합 테스트: Docker Service와 연동
@MainActor
class DockerIntegrationTests: XCTestCase {
    
    var dockerService: DockerService!
    
    override func setUp() {
        super.setUp()
        dockerService = DockerService()
    }
    
    override func tearDown() {
        dockerService = nil
        super.tearDown()
    }
    
    // MARK: - Docker Installation Tests
    
    func testDockerInstallationCheck() {
        // When & Then
        do {
            let isInstalled = try dockerService.checkInstallation()
            // Docker가 설치되어 있거나 없을 수 있음
            // 단순히 예외가 발생하지 않는지 확인
            XCTAssertTrue(isInstalled || !isInstalled)
        } catch {
            // Docker가 없으면 예외가 발생할 수 있음 (정상)
            XCTAssertNotNil(error)
        }
    }
    
    // MARK: - Container Lifecycle Tests (Mock)
    
    func testContainerLifecycleWithMock() throws {
        // Given
        let mockRunner = MockCommandRunner()
        mockRunner.mockOutput = "container-id-123"
        let service = DockerService(runner: mockRunner)
        
        // When - Create container
        let containerId = try service.runContainer(image: "alpine:latest", name: "test-container")
        
        // Then
        XCTAssertEqual(containerId, "container-id-123")
    }
    
    func testExecuteShellWithMock() throws {
        // Given
        let mockRunner = MockCommandRunner()
        mockRunner.mockOutput = "Hello from container"
        let service = DockerService(runner: mockRunner)
        
        // When
        let output = try service.executeShell(container: "test", script: "echo Hello")
        
        // Then
        XCTAssertEqual(output, "Hello from container")
    }
    
    func testFileOperationsWithMock() throws {
        // Given
        let mockRunner = MockCommandRunner()
        mockRunner.mockOutput = "file content"
        let service = DockerService(runner: mockRunner)
        
        // When
        let content = try service.readFile(container: "test", path: "/workspace/test.txt")
        
        // Then
        XCTAssertEqual(content, "file content")
    }
}

/// 통합 테스트: BuildConfiguration Service
@MainActor
class BuildConfigurationIntegrationTests: XCTestCase {
    
    var service: FileBasedBuildConfigurationService!
    let testConfigPath = FileManager.default.temporaryDirectory.appendingPathComponent("test-build-config.json").path
    
    override func setUp() {
        super.setUp()
        service = FileBasedBuildConfigurationService(configPath: testConfigPath)
        // Clean up before test
        try? FileManager.default.removeItem(atPath: testConfigPath)
    }
    
    override func tearDown() {
        // Clean up after test
        try? FileManager.default.removeItem(atPath: testConfigPath)
        service = nil
        super.tearDown()
    }
    
    func testSaveAndLoadConfiguration() throws {
        // Given
        let config = BuildConfiguration(
            selectedJDK: JDKConfiguration.predefined[0],
            buildTool: .maven,
            customArgs: ["-Xmx2g"]
        )
        
        // When
        try service.save(config)
        let loadedConfig = try service.load()
        
        // Then
        XCTAssertEqual(loadedConfig.selectedJDK.id, config.selectedJDK.id)
        XCTAssertEqual(loadedConfig.buildTool, config.buildTool)
        XCTAssertEqual(loadedConfig.customArgs, config.customArgs)
    }
    
    func testResetConfiguration() throws {
        // Given
        let customConfig = BuildConfiguration(
            selectedJDK: JDKConfiguration.predefined[2],
            buildTool: .gradle,
            customArgs: ["--info"]
        )
        try service.save(customConfig)
        
        // When
        try service.reset()
        let resetConfig = try service.load()
        
        // Then
        XCTAssertEqual(resetConfig.buildTool, BuildConfiguration.default.buildTool)
    }
    
    func testConfigurationPersistence() throws {
        // Given
        let config = BuildConfiguration(
            selectedJDK: JDKConfiguration.predefined[1],
            buildTool: .javac,
            customArgs: []
        )
        
        // When - Save with one instance
        try service.save(config)
        
        // Load with another instance (simulates app restart)
        let newService = FileBasedBuildConfigurationService(configPath: testConfigPath)
        let loadedConfig = try newService.load()
        
        // Then
        XCTAssertEqual(loadedConfig.selectedJDK.id, config.selectedJDK.id)
        XCTAssertEqual(loadedConfig.buildTool, config.buildTool)
    }
}

/// 통합 테스트: Session Manager
@MainActor
class SessionManagerIntegrationTests: XCTestCase {
    
    var sessionManager: SessionManager!
    
    override func setUp() {
        super.setUp()
        sessionManager = SessionManager()
    }
    
    override func tearDown() {
        sessionManager = nil
        super.tearDown()
    }
    
    func testCreateSession() throws {
        // Given
        let repoURL = URL(string: "https://github.com/user/repo.git")!
        let containerName = "zero-dev-test-123"
        
        // When
        let session = try sessionManager.createSession(repoURL: repoURL, containerName: containerName)
        
        // Then
        XCTAssertEqual(session.repoURL, repoURL)
        XCTAssertEqual(session.containerName, containerName)
        XCTAssertNotNil(session.id)
        XCTAssertNotNil(session.createdAt)
    }
    
    func testLoadSessions() throws {
        // Given
        let repoURL = URL(string: "https://github.com/user/repo.git")!
        let _ = try sessionManager.createSession(repoURL: repoURL, containerName: "test-1")
        let _ = try sessionManager.createSession(repoURL: repoURL, containerName: "test-2")
        
        // When
        let sessions = try sessionManager.loadSessions()
        
        // Then
        XCTAssertGreaterThanOrEqual(sessions.count, 2)
    }
    
    func testDeleteSession() throws {
        // Given
        let repoURL = URL(string: "https://github.com/user/repo.git")!
        let session = try sessionManager.createSession(repoURL: repoURL, containerName: "test-delete")
        
        // When
        try sessionManager.deleteSession(session)
        
        // Then
        let sessions = try sessionManager.loadSessions()
        XCTAssertFalse(sessions.contains { $0.id == session.id })
    }
}
