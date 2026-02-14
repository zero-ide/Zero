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
    @Published var status: ExecutionStatus = .idle
    @Published var output: String = ""
    
    init(dockerService: DockerServiceProtocol, buildConfigService: BuildConfigurationService = FileBasedBuildConfigurationService()) {
        self.dockerService = dockerService
        self.buildConfigService = buildConfigService
    }
    
    func run(container: String, command: String) async {
        await MainActor.run {
            self.status = .running
            // output 초기화하지 않음
        }
        
        do {
            // 1. 환경 설정 (런타임 설치)
            try await setupEnvironment(for: command, container: container)
            
            // 2. /workspace로 이동 후 실행
            let fullCommand = "cd /workspace && \(command)"
            let result = try dockerService.executeShell(container: container, script: fullCommand)
            
            await MainActor.run {
                self.output += "\n" + result
                self.status = .success
            }
        } catch {
            await MainActor.run {
                self.status = .failed(error.localizedDescription)
                self.output += "\n❌ Error: \(error.localizedDescription)"
            }
        }
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
    
    func detectRunCommand(container: String) async throws -> String {
        let config = try buildConfigService.load()
        
        // 순서대로 체크 (우선순위)
        // 1. Swift
        if try dockerService.fileExists(container: container, path: "Package.swift") {
            return "swift run"
        }
        
        // 2. Maven (pom.xml)
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
        
        // 3. Gradle (build.gradle 또는 build.gradle.kts)
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
        
        // 4. Node.js
        if try dockerService.fileExists(container: container, path: "package.json") {
            return "npm start"
        }
        
        // 5. Python
        if try dockerService.fileExists(container: container, path: "main.py") {
            return "python3 main.py"
        }
        
        // 6. Java (단일 파일)
        if try dockerService.fileExists(container: container, path: "Main.java") {
            return "javac Main.java && java Main"
        }
        
        // 7. Go
        if try dockerService.fileExists(container: container, path: "go.mod") {
            return "go run ."
        }
        
        throw NSError(domain: "ExecutionService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Cannot detect project type"])
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
