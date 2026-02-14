import XCTest
@testable import Zero

@MainActor
final class LSPContainerManagerTests: XCTestCase {
    private func makeManager(
        commandStub: HostCommandStub,
        dockerContextPathResolver: ((String) -> String?)? = { _ in "/tmp/zero/docker/lsp-java" }
    ) -> LSPContainerManager {
        let dockerRunner = DockerInstallationCommandRunner()
        let dockerService = DockerService(runner: dockerRunner)

        return LSPContainerManager(
            dockerService: dockerService,
            commandRunner: { try await commandStub.run($0) },
            dockerContextPathResolver: dockerContextPathResolver,
            sleep: { _ in }
        )
    }

    func testStartLSPContainerUsesEnvironmentDockerContextPath() async throws {
        let runningCheck = "docker ps --filter \"name=^/zero-lsp-java$\" --filter \"status=running\" --format \"{{.Names}}\""
        let imageCheck = "docker image inspect zero-lsp-java --format '{{.Id}}'"
        let containerExistsCheck = "docker ps -a --filter \"name=^/zero-lsp-java$\" --format \"{{.Names}}\""
        let runCommand = "docker run -d --name zero-lsp-java -p 8080:8080 -v /tmp/zero-lsp-workspace:/workspace zero-lsp-java"

        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("zero-lsp-context-\(UUID().uuidString)", isDirectory: true)
        let expectedContext = tempRoot.appendingPathComponent("lsp-java", isDirectory: true)
        try FileManager.default.createDirectory(at: expectedContext, withIntermediateDirectories: true)
        try "FROM scratch\n".write(to: expectedContext.appendingPathComponent("Dockerfile"), atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let previousValue = ProcessInfo.processInfo.environment["ZERO_LSP_DOCKER_CONTEXT"]
        setenv("ZERO_LSP_DOCKER_CONTEXT", tempRoot.path, 1)
        defer {
            if let previousValue {
                setenv("ZERO_LSP_DOCKER_CONTEXT", previousValue, 1)
            } else {
                unsetenv("ZERO_LSP_DOCKER_CONTEXT")
            }
        }

        let commandStub = HostCommandStub(
            outputs: [
                runningCheck: ["", "zero-lsp-java\n"],
                containerExistsCheck: [""],
                runCommand: ["container-id\n"]
            ],
            failingCommands: [imageCheck]
        )

        let manager = makeManager(commandStub: commandStub, dockerContextPathResolver: nil)

        _ = try await manager.startLSPContainer(language: "java")
        let executed = await commandStub.executedCommands()

        XCTAssertTrue(executed.contains("docker build -t zero-lsp-java \"\(expectedContext.path)\""))
    }

    func testStartLSPContainerUsesSharedRunningContainer() async throws {
        let runningCheck = "docker ps --filter \"name=^/zero-lsp-java$\" --filter \"status=running\" --format \"{{.Names}}\""
        let commandStub = HostCommandStub(
            outputs: [
                runningCheck: ["zero-lsp-java\n"]
            ]
        )

        let manager = makeManager(commandStub: commandStub)

        let name = try await manager.startLSPContainer(language: "java")
        let executed = await commandStub.executedCommands()

        XCTAssertEqual(name, "zero-lsp-java")
        XCTAssertEqual(executed, [runningCheck])
    }

    func testEnsureLSPContainerRunningReturnsFalseWhenContextMissing() async {
        let runningCheck = "docker ps --filter \"name=^/zero-lsp-java$\" --filter \"status=running\" --format \"{{.Names}}\""
        let imageCheck = "docker image inspect zero-lsp-java --format '{{.Id}}'"
        let commandStub = HostCommandStub(
            outputs: [
                runningCheck: [""]
            ],
            failingCommands: [imageCheck]
        )

        let manager = makeManager(commandStub: commandStub, dockerContextPathResolver: { _ in nil })
        let isReady = await manager.ensureLSPContainerRunning(language: "java")

        XCTAssertFalse(isReady)
        XCTAssertEqual(manager.statusMessage, "LSP unavailable")
        XCTAssertEqual(manager.errorMessage, "LSP Docker 컨텍스트를 찾을 수 없습니다: lsp-java")
    }

    func testStartLSPContainerBuildsAndRunsWhenMissing() async throws {
        let runningCheck = "docker ps --filter \"name=^/zero-lsp-java$\" --filter \"status=running\" --format \"{{.Names}}\""
        let imageCheck = "docker image inspect zero-lsp-java --format '{{.Id}}'"
        let containerExistsCheck = "docker ps -a --filter \"name=^/zero-lsp-java$\" --format \"{{.Names}}\""
        let buildCommand = "docker build -t zero-lsp-java \"/tmp/zero/docker/lsp-java\""
        let runCommand = "docker run -d --name zero-lsp-java -p 8080:8080 -v /tmp/zero-lsp-workspace:/workspace zero-lsp-java"

        let commandStub = HostCommandStub(
            outputs: [
                runningCheck: ["", "zero-lsp-java\n"],
                containerExistsCheck: [""],
                runCommand: ["container-id\n"]
            ],
            failingCommands: [imageCheck]
        )

        let manager = makeManager(commandStub: commandStub)

        _ = try await manager.startLSPContainer(language: "java")
        let executed = await commandStub.executedCommands()

        XCTAssertTrue(executed.contains(buildCommand))
        XCTAssertTrue(executed.contains(runCommand))
    }

    func testStartLSPContainerStartsExistingStoppedContainer() async throws {
        let runningCheck = "docker ps --filter \"name=^/zero-lsp-java$\" --filter \"status=running\" --format \"{{.Names}}\""
        let imageCheck = "docker image inspect zero-lsp-java --format '{{.Id}}'"
        let containerExistsCheck = "docker ps -a --filter \"name=^/zero-lsp-java$\" --format \"{{.Names}}\""
        let startCommand = "docker start zero-lsp-java"

        let commandStub = HostCommandStub(
            outputs: [
                runningCheck: ["", "zero-lsp-java\n"],
                imageCheck: ["sha256:abc\n"],
                containerExistsCheck: ["zero-lsp-java\n"],
                startCommand: ["zero-lsp-java\n"]
            ]
        )

        let manager = makeManager(commandStub: commandStub)

        _ = try await manager.startLSPContainer(language: "java")
        let executed = await commandStub.executedCommands()

        XCTAssertTrue(executed.contains(startCommand))
        XCTAssertFalse(executed.contains(where: { $0.hasPrefix("docker run -d --name zero-lsp-java") }))
    }
}

actor HostCommandStub {
    private var outputs: [String: [String]]
    private let failingCommands: Set<String>
    private var commands: [String] = []

    init(outputs: [String: [String]], failingCommands: Set<String> = []) {
        self.outputs = outputs
        self.failingCommands = failingCommands
    }

    func run(_ command: String) async throws -> String {
        commands.append(command)

        if failingCommands.contains(command) {
            throw NSError(domain: "HostCommandStub", code: 1, userInfo: [NSLocalizedDescriptionKey: command])
        }

        guard var queue = outputs[command], !queue.isEmpty else {
            return ""
        }

        let value = queue.removeFirst()
        outputs[command] = queue
        return value
    }

    func executedCommands() -> [String] {
        commands
    }
}

private final class DockerInstallationCommandRunner: CommandRunning {
    func execute(command: String, arguments: [String]) throws -> String {
        if arguments == ["--version"] {
            return "Docker version 25.0.0"
        }

        return ""
    }
}
