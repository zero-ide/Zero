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
        XCTAssertTrue(service.output.contains("Hello World"))
    }

    func testClearOutputResetsToIdleWhenNotRunning() async {
        await MainActor.run {
            service.output = "old log"
            service.status = .success
            service.clearOutput()
        }

        XCTAssertEqual(service.output, "")
        XCTAssertEqual(service.status, .idle)
    }

    func testClearOutputKeepsRunningState() async {
        await MainActor.run {
            service.output = "running log"
            service.status = .running
            service.clearOutput()
        }

        XCTAssertEqual(service.output, "")
        XCTAssertEqual(service.status, .running)
    }

    func testStopRunningCancelsActiveExecutionAndMarksCancelled() async {
        // Given
        mockDocker.shouldBlockUntilCancelled = true

        let runTask = Task {
            await service.run(container: "test-container", command: "sleep 10")
        }

        try? await Task.sleep(nanoseconds: 150_000_000)

        // When
        await MainActor.run {
            service.stopRunning()
        }
        await runTask.value

        // Then
        XCTAssertTrue(mockDocker.cancelCurrentExecutionCalled)
        XCTAssertEqual(service.status, .failed("Execution cancelled"))
        XCTAssertTrue(service.output.contains("Execution cancelled by user"))
    }

    func testStopRunningNoopsWhenNotRunning() async {
        // Given
        await MainActor.run {
            service.status = .idle
            service.output = ""
        }

        // When
        await MainActor.run {
            service.stopRunning()
        }

        // Then
        XCTAssertFalse(mockDocker.cancelCurrentExecutionCalled)
        XCTAssertEqual(service.status, .idle)
    }

    func testRunStreamsOutputWhileExecutionIsStillRunning() async {
        // Given
        mockDocker.streamingChunks = ["first chunk\n", "second chunk\n"]
        mockDocker.interChunkDelayNanoseconds = 200_000_000

        // When
        let runTask = Task {
            await service.run(container: "test-container", command: "echo hello")
        }

        try? await Task.sleep(nanoseconds: 80_000_000)

        // Then
        XCTAssertTrue(service.output.contains("first chunk"), "Expected first streamed chunk before command completion")

        await runTask.value
        XCTAssertTrue(service.output.contains("second chunk"))
        XCTAssertEqual(service.status, .success)
    }
}

class MockExecutionDockerService: DockerServiceProtocol {
    var fileExistenceResults: [String: Bool] = [:]
    var commandOutput: String = ""
    var shouldBlockUntilCancelled = false
    var cancelCurrentExecutionCalled = false
    var streamingChunks: [String] = []
    var interChunkDelayNanoseconds: UInt64 = 0
    
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
        if shouldBlockUntilCancelled {
            while !cancelCurrentExecutionCalled {
                usleep(10_000)
            }
            throw NSError(domain: "Execution", code: 999, userInfo: [NSLocalizedDescriptionKey: "Cancelled"])
        }

        if !streamingChunks.isEmpty {
            for _ in streamingChunks {
                if interChunkDelayNanoseconds > 0 {
                    usleep(UInt32(interChunkDelayNanoseconds / 1_000))
                }
            }
            return streamingChunks.joined()
        }

        return commandOutput
    }

    func executeShellStreaming(container: String, script: String, onOutput: @escaping (String) -> Void) throws -> String {
        if shouldBlockUntilCancelled {
            while !cancelCurrentExecutionCalled {
                usleep(10_000)
            }
            throw NSError(domain: "Execution", code: 999, userInfo: [NSLocalizedDescriptionKey: "Cancelled"])
        }

        if !streamingChunks.isEmpty {
            for chunk in streamingChunks {
                onOutput(chunk)
                if interChunkDelayNanoseconds > 0 {
                    usleep(UInt32(interChunkDelayNanoseconds / 1_000))
                }
            }
            return streamingChunks.joined()
        }

        onOutput(commandOutput)
        return commandOutput
    }
    func cancelCurrentExecution() {
        cancelCurrentExecutionCalled = true
    }
    func listFiles(container: String, path: String) throws -> String { return "" }
    func readFile(container: String, path: String) throws -> String { return "" }
    func writeFile(container: String, path: String, content: String) throws {}
    func stopContainer(name: String) throws {}
    func removeContainer(name: String) throws {}
    // fileExists 중복 제거
}
