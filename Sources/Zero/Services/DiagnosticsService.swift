import Foundation

struct DiagnosticsSnapshot {
    let checkedAt: Date
    let dockerPath: String
    let isDockerInstalled: Bool
    let dockerVersion: String?
    let isDockerDaemonRunning: Bool
    let runningContainers: [String]
    let dockerStatusMessage: String
}

struct DiagnosticsService {
    private let runner: CommandRunning
    private let now: () -> Date

    let dockerPath: String

    init(
        runner: CommandRunning = CommandRunner(),
        dockerPath: String? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        self.runner = runner
        self.dockerPath = dockerPath ?? Self.resolveDockerPath()
        self.now = now
    }

    func collectSnapshot() -> DiagnosticsSnapshot {
        let checkedAt = now()

        do {
            _ = try runner.execute(command: dockerPath, arguments: ["--version"])
        } catch {
            return DiagnosticsSnapshot(
                checkedAt: checkedAt,
                dockerPath: dockerPath,
                isDockerInstalled: false,
                dockerVersion: nil,
                isDockerDaemonRunning: false,
                runningContainers: [],
                dockerStatusMessage: "Docker CLI not found: \(errorMessage(error))"
            )
        }

        do {
            let serverVersionOutput = try runner.execute(
                command: dockerPath,
                arguments: ["info", "--format", "{{.ServerVersion}}"]
            )
            let serverVersion = trimmed(serverVersionOutput)

            let runningContainersOutput = try runner.execute(
                command: dockerPath,
                arguments: ["ps", "--format", "{{.Names}}"]
            )
            let runningContainers = parseLines(runningContainersOutput)

            return DiagnosticsSnapshot(
                checkedAt: checkedAt,
                dockerPath: dockerPath,
                isDockerInstalled: true,
                dockerVersion: serverVersion.isEmpty ? nil : serverVersion,
                isDockerDaemonRunning: true,
                runningContainers: runningContainers,
                dockerStatusMessage: "Docker is ready"
            )
        } catch {
            return DiagnosticsSnapshot(
                checkedAt: checkedAt,
                dockerPath: dockerPath,
                isDockerInstalled: true,
                dockerVersion: nil,
                isDockerDaemonRunning: false,
                runningContainers: [],
                dockerStatusMessage: "Docker daemon is not reachable: \(errorMessage(error))"
            )
        }
    }

    private func parseLines(_ output: String) -> [String] {
        output
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .map(trimmed)
            .filter { !$0.isEmpty }
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func errorMessage(_ error: Error) -> String {
        let message = trimmed(error.localizedDescription)
        return message.isEmpty ? "Unknown error" : message
    }

    private static func resolveDockerPath() -> String {
        let possiblePaths = [
            "/usr/local/bin/docker",
            "/opt/homebrew/bin/docker",
            "/usr/bin/docker"
        ]
        return possiblePaths.first(where: { FileManager.default.fileExists(atPath: $0) })
            ?? "/usr/local/bin/docker"
    }
}
