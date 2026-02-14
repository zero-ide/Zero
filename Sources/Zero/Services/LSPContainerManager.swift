import Foundation
import Combine

@MainActor
class LSPContainerManager: ObservableObject {
    typealias CommandRunner = (String) async throws -> String
    typealias DockerContextPathResolver = (String) -> String?
    typealias Sleeper = (UInt64) async throws -> Void

    @Published var isRunning = false
    @Published var statusMessage = ""
    @Published var errorMessage: String?

    private var containerName: String?
    private let dockerService: DockerService
    private var webSocketTask: URLSessionWebSocketTask?
    private let commandRunner: CommandRunner
    private let dockerContextPathResolver: DockerContextPathResolver
    private let sleep: Sleeper

    init(
        dockerService: DockerService = DockerService(),
        commandRunner: CommandRunner? = nil,
        dockerContextPathResolver: DockerContextPathResolver? = nil,
        sleep: Sleeper? = nil
    ) {
        self.dockerService = dockerService
        self.commandRunner = commandRunner ?? LSPContainerManager.defaultCommandRunner
        self.dockerContextPathResolver = dockerContextPathResolver ?? LSPContainerManager.defaultDockerContextPath
        self.sleep = sleep ?? { nanoseconds in
            try await Task.sleep(nanoseconds: nanoseconds)
        }
    }

    func startLSPContainer(language: String) async throws -> String {
        guard (try? dockerService.checkInstallation()) == true else {
            throw LSPError.dockerNotInstalled
        }

        let imageName = "zero-lsp-\(language)"
        let sharedContainerName = "zero-lsp-\(language)"

        self.containerName = sharedContainerName
        statusMessage = "Checking LSP container..."
        errorMessage = nil

        if try await isContainerRunning(sharedContainerName) {
            isRunning = true
            statusMessage = "LSP ready"
            return sharedContainerName
        }

        if try await isImageMissing(imageName) {
            guard let contextPath = dockerContextPathResolver(language) else {
                throw LSPError.dockerContextNotFound(language)
            }

            statusMessage = "Building LSP image (this may take a while)..."
            _ = try await execute("docker build -t \(imageName) \"\(contextPath)\"")
        }

        statusMessage = "Starting LSP container..."

        if try await containerExists(sharedContainerName) {
            _ = try await execute("docker start \(sharedContainerName)")
        } else {
            let runCommand = "docker run -d --name \(sharedContainerName) -p 8080:8080 -v /tmp/zero-lsp-workspace:/workspace \(imageName)"
            _ = try await execute(runCommand)
        }

        try await waitUntilContainerRunning(sharedContainerName)

        self.isRunning = true
        self.statusMessage = "LSP ready"
        return sharedContainerName
    }

    func ensureLSPContainerRunning(language: String) async -> Bool {
        do {
            _ = try await startLSPContainer(language: language)
            return true
        } catch {
            isRunning = false
            errorMessage = error.localizedDescription
            statusMessage = "LSP unavailable"
            return false
        }
    }

    func stopLSPContainer() async throws {
        guard let containerName = containerName else { return }

        statusMessage = "Stopping LSP..."

        _ = try await execute("docker stop \(containerName)")

        self.containerName = nil
        self.isRunning = false
        self.statusMessage = ""

        webSocketTask?.cancel()
        webSocketTask = nil
    }

    func connectToLSP() async throws -> URLSessionWebSocketTask {
        let url = URL(string: "ws://localhost:8080")!

        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: url)

        task.resume()

        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        self.webSocketTask = task
        return task
    }

    func sendLSPMessage(_ message: [String: Any]) async throws {
        guard let task = webSocketTask else {
            throw LSPError.notConnected
        }

        let data = try JSONSerialization.data(withJSONObject: message)
        let messageString = String(data: data, encoding: .utf8)!

        try await task.send(.string(messageString))
    }

    func receiveLSPMessage() async throws -> [String: Any] {
        guard let task = webSocketTask else {
            throw LSPError.notConnected
        }

        let message = try await task.receive()

        switch message {
        case .string(let text):
            guard let data = text.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw LSPError.invalidMessage
            }
            return json
        default:
            throw LSPError.invalidMessage
        }
    }

    private func execute(_ command: String) async throws -> String {
        try await commandRunner(command)
    }

    private func isContainerRunning(_ name: String) async throws -> Bool {
        let command = "docker ps --filter \"name=^/\(name)$\" --filter \"status=running\" --format \"{{.Names}}\""
        let output = try await execute(command)
        return output
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .contains(name)
    }

    private func containerExists(_ name: String) async throws -> Bool {
        let command = "docker ps -a --filter \"name=^/\(name)$\" --format \"{{.Names}}\""
        let output = try await execute(command)
        return output
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .contains(name)
    }

    private func isImageMissing(_ imageName: String) async throws -> Bool {
        let command = "docker image inspect \(imageName) --format '{{.Id}}'"
        do {
            let output = try await execute(command)
            return output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } catch {
            return true
        }
    }

    private func waitUntilContainerRunning(_ name: String) async throws {
        let maxChecks = 20

        for _ in 0..<maxChecks {
            if try await isContainerRunning(name) {
                return
            }

            try await sleep(500_000_000)
        }

        throw LSPError.containerNotRunning
    }

    private static func defaultCommandRunner(_ command: String) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", command]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { _ in
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let outputText = String(data: outputData, encoding: .utf8) ?? ""
                let errorText = String(data: errorData, encoding: .utf8) ?? ""
                let combined = (outputText + errorText).trimmingCharacters(in: .whitespacesAndNewlines)

                if process.terminationStatus == 0 {
                    continuation.resume(returning: combined)
                } else {
                    let message = combined.isEmpty ? command : combined
                    continuation.resume(throwing: NSError(
                        domain: "LSPContainerManager",
                        code: Int(process.terminationStatus),
                        userInfo: [NSLocalizedDescriptionKey: message]
                    ))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private static func defaultDockerContextPath(_ language: String) -> String? {
        let fileManager = FileManager.default
        let contextSuffix = "lsp-\(language)"
        var candidates: [String] = []

        if let overrideRoot = ProcessInfo.processInfo.environment["ZERO_LSP_DOCKER_CONTEXT"], !overrideRoot.isEmpty {
            if overrideRoot.hasSuffix("/\(contextSuffix)") {
                candidates.append(overrideRoot)
            } else {
                candidates.append("\(overrideRoot)/\(contextSuffix)")
            }
        }

        if let resourcePath = Bundle.main.resourceURL?.appendingPathComponent("docker/\(contextSuffix)").path {
            candidates.append(resourcePath)
        }

        candidates.append("\(fileManager.currentDirectoryPath)/docker/\(contextSuffix)")
        candidates.append("\(NSHomeDirectory())/Documents/Zero/docker/\(contextSuffix)")
        candidates.append("/Users/\(NSUserName())/Documents/Zero/docker/\(contextSuffix)")

        return candidates.first(where: { path in
            fileManager.fileExists(atPath: path) && fileManager.fileExists(atPath: "\(path)/Dockerfile")
        })
    }
}

enum LSPError: Error {
    case notConnected
    case invalidMessage
    case containerNotRunning
    case initializationFailed
    case dockerContextNotFound(String)
    case dockerNotInstalled
}

extension LSPError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "LSP에 연결되어 있지 않습니다"
        case .invalidMessage:
            return "잘못된 LSP 메시지"
        case .containerNotRunning:
            return "LSP 컨테이너가 실행 중이 아닙니다"
        case .initializationFailed:
            return "LSP 초기화 실패"
        case .dockerContextNotFound(let language):
            return "LSP Docker 컨텍스트를 찾을 수 없습니다: lsp-\(language)"
        case .dockerNotInstalled:
            return "Docker가 설치되어 있지 않거나 실행 중이 아닙니다"
        }
    }
}
