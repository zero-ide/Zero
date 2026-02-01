import Foundation
import Combine

/// LSP Container Manager - Manages Language Server containers
@MainActor
class LSPContainerManager: ObservableObject {
    @Published var isRunning = false
    @Published var statusMessage = ""
    @Published var errorMessage: String?
    
    private var containerName: String?
    private let dockerService: DockerService
    private var webSocketTask: URLSessionWebSocketTask?
    
    init(dockerService: DockerService = DockerService()) {
        self.dockerService = dockerService
    }
    
    // MARK: - Container Management
    
    /// Start LSP container for given language
    func startLSPContainer(language: String) async throws -> String {
        let imageName = "zero-lsp-\(language)"
        let containerName = "zero-lsp-\(language)-\(UUID().uuidString.prefix(8))"
        
        statusMessage = "Pulling LSP image..."
        
        // Check if image exists, build if not
        do {
            _ = try dockerService.executeShell(
                container: "",
                script: "docker images -q \(imageName)"
            )
        } catch {
            // Build image from Dockerfile
            statusMessage = "Building LSP image (this may take a while)..."
            let buildScript = """
            cd /Users/$USER/Zero/docker/lsp-\(language) && \
            docker build -t \(imageName) .
            """
            _ = try await runLocalCommand(buildScript)
        }
        
        statusMessage = "Starting LSP container..."
        
        // Run container with port exposed
        let runScript = """
        docker run -d \
            --name \(containerName) \
            -p 8080:8080 \
            -v /tmp/zero-lsp-workspace:/workspace \
            \(imageName)
        """
        
        let containerID = try await runLocalCommand(runScript)
        self.containerName = containerName
        self.isRunning = true
        self.statusMessage = "LSP ready"
        
        // Wait for LSP to be ready
        try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
        
        return containerID
    }
    
    /// Stop LSP container
    func stopLSPContainer() async throws {
        guard let containerName = containerName else { return }
        
        statusMessage = "Stopping LSP..."
        
        let stopScript = "docker stop \(containerName) && docker rm \(containerName)"
        _ = try await runLocalCommand(stopScript)
        
        self.containerName = nil
        self.isRunning = false
        self.statusMessage = ""
        
        webSocketTask?.cancel()
        webSocketTask = nil
    }
    
    // MARK: - WebSocket Connection
    
    /// Connect to LSP WebSocket
    func connectToLSP() async throws -> URLSessionWebSocketTask {
        let url = URL(string: "ws://localhost:8080")!
        
        let session = URLSession(configuration: .default)
        let task = session.webSocketTask(with: url)
        
        task.resume()
        
        // Wait for connection
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        self.webSocketTask = task
        return task
    }
    
    /// Send LSP message
    func sendLSPMessage(_ message: [String: Any]) async throws {
        guard let task = webSocketTask else {
            throw LSPError.notConnected
        }
        
        let data = try JSONSerialization.data(withJSONObject: message)
        let messageString = String(data: data, encoding: .utf8)!
        
        try await task.send(.string(messageString))
    }
    
    /// Receive LSP message
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
    
    // MARK: - Helpers
    
    private func runLocalCommand(_ command: String) async throws -> String {
        let process = Process()
        process.launchPath = "/bin/bash"
        process.arguments = ["-c", command]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                continuation.resume(returning: output.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

// MARK: - Errors

enum LSPError: Error {
    case notConnected
    case invalidMessage
    case containerNotRunning
    case initializationFailed
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
        }
    }
}
