import XCTest
@testable import Zero

final class DiagnosticsServiceTests: XCTestCase {
    func testCollectSnapshotReportsDockerReadyAndRunningContainers() {
        // Given
        let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
        let mockRunner = DiagnosticsMockCommandRunner(responses: [
            .success("Docker version 27.0.1, build deadbeef"),
            .success("27.0.1\n"),
            .success("zero-dev\nzero-lsp-java\n")
        ])
        let service = DiagnosticsService(
            runner: mockRunner,
            dockerPath: "/opt/homebrew/bin/docker",
            now: { fixedDate },
            networkStatusProvider: {
                DiagnosticsNetworkStatus(isReachable: true, message: "Network reachable")
            }
        )

        // When
        let snapshot = service.collectSnapshot()

        // Then
        XCTAssertEqual(snapshot.checkedAt, fixedDate)
        XCTAssertEqual(snapshot.dockerPath, "/opt/homebrew/bin/docker")
        XCTAssertTrue(snapshot.isDockerInstalled)
        XCTAssertEqual(snapshot.dockerVersion, "27.0.1")
        XCTAssertTrue(snapshot.isDockerDaemonRunning)
        XCTAssertTrue(snapshot.isDockerSocketAccessible)
        XCTAssertEqual(snapshot.dockerSocketStatusMessage, "Docker socket access is available")
        XCTAssertTrue(snapshot.isNetworkReachable)
        XCTAssertEqual(snapshot.networkStatusMessage, "Network reachable")
        XCTAssertEqual(snapshot.runningContainers, ["zero-dev", "zero-lsp-java"])
        XCTAssertEqual(snapshot.dockerStatusMessage, "Docker is ready")
        XCTAssertEqual(mockRunner.executedCommands, [
            "/opt/homebrew/bin/docker",
            "/opt/homebrew/bin/docker",
            "/opt/homebrew/bin/docker"
        ])
        XCTAssertEqual(mockRunner.executedArguments, [
            ["--version"],
            ["info", "--format", "{{.ServerVersion}}"],
            ["ps", "--format", "{{.Names}}"]
        ])
    }

    func testCollectSnapshotReportsMissingDockerCLI() {
        // Given
        let mockRunner = DiagnosticsMockCommandRunner(responses: [
            .failure(NSError(domain: "Test", code: 127, userInfo: [NSLocalizedDescriptionKey: "No such file or directory"]))
        ])
        let service = DiagnosticsService(
            runner: mockRunner,
            dockerPath: "/missing/docker",
            networkStatusProvider: {
                DiagnosticsNetworkStatus(isReachable: false, message: "Network unreachable")
            }
        )

        // When
        let snapshot = service.collectSnapshot()

        // Then
        XCTAssertFalse(snapshot.isDockerInstalled)
        XCTAssertNil(snapshot.dockerVersion)
        XCTAssertFalse(snapshot.isDockerDaemonRunning)
        XCTAssertFalse(snapshot.isDockerSocketAccessible)
        XCTAssertEqual(snapshot.dockerSocketStatusMessage, "Docker CLI unavailable; socket access not checked")
        XCTAssertFalse(snapshot.isNetworkReachable)
        XCTAssertEqual(snapshot.networkStatusMessage, "Network unreachable")
        XCTAssertTrue(snapshot.runningContainers.isEmpty)
        XCTAssertEqual(snapshot.dockerStatusMessage, "Docker CLI not found: No such file or directory")
        XCTAssertEqual(mockRunner.executedArguments, [["--version"]])
    }

    func testCollectSnapshotReportsDaemonUnavailable() {
        // Given
        let mockRunner = DiagnosticsMockCommandRunner(responses: [
            .success("Docker version 27.0.1, build deadbeef"),
            .failure(NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot connect to the Docker daemon"]))
        ])
        let service = DiagnosticsService(
            runner: mockRunner,
            dockerPath: "/usr/local/bin/docker",
            networkStatusProvider: {
                DiagnosticsNetworkStatus(isReachable: true, message: "Network reachable")
            }
        )

        // When
        let snapshot = service.collectSnapshot()

        // Then
        XCTAssertTrue(snapshot.isDockerInstalled)
        XCTAssertNil(snapshot.dockerVersion)
        XCTAssertFalse(snapshot.isDockerDaemonRunning)
        XCTAssertFalse(snapshot.isDockerSocketAccessible)
        XCTAssertEqual(snapshot.dockerSocketStatusMessage, "Docker socket access could not be verified")
        XCTAssertTrue(snapshot.isNetworkReachable)
        XCTAssertEqual(snapshot.networkStatusMessage, "Network reachable")
        XCTAssertTrue(snapshot.runningContainers.isEmpty)
        XCTAssertEqual(snapshot.dockerStatusMessage, "Docker daemon is not reachable: Cannot connect to the Docker daemon")
        XCTAssertEqual(mockRunner.executedArguments, [
            ["--version"],
            ["info", "--format", "{{.ServerVersion}}"]
        ])
    }

    func testCollectSnapshotReportsDockerSocketPermissionDenied() {
        // Given
        let mockRunner = DiagnosticsMockCommandRunner(responses: [
            .success("Docker version 27.0.1, build deadbeef"),
            .failure(NSError(
                domain: "Test",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey: "Got permission denied while trying to connect to the Docker daemon socket at unix:///var/run/docker.sock"
                ]
            ))
        ])
        let service = DiagnosticsService(
            runner: mockRunner,
            dockerPath: "/usr/local/bin/docker",
            networkStatusProvider: {
                DiagnosticsNetworkStatus(isReachable: true, message: "Network reachable")
            }
        )

        // When
        let snapshot = service.collectSnapshot()

        // Then
        XCTAssertTrue(snapshot.isDockerInstalled)
        XCTAssertFalse(snapshot.isDockerDaemonRunning)
        XCTAssertFalse(snapshot.isDockerSocketAccessible)
        XCTAssertEqual(snapshot.dockerSocketStatusMessage, "Docker socket permission denied")
        XCTAssertEqual(
            snapshot.dockerStatusMessage,
            "Docker daemon is not reachable: Got permission denied while trying to connect to the Docker daemon socket at unix:///var/run/docker.sock"
        )
    }
}

private final class DiagnosticsMockCommandRunner: CommandRunning {
    enum Response {
        case success(String)
        case failure(Error)
    }

    private var responses: [Response]
    private(set) var executedCommands: [String] = []
    private(set) var executedArguments: [[String]] = []

    init(responses: [Response]) {
        self.responses = responses
    }

    func execute(command: String, arguments: [String]) throws -> String {
        executedCommands.append(command)
        executedArguments.append(arguments)

        guard !responses.isEmpty else {
            XCTFail("No mock response available for command: \(command) \(arguments.joined(separator: " "))")
            throw NSError(domain: "DiagnosticsMockCommandRunner", code: -1, userInfo: nil)
        }

        let next = responses.removeFirst()
        switch next {
        case .success(let output):
            return output
        case .failure(let error):
            throw error
        }
    }

    func executeStreaming(command: String, arguments: [String], onOutput: @escaping (String) -> Void) throws -> String {
        let output = try execute(command: command, arguments: arguments)
        onOutput(output)
        return output
    }

    func cancelCurrentCommand() {}
}
