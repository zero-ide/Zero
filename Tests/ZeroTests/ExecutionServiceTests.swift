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
        let (setup, command) = try await service.detectRunCommand(container: "test-container")
        
        // Then
        XCTAssertEqual(command, "swift run")
        XCTAssertNil(setup)
    }
    
    func testDetectRunCommand_NodeJS() async throws {
        // Given
        mockDocker.fileExistenceResults = ["package.json": true]
        
        // When
        let (setup, command) = try await service.detectRunCommand(container: "test-container")
        
        // Then
        XCTAssertEqual(command, "npm start")
        XCTAssertNil(setup)
    }
    
    func testDetectRunCommand_CustomConfig() async throws {
        // Given
        mockDocker.fileExistenceResults = ["zero-ide.json": true]
        mockDocker.fileContentResults = [
            "zero-ide.json": """
            {
                "command": "custom run",
                "setup": "custom setup"
            }
            """
        ]
        
        // When
        let (setup, command) = try await service.detectRunCommand(container: "test-container")
        
        // Then
        XCTAssertEqual(command, "custom run")
        XCTAssertEqual(setup, "custom setup")
    }
}

class MockExecutionDockerService: DockerServiceProtocol {
    var fileExistenceResults: [String: Bool] = [:]
    var fileContentResults: [String: String] = [:]
    var commandOutput: String = ""
    
    func checkInstallation() throws -> Bool { return true }
    
    func fileExists(container: String, path: String) throws -> Bool {
        let filename = URL(fileURLWithPath: path).lastPathComponent
        return fileExistenceResults[filename] ?? false
    }
    
    func readFile(container: String, path: String) throws -> String {
        let filename = URL(fileURLWithPath: path).lastPathComponent
        return fileContentResults[filename] ?? ""
    }
    
    func executeShell(container: String, script: String) throws -> String {
        return commandOutput
    }
    
    func runContainer(image: String, name: String) throws -> String { return "" }
    func executeCommand(container: String, command: String) throws -> String { return "" }
    func listFiles(container: String, path: String) throws -> String { return "" }
    func writeFile(container: String, path: String, content: String) throws {}
    func stopContainer(name: String) throws {}
    func removeContainer(name: String) throws {}
}
