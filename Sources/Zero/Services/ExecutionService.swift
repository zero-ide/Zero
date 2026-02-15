import Foundation
import Combine

enum ExecutionStatus: Equatable {
    case idle
    case running
    case success
    case failed(String)
}

class ExecutionService: ObservableObject {
    let dockerService: DockerServiceProtocol
    let buildConfigService: BuildConfigurationService
    let runProfileService: RunProfileService
    @Published var status: ExecutionStatus = .idle
    @Published var output: String = ""
    private var cancellationRequested = false
    
    init(
        dockerService: DockerServiceProtocol,
        buildConfigService: BuildConfigurationService = FileBasedBuildConfigurationService(),
        runProfileService: RunProfileService = FileBasedRunProfileService()
    ) {
        self.dockerService = dockerService
        self.buildConfigService = buildConfigService
        self.runProfileService = runProfileService
    }
    
    func run(container: String, command: String) async {
        await MainActor.run {
            self.status = .running
            self.cancellationRequested = false
            // output 초기화하지 않음
        }
        
        do {
            // 1. 환경 설정 (런타임 설치)
            try await setupEnvironment(for: command, container: container)
            
            // 2. /workspace로 이동 후 실행
            let fullCommand = "cd /workspace && \(command)"
            _ = try dockerService.executeShellStreaming(container: container, script: fullCommand) { chunk in
                Task { @MainActor in
                    self.output += chunk
                }
            }
            
            await MainActor.run {
                if self.cancellationRequested {
                    self.status = .failed("Execution cancelled")
                    self.output += "\n⏹️ Execution cancelled by user"
                } else {
                    self.status = .success
                }
            }
        } catch {
            await MainActor.run {
                if self.cancellationRequested {
                    self.status = .failed("Execution cancelled")
                    self.output += "\n⏹️ Execution cancelled by user"
                } else {
                    let userMessage = self.userMessage(for: error)
                    self.status = .failed(userMessage)
                    self.output += "\n❌ Error: \(userMessage)"
                }
            }
        }
    }

    @MainActor
    func stopRunning() {
        guard status == .running else { return }
        cancellationRequested = true
        dockerService.cancelCurrentExecution()
    }

    @MainActor
    func clearOutput() {
        output = ""
        if status != .running {
            status = .idle
        }
    }
    
    private func setupEnvironment(for command: String, container: String) async throws {
        if command.contains("npm") {
            await MainActor.run { self.output += "\n📦 Installing Node.js..." }
            _ = try dockerService.executeShell(container: container, script: "apk add --no-cache nodejs npm")
        } else if command.contains("python") {
            await MainActor.run { self.output += "\n📦 Installing Python..." }
            _ = try dockerService.executeShell(container: container, script: "apk add --no-cache python3")
        } else if command.contains("javac") || command.contains("mvn") || command.contains("gradle") {
            await MainActor.run { self.output += "\n📦 Setting up Java environment..." }
            // Note: JDK should be pre-installed in the container image
            // This is handled by using the configured JDK image
        } else if command.contains("go") {
            await MainActor.run { self.output += "\n📦 Installing Go..." }
            _ = try dockerService.executeShell(container: container, script: "apk add --no-cache go")
        }
    }
    
    func createJavaContainer(name: String) async throws -> String {
        let config = try buildConfigService.load()
        let jdkImage = config.selectedJDK.image
        
        await MainActor.run {
            self.output += "\n🐳 Creating container with \(config.selectedJDK.name)..."
        }
        
        return try dockerService.runContainer(image: jdkImage, name: name)
    }
    
    func detectRunCommand(container: String, repositoryURL: URL? = nil) async throws -> String {
        if let repositoryURL,
           let savedCommand = try? runProfileService.loadCommand(for: repositoryURL),
           let normalizedSavedCommand = normalizeCommand(savedCommand) {
            return normalizedSavedCommand
        }

        let config = try buildConfigService.load()

        if try dockerService.fileExists(container: container, path: "Dockerfile") {
            if canUseDockerfileStrategy(container: container) {
                return "docker build -t zero-runner . && docker run --rm zero-runner"
            }
        }

        if try dockerService.fileExists(container: container, path: "Package.swift") {
            return "swift run"
        }
        
        if try dockerService.fileExists(container: container, path: "pom.xml") {
            if config.buildTool == .maven {
                // Spring Boot 플러그인 확인
                if try await isSpringBootProject(container: container, buildTool: .maven) {
                    return "mvn spring-boot:run"
                }
                return "mvn clean install"
            }
            return "mvn clean install"
        }
        
        let hasBuildGradle = try dockerService.fileExists(container: container, path: "build.gradle")
        let hasBuildGradleKts = try dockerService.fileExists(container: container, path: "build.gradle.kts")
        if hasBuildGradle || hasBuildGradleKts {
            if config.buildTool == .gradle {
                // Spring Boot 플러그인 확인
                if try await isSpringBootProject(container: container, buildTool: .gradle) {
                    return "gradle bootRun"
                }
                return "gradle build"
            }
            return "gradle build"
        }
        
        if try dockerService.fileExists(container: container, path: "package.json") {
            return "npm start"
        }
        
        if try dockerService.fileExists(container: container, path: "main.py") {
            return "python3 main.py"
        }
        
        if try dockerService.fileExists(container: container, path: "Main.java") {
            return "javac Main.java && java Main"
        }
        
        if try dockerService.fileExists(container: container, path: "go.mod") {
            return "go run ."
        }
        
        throw NSError(domain: "ExecutionService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Cannot detect project type"])
    }

    func saveRunProfileCommand(_ command: String, for repositoryURL: URL) throws {
        let normalizedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalizedCommand.isEmpty {
            try runProfileService.removeCommand(for: repositoryURL)
            return
        }

        try runProfileService.save(command: normalizedCommand, for: repositoryURL)
    }

    func loadRunProfileCommand(for repositoryURL: URL) throws -> String? {
        normalizeCommand(try runProfileService.loadCommand(for: repositoryURL))
    }

    func clearRunProfile(for repositoryURL: URL) throws {
        try runProfileService.removeCommand(for: repositoryURL)
    }

    private func canUseDockerfileStrategy(container: String) -> Bool {
        guard let output = try? dockerService.executeShell(
            container: container,
            script: "command -v docker >/dev/null 2>&1 && echo yes || echo no"
        ) else {
            return false
        }

        return output.contains("yes")
    }

    private func normalizeCommand(_ command: String?) -> String? {
        guard let command else {
            return nil
        }

        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedCommand.isEmpty ? nil : trimmedCommand
    }

    private func userMessage(for error: Error) -> String {
        if let zeroError = error as? ZeroError {
            switch zeroError {
            case .runtimeCommandFailed(let userMessage, _):
                return userMessage
            default:
                return zeroError.localizedDescription
            }
        }

        return error.localizedDescription
    }
    
    /// Spring Boot 프로젝트 여부 확인
    private func isSpringBootProject(container: String, buildTool: BuildConfiguration.BuildTool) async throws -> Bool {
        switch buildTool {
        case .maven:
            let pomContent = try? dockerService.readFile(container: container, path: "/workspace/pom.xml")
            return pomContent?.contains("spring-boot") ?? false
        case .gradle:
            let buildGradleContent = try? dockerService.readFile(container: container, path: "/workspace/build.gradle")
            let buildGradleKtsContent = try? dockerService.readFile(container: container, path: "/workspace/build.gradle.kts")
            return (buildGradleContent?.contains("spring-boot") ?? false) || 
                   (buildGradleKtsContent?.contains("spring-boot") ?? false)
        default:
            return false
        }
    }
}
