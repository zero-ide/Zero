import XCTest
@testable import Zero

final class ExecutionServiceTests: XCTestCase {
    var service: ExecutionService!
    var mockDocker: MockExecutionDockerService!
    var mockRunProfileService: MockRunProfileService!
    
    override func setUp() {
        super.setUp()
        mockDocker = MockExecutionDockerService()
        mockRunProfileService = MockRunProfileService()
        service = ExecutionService(
            dockerService: mockDocker,
            runProfileService: mockRunProfileService
        )
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

    func testDetectRunCommand_UsesSavedRunProfileBeforeAutoDetection() async throws {
        // Given
        let repositoryURL = URL(string: "https://github.com/zero-ide/Zero.git")!
        mockRunProfileService.commands[repositoryURL.absoluteString] = "swift run --configuration release"
        mockDocker.fileExistenceResults = ["Package.swift": true]

        // When
        let command = try await service.detectRunCommand(container: "test-container", repositoryURL: repositoryURL)

        // Then
        XCTAssertEqual(command, "swift run --configuration release")
    }

    func testDetectRunCommand_FallsBackToAutoDetectionWhenNoSavedRunProfile() async throws {
        // Given
        let repositoryURL = URL(string: "https://github.com/zero-ide/Zero.git")!
        mockDocker.fileExistenceResults = ["Package.swift": true]

        // When
        let command = try await service.detectRunCommand(container: "test-container", repositoryURL: repositoryURL)

        // Then
        XCTAssertEqual(command, "swift run")
    }

    func testDetectRunCommand_IgnoresWhitespaceOnlySavedRunProfile() async throws {
        // Given
        let repositoryURL = URL(string: "https://github.com/zero-ide/Zero.git")!
        mockRunProfileService.commands[repositoryURL.absoluteString] = "  \n\t  "
        mockDocker.fileExistenceResults = ["Package.swift": true]

        // When
        let command = try await service.detectRunCommand(container: "test-container", repositoryURL: repositoryURL)

        // Then
        XCTAssertEqual(command, "swift run")
    }

    func testDetectRunCommand_DockerfileTakesPriorityOverSwift() async throws {
        // Given
        mockDocker.dockerCommandAvailable = true
        mockDocker.fileExistenceResults = [
            "Dockerfile": true,
            "Package.swift": true
        ]

        // When
        let command = try await service.detectRunCommand(container: "test-container")

        // Then
        XCTAssertEqual(command, "docker build -t zero-runner . && docker run --rm zero-runner")
    }

    func testDetectRunCommand_DockerfileStrategyWhenOnlyDockerfileExists() async throws {
        // Given
        mockDocker.dockerCommandAvailable = true
        mockDocker.fileExistenceResults = ["Dockerfile": true]

        // When
        let command = try await service.detectRunCommand(container: "test-container")

        // Then
        XCTAssertEqual(command, "docker build -t zero-runner . && docker run --rm zero-runner")
    }

    func testDetectRunCommand_DockerfileFallsBackWhenDockerUnavailable() async throws {
        // Given
        mockDocker.dockerCommandAvailable = false
        mockDocker.fileExistenceResults = [
            "Dockerfile": true,
            "Package.swift": true
        ]

        // When
        let command = try await service.detectRunCommand(container: "test-container")

        // Then
        XCTAssertEqual(command, "swift run")
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

    func testRunUsesStructuredUserMessageWhenExecutionFails() async {
        // Given
        mockDocker.executionError = ZeroError.runtimeCommandFailed(
            userMessage: "Docker shell command failed.",
            debugDetails: "docker exec zero-dev sh -c 'echo hi' exited 127"
        )

        // When
        await service.run(container: "test-container", command: "echo hi")

        // Then
        XCTAssertEqual(service.status, .failed("Docker shell command failed."))
        XCTAssertTrue(service.output.contains("❌ Error: Docker shell command failed."))
    }

    func testRunRetriesPackageInstallAfterTransientFailure() async {
        // Given
        mockDocker.scriptedShellResults = [
            .failure(ZeroError.runtimeCommandFailed(userMessage: "Docker shell command timed out.", debugDetails: "attempt 1 timeout")),
            .success(""),
            .success("run ok")
        ]

        // When
        await service.run(container: "test-container", command: "npm start")

        // Then
        XCTAssertEqual(service.status, .success)
        XCTAssertTrue(service.output.contains("Retrying Node.js installation (attempt 2/3)"))

        let installCommands = mockDocker.executedShellScripts.filter { $0.contains("apk add --no-cache nodejs npm") }
        XCTAssertEqual(installCommands.count, 2)
    }

    func testRunFailsWhenPackageInstallRetriesExhausted() async {
        // Given
        mockDocker.scriptedShellResults = [
            .failure(ZeroError.runtimeCommandFailed(userMessage: "Docker shell command timed out.", debugDetails: "attempt 1 timeout")),
            .failure(ZeroError.runtimeCommandFailed(userMessage: "Docker shell command timed out.", debugDetails: "attempt 2 timeout")),
            .failure(ZeroError.runtimeCommandFailed(userMessage: "Docker shell command timed out.", debugDetails: "attempt 3 timeout"))
        ]

        // When
        await service.run(container: "test-container", command: "npm start")

        // Then
        XCTAssertEqual(service.status, .failed("Failed to install Node.js after 3 attempts."))
        XCTAssertTrue(service.output.contains("❌ Error: Failed to install Node.js after 3 attempts."))
    }

    func testRunWrapsPackageInstallWithTimeoutPolicy() async {
        // Given
        mockDocker.scriptedShellResults = [.success(""), .success("run ok")]

        // When
        await service.run(container: "test-container", command: "npm start")

        // Then
        guard let installScript = mockDocker.executedShellScripts.first(where: { $0.contains("apk add --no-cache nodejs npm") }) else {
            XCTFail("Expected Node.js install command to run")
            return
        }

        XCTAssertTrue(installScript.contains("timeout 20 sh -lc"))
    }

    func testRunRecordsTelemetrySummaryWhenEnabled() async {
        // Given
        service.telemetryEnabled = true
        mockDocker.commandOutput = "ok"

        // When
        await service.run(container: "test-container", command: "echo ok")

        mockDocker.executionError = ZeroError.runtimeCommandFailed(
            userMessage: "Docker shell command failed.",
            debugDetails: "runtime command failed"
        )
        await service.run(container: "test-container", command: "echo fail")

        // Then
        XCTAssertEqual(service.telemetrySummary.totalRuns, 2)
        XCTAssertEqual(service.telemetrySummary.successfulRuns, 1)
        XCTAssertEqual(service.telemetrySummary.failedRuns, 1)
        XCTAssertEqual(service.telemetrySummary.topErrorCodes.first?.code, "runtime_command_failed")
    }

    func testRunDoesNotRecordTelemetryWhenDisabled() async {
        // Given
        service.telemetryEnabled = false
        mockDocker.commandOutput = "ok"

        // When
        await service.run(container: "test-container", command: "echo ok")

        // Then
        XCTAssertEqual(service.telemetrySummary.totalRuns, 0)
        XCTAssertEqual(service.telemetrySummary.successfulRuns, 0)
        XCTAssertEqual(service.telemetrySummary.failedRuns, 0)
    }

    func testSaveAndLoadRunProfileCommand() throws {
        // Given
        let repositoryURL = URL(string: "https://github.com/zero-ide/Zero.git")!

        // When
        try service.saveRunProfileCommand("npm run dev", for: repositoryURL)
        let loadedCommand = try service.loadRunProfileCommand(for: repositoryURL)

        // Then
        XCTAssertEqual(loadedCommand, "npm run dev")
    }

    func testSaveRunProfileCommand_TrimsWhitespaceBeforeSaving() throws {
        // Given
        let repositoryURL = URL(string: "https://github.com/zero-ide/Zero.git")!

        // When
        try service.saveRunProfileCommand("  npm run dev  \n", for: repositoryURL)
        let loadedCommand = try service.loadRunProfileCommand(for: repositoryURL)

        // Then
        XCTAssertEqual(loadedCommand, "npm run dev")
    }

    func testSaveRunProfileCommand_WhitespaceOnlyRemovesSavedProfile() throws {
        // Given
        let repositoryURL = URL(string: "https://github.com/zero-ide/Zero.git")!
        try service.saveRunProfileCommand("npm run dev", for: repositoryURL)

        // When
        try service.saveRunProfileCommand("   \n\t   ", for: repositoryURL)
        let loadedCommand = try service.loadRunProfileCommand(for: repositoryURL)

        // Then
        XCTAssertNil(loadedCommand)
    }

    func testLoadRunProfileCommand_NormalizesWhitespaceOnlyValueToNil() throws {
        // Given
        let repositoryURL = URL(string: "https://github.com/zero-ide/Zero.git")!
        mockRunProfileService.commands[repositoryURL.absoluteString] = "\n  \t"

        // When
        let loadedCommand = try service.loadRunProfileCommand(for: repositoryURL)

        // Then
        XCTAssertNil(loadedCommand)
    }

    func testClearRunProfileCommand() throws {
        // Given
        let repositoryURL = URL(string: "https://github.com/zero-ide/Zero.git")!
        try service.saveRunProfileCommand("npm run dev", for: repositoryURL)

        // When
        try service.clearRunProfile(for: repositoryURL)
        let loadedCommand = try service.loadRunProfileCommand(for: repositoryURL)

        // Then
        XCTAssertNil(loadedCommand)
    }
}

class MockRunProfileService: RunProfileService {
    var commands: [String: String] = [:]

    func save(command: String, for repositoryURL: URL) throws {
        commands[repositoryURL.absoluteString] = command
    }

    func loadCommand(for repositoryURL: URL) throws -> String? {
        commands[repositoryURL.absoluteString]
    }

    func removeCommand(for repositoryURL: URL) throws {
        commands.removeValue(forKey: repositoryURL.absoluteString)
    }
}

class MockExecutionDockerService: DockerServiceProtocol {
    var fileExistenceResults: [String: Bool] = [:]
    var commandOutput: String = ""
    var shouldBlockUntilCancelled = false
    var cancelCurrentExecutionCalled = false
    var streamingChunks: [String] = []
    var interChunkDelayNanoseconds: UInt64 = 0
    var dockerCommandAvailable = true
    var executionError: Error?
    var scriptedShellResults: [Result<String, Error>] = []
    var executedShellScripts: [String] = []
    
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
        executedShellScripts.append(script)

        if !scriptedShellResults.isEmpty {
            let nextResult = scriptedShellResults.removeFirst()
            switch nextResult {
            case .success(let output):
                return output
            case .failure(let error):
                throw error
            }
        }

        if let executionError {
            throw executionError
        }

        if script.contains("command -v docker") {
            return dockerCommandAvailable ? "yes" : "no"
        }

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
        if let executionError {
            throw executionError
        }

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
    func ensureDirectory(container: String, path: String) throws {}
    func rename(container: String, from: String, to: String) throws {}
    func remove(container: String, path: String, recursive: Bool) throws {}
    func stopContainer(name: String) throws {}
    func removeContainer(name: String) throws {}
    // fileExists 중복 제거
}
