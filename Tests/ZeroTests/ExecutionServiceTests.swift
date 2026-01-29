import XCTest
@testable import Zero

final class ExecutionServiceTests: XCTestCase {
    var service: ExecutionService!
    var mockDocker: MockExecutionDockerService!
    
    override func setUp() {
        super.setUp()
        mockDocker = MockExecutionDockerService()
        service = ExecutionService(dockerService: mockDocker)
    }
    
    func testInitialization() {
        XCTAssertNotNil(service)
        XCTAssertEqual(service.status, .idle)
    }
    
    func testDetectRunCommand_Swift() async throws {
        // Given
        mockDocker.fileExistenceResults = ["Package.swift": true]
        
        // When
        let command = try await service.detectRunCommand(container: "test-container")
        
        // Then
        XCTAssertEqual(command, "swift run")
    }
    
    func testDetectRunCommand_NodeJS() async throws {
        // Given
        mockDocker.fileExistenceResults = ["package.json": true]
        
        // When
        let command = try await service.detectRunCommand(container: "test-container")
        
        // Then
        XCTAssertEqual(command, "npm start")
    }
    
    func testExecute_Success() async {
        // Given
        mockDocker.commandOutput = "Hello World\n"
        
        // When
        await service.run(container: "test-container", command: "echo hello")
        
        // Then
        XCTAssertEqual(service.status, .success)
        XCTAssertEqual(service.output, "Hello World\n")
    }
}

class MockExecutionDockerService: DockerServiceProtocol {
    var fileExistenceResults: [String: Bool] = [:]
    var commandOutput: String = ""
    
    func checkInstallation() throws -> Bool { return true }
    
    // ...
    
    func fileExists(container: String, path: String) throws -> Bool {
        // 경로에서 파일명만 추출해서 체크 (간단하게)
        let filename = URL(fileURLWithPath: path).lastPathComponent
        return fileExistenceResults[filename] ?? false
    }
    
    // ... rest of methods
    func runContainer(image: String, name: String) throws -> String { return "" }
    func executeCommand(container: String, command: String) throws -> String { return "" }
    func executeShell(container: String, script: String) throws -> String {
        return commandOutput
    }
    func listFiles(container: String, path: String) throws -> String { return "" }
    func readFile(container: String, path: String) throws -> String { return "" }
    func writeFile(container: String, path: String, content: String) throws {}
    func stopContainer(name: String) throws {}
    func removeContainer(name: String) throws {}
    // fileExists 중복 제거
}
