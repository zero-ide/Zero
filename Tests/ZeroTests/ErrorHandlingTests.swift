import XCTest
@testable import Zero

@MainActor
class ErrorHandlingTests: XCTestCase {
    
    // MARK: - DockerService Error Tests
    
    func testDockerServiceInvalidContainer() {
        // Given
        let mockRunner = MockCommandRunning()
        mockRunner.mockError = NSError(domain: "Docker", code: 1, userInfo: [NSLocalizedDescriptionKey: "container not found"])
        let service = DockerService(runner: mockRunner)
        
        // When & Then
        XCTAssertThrowsError(try service.executeShell(container: "invalid", script: "ls")) { error in
            XCTAssertTrue(error.localizedDescription.contains("not found") || error.localizedDescription.contains("Docker"))
        }
    }
    
    func testDockerServiceEmptyScript() {
        // Given
        let mockRunner = MockCommandRunning()
        mockRunner.mockOutput = ""
        let service = DockerService(runner: mockRunner)
        
        // When
        let result = try? service.executeShell(container: "test", script: "")
        
        // Then
        XCTAssertEqual(result, "")
    }
    
    // MARK: - BuildConfigurationService Error Tests
    
    func testBuildConfigurationServiceLoadInvalidJSON() {
        // Given
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("invalid-build-config.json")
        try? "invalid json".write(to: testFile, atomically: true, encoding: .utf8)
        
        let service = FileBasedBuildConfigurationService(configPath: testFile.path)
        
        // When
        do {
            _ = try service.load()
            XCTFail("Should have thrown decoding error")
        } catch {
            // Then - Should throw decoding error
            XCTAssertTrue(error is BuildConfigurationError)
        }
        
        // Cleanup
        try? FileManager.default.removeItem(at: testFile)
    }
    
    func testBuildConfigurationServiceLoadNonExistentFile() {
        // Given
        let service = FileBasedBuildConfigurationService(configPath: "/non/existent/path/config.json")
        
        // When
        let config = try? service.load()
        
        // Then - Should return default when file doesn't exist
        XCTAssertNotNil(config)
        XCTAssertEqual(config?.buildTool, .javac)
    }
    
    // MARK: - ContainerOrchestrator Error Tests
    
    func testContainerOrchestratorSessionCreationFailure() async {
        // Given
        let mockDocker = MockDockerServiceProtocol()
        mockDocker.shouldFail = true
        let sessionManager = SessionManager()
        let orchestrator = ContainerOrchestrator(dockerService: mockDocker, sessionManager: sessionManager)
        
        let repo = Repository(
            id: 1,
            name: "test-repo",
            fullName: "user/test-repo",
            isPrivate: false,
            htmlURL: URL(string: "https://github.com/user/test-repo")!,
            cloneURL: URL(string: "https://github.com/user/test-repo.git")!
        )
        
        // When & Then
        do {
            _ = try await orchestrator.startSession(repo: repo, token: "token")
            XCTFail("Should have thrown an error")
        } catch {
            // Expected
            XCTAssertNotNil(error)
        }
    }
    
    // MARK: - ExecutionService Error Tests
    
    func testExecutionServiceDetectRunCommandError() async {
        // Given
        let mockDocker = MockDockerServiceProtocol()
        let service = ExecutionService(dockerService: mockDocker)
        
        // When & Then
        do {
            _ = try await service.detectRunCommand(container: "test")
            XCTFail("Should have thrown error")
        } catch {
            XCTAssertNotNil(error)
        }
    }
}

// MARK: - Mocks

class MockCommandRunning: CommandRunning {
    var mockOutput: String = ""
    var mockError: Error?
    
    func execute(command: String, arguments: [String]) throws -> String {
        if let error = mockError {
            throw error
        }
        return mockOutput
    }
}

class MockDockerServiceProtocol: DockerServiceProtocol {
    var shouldFail = false
    
    func checkInstallation() throws -> Bool {
        return !shouldFail
    }
    
    func runContainer(image: String, name: String) throws -> String {
        if shouldFail {
            throw NSError(domain: "Docker", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to run container"])
        }
        return name
    }
    
    func executeCommand(container: String, command: String) throws -> String {
        if shouldFail {
            throw NSError(domain: "Docker", code: 1, userInfo: [NSLocalizedDescriptionKey: "Execution failed"])
        }
        return "output"
    }
    
    func executeShell(container: String, script: String) throws -> String {
        if shouldFail {
            throw NSError(domain: "Docker", code: 1, userInfo: [NSLocalizedDescriptionKey: "Execution failed"])
        }
        return "output"
    }
    
    func listFiles(container: String, path: String) throws -> String {
        if shouldFail {
            throw NSError(domain: "Docker", code: 1)
        }
        return ""
    }
    
    func readFile(container: String, path: String) throws -> String {
        if shouldFail {
            throw NSError(domain: "Docker", code: 1)
        }
        return ""
    }
    
    func writeFile(container: String, path: String, content: String) throws {
        if shouldFail {
            throw NSError(domain: "Docker", code: 1)
        }
    }
    
    func stopContainer(name: String) throws {
        if shouldFail {
            throw NSError(domain: "Docker", code: 1)
        }
    }
    
    func removeContainer(name: String) throws {
        if shouldFail {
            throw NSError(domain: "Docker", code: 1)
        }
    }
    
    func fileExists(container: String, path: String) throws -> Bool {
        return !shouldFail
    }
}
