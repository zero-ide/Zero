import Foundation

struct DiagnosticsNetworkStatus {
    let isReachable: Bool
    let message: String
}

struct DiagnosticsSnapshot {
    let checkedAt: Date
    let dockerPath: String
    let isDockerInstalled: Bool
    let dockerVersion: String?
    let isDockerDaemonRunning: Bool
    let isDockerSocketAccessible: Bool
    let dockerSocketStatusMessage: String
    let isNetworkReachable: Bool
    let networkStatusMessage: String
    let runningContainers: [String]
    let dockerStatusMessage: String
}

struct DiagnosticsService {
    private let runner: CommandRunning
    private let now: () -> Date
    private let networkStatusProvider: () -> DiagnosticsNetworkStatus

    let dockerPath: String

    init(
        runner: CommandRunning = CommandRunner(),
        dockerPath: String? = nil,
        now: @escaping () -> Date = Date.init,
        networkStatusProvider: @escaping () -> DiagnosticsNetworkStatus = Self.defaultNetworkStatusProvider
    ) {
        self.runner = runner
        self.dockerPath = dockerPath ?? Self.resolveDockerPath()
        self.now = now
        self.networkStatusProvider = networkStatusProvider
    }

    func collectSnapshot() -> DiagnosticsSnapshot {
        let checkedAt = now()
        let networkStatus = networkStatusProvider()

        do {
            _ = try runner.execute(command: dockerPath, arguments: ["--version"])
        } catch {
            let socketStatus = dockerSocketStatus(isDockerInstalled: false, isDockerDaemonRunning: false, daemonErrorMessage: nil)
            return DiagnosticsSnapshot(
                checkedAt: checkedAt,
                dockerPath: dockerPath,
                isDockerInstalled: false,
                dockerVersion: nil,
                isDockerDaemonRunning: false,
                isDockerSocketAccessible: socketStatus.isAccessible,
                dockerSocketStatusMessage: socketStatus.message,
                isNetworkReachable: networkStatus.isReachable,
                networkStatusMessage: networkStatus.message,
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
            let socketStatus = dockerSocketStatus(isDockerInstalled: true, isDockerDaemonRunning: true, daemonErrorMessage: nil)

            return DiagnosticsSnapshot(
                checkedAt: checkedAt,
                dockerPath: dockerPath,
                isDockerInstalled: true,
                dockerVersion: serverVersion.isEmpty ? nil : serverVersion,
                isDockerDaemonRunning: true,
                isDockerSocketAccessible: socketStatus.isAccessible,
                dockerSocketStatusMessage: socketStatus.message,
                isNetworkReachable: networkStatus.isReachable,
                networkStatusMessage: networkStatus.message,
                runningContainers: runningContainers,
                dockerStatusMessage: "Docker is ready"
            )
        } catch {
            let daemonErrorMessage = errorMessage(error)
            let socketStatus = dockerSocketStatus(
                isDockerInstalled: true,
                isDockerDaemonRunning: false,
                daemonErrorMessage: daemonErrorMessage
            )

            return DiagnosticsSnapshot(
                checkedAt: checkedAt,
                dockerPath: dockerPath,
                isDockerInstalled: true,
                dockerVersion: nil,
                isDockerDaemonRunning: false,
                isDockerSocketAccessible: socketStatus.isAccessible,
                dockerSocketStatusMessage: socketStatus.message,
                isNetworkReachable: networkStatus.isReachable,
                networkStatusMessage: networkStatus.message,
                runningContainers: [],
                dockerStatusMessage: "Docker daemon is not reachable: \(daemonErrorMessage)"
            )
        }
    }

    private func dockerSocketStatus(
        isDockerInstalled: Bool,
        isDockerDaemonRunning: Bool,
        daemonErrorMessage: String?
    ) -> (isAccessible: Bool, message: String) {
        guard isDockerInstalled else {
            return (false, "Docker CLI unavailable; socket access not checked")
        }

        if isDockerDaemonRunning {
            return (true, "Docker socket access is available")
        }

        if let daemonErrorMessage,
           daemonErrorMessage.lowercased().contains("permission denied") {
            return (false, "Docker socket permission denied")
        }

        return (false, "Docker socket access could not be verified")
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

    private static func defaultNetworkStatusProvider() -> DiagnosticsNetworkStatus {
        guard let url = URL(string: "https://api.github.com/meta") else {
            return DiagnosticsNetworkStatus(isReachable: false, message: "Network check failed: invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 3

        let semaphore = DispatchSemaphore(value: 0)
        let lock = NSLock()
        var result = DiagnosticsNetworkStatus(isReachable: false, message: "Network check timed out")

        let task = URLSession.shared.dataTask(with: request) { _, response, error in
            defer { semaphore.signal() }

            let nextResult: DiagnosticsNetworkStatus
            if let error {
                nextResult = DiagnosticsNetworkStatus(
                    isReachable: false,
                    message: "Network unreachable: \(error.localizedDescription)"
                )
            } else if let httpResponse = response as? HTTPURLResponse,
                      (200..<500).contains(httpResponse.statusCode) {
                nextResult = DiagnosticsNetworkStatus(
                    isReachable: true,
                    message: "Network reachable (HTTP \(httpResponse.statusCode))"
                )
            } else {
                nextResult = DiagnosticsNetworkStatus(
                    isReachable: false,
                    message: "Network unreachable: unexpected response"
                )
            }

            lock.lock()
            result = nextResult
            lock.unlock()
        }

        task.resume()

        if semaphore.wait(timeout: .now() + 4) == .timedOut {
            task.cancel()
            return DiagnosticsNetworkStatus(isReachable: false, message: "Network check timed out")
        }

        lock.lock()
        defer { lock.unlock() }
        return result
    }
}
