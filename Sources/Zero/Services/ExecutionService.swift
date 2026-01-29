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
    @Published var status: ExecutionStatus = .idle
    @Published var output: String = ""
    
    init(dockerService: DockerServiceProtocol) {
        self.dockerService = dockerService
    }
    
    func run(container: String, command: String) async {
        await MainActor.run {
            self.status = .running
            // output 초기화하지 않음 (이전 로그 유지)
        }
        
        do {
            // /workspace로 이동 후 실행
            let fullCommand = "cd /workspace && \(command)"
            let result = try dockerService.executeShell(container: container, script: fullCommand)
            
            await MainActor.run {
                self.output += "\n" + result
                self.status = .success
            }
        } catch {
            await MainActor.run {
                self.status = .failed(error.localizedDescription)
                self.output += "\n❌ Execution Error: \(error.localizedDescription)"
            }
        }
    }
    
    func detectRunCommand(container: String) async throws -> String {
        // 순서대로 체크 (우선순위)
        // 1. Swift
        if try dockerService.fileExists(container: container, path: "Package.swift") {
            return "swift run"
        }
        
        // 2. Node.js
        if try dockerService.fileExists(container: container, path: "package.json") {
            return "npm start"
        }
        
        // 3. Python
        if try dockerService.fileExists(container: container, path: "main.py") {
            return "python3 main.py"
        }
        
        // 4. Java
        if try dockerService.fileExists(container: container, path: "Main.java") {
            return "javac Main.java && java Main"
        }
        
        // 5. Go
        if try dockerService.fileExists(container: container, path: "go.mod") {
            return "go run ."
        }
        
        throw NSError(domain: "ExecutionService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Cannot detect project type"])
    }
}
