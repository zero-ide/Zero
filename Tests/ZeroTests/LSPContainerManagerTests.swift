import XCTest
@testable import Zero

@MainActor
final class LSPContainerManagerTests: XCTestCase {
    func testStartLSPContainerUsesSharedRunningContainer() async throws {
        let runningCheck = "docker ps --filter \"name=^/zero-lsp-java$\" --filter \"status=running\" --format \"{{.Names}}\""
        let commandStub = HostCommandStub(
            outputs: [
                runningCheck: ["zero-lsp-java\n"]
            ]
        )

        let manager = LSPContainerManager(
            commandRunner: { try await commandStub.run($0) },
            dockerContextPathResolver: { _ in "/tmp/zero/docker/lsp-java" },
            sleep: { _ in }
        )

        let name = try await manager.startLSPContainer(language: "java")
        let executed = await commandStub.executedCommands()

        XCTAssertEqual(name, "zero-lsp-java")
        XCTAssertEqual(executed, [runningCheck])
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

        let manager = LSPContainerManager(
            commandRunner: { try await commandStub.run($0) },
            dockerContextPathResolver: { _ in "/tmp/zero/docker/lsp-java" },
            sleep: { _ in }
        )

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

        let manager = LSPContainerManager(
            commandRunner: { try await commandStub.run($0) },
            dockerContextPathResolver: { _ in "/tmp/zero/docker/lsp-java" },
            sleep: { _ in }
        )

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
