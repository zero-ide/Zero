import Foundation

protocol ContainerRunning {
    func executeCommand(container: String, command: String) throws -> String
    func executeShell(container: String, script: String) throws -> String
    func executeShellStreaming(container: String, script: String, onOutput: @escaping (String) -> Void) throws -> String
}

protocol DockerServiceProtocol: ContainerRunning {
    func checkInstallation() throws -> Bool
    func runContainer(image: String, name: String) throws -> String
    func executeCommand(container: String, command: String) throws -> String
    func executeShell(container: String, script: String) throws -> String
    func executeShellStreaming(container: String, script: String, onOutput: @escaping (String) -> Void) throws -> String
    func listFiles(container: String, path: String) throws -> String
    func readFile(container: String, path: String) throws -> String
    func writeFile(container: String, path: String, content: String) throws
    func ensureDirectory(container: String, path: String) throws
    func rename(container: String, from: String, to: String) throws
    func remove(container: String, path: String, recursive: Bool) throws
    func stopContainer(name: String) throws
    func removeContainer(name: String) throws
    func fileExists(container: String, path: String) throws -> Bool
    func cancelCurrentExecution()
}

struct DockerService: DockerServiceProtocol {
    let runner: CommandRunning
    let dockerPath: String
    
    init(runner: CommandRunning = CommandRunner()) {
        self.runner = runner
        // Docker 경로 탐색 (Apple Silicon vs Intel)
        let possiblePaths = [
            "/usr/local/bin/docker",
            "/opt/homebrew/bin/docker",
            "/usr/bin/docker"
        ]
        self.dockerPath = possiblePaths.first(where: { FileManager.default.fileExists(atPath: $0) }) 
            ?? "/usr/local/bin/docker"
    }
    
    func checkInstallation() throws -> Bool {
        let output = try runner.execute(command: dockerPath, arguments: ["--version"])
        return output.contains("Docker version")
    }
    
    func runContainer(image: String, name: String) throws -> String {
        // docker run -d --rm --name {name} {image} tail -f /dev/null
        // -d: Detached mode (백그라운드)
        // --rm: 컨테이너 종료 시 자동 삭제 (일회용)
        // tail -f /dev/null: 컨테이너가 종료되지 않고 계속 실행되도록 유지
        let args = ["run", "-d", "--rm", "--name", name, image, "tail", "-f", "/dev/null"]
        return try runner.execute(command: dockerPath, arguments: args)
    }
    
    func executeCommand(container: String, command: String) throws -> String {
        // docker exec {container} {command}
        // command 문자열을 공백으로 쪼개서 전달 (간단한 구현)
        let commandArgs = command.components(separatedBy: " ")
        let args = ["exec", container] + commandArgs
        return try runner.execute(command: dockerPath, arguments: args)
    }
    
    /// 쉘 스크립트 실행 (sh -c 사용)
    func executeShell(container: String, script: String) throws -> String {
        let args = ["exec", container, "sh", "-c", script]
        do {
            return try runner.execute(command: dockerPath, arguments: args)
        } catch {
            throw mapRuntimeError(error, command: script, context: "Docker shell command failed.")
        }
    }

    func executeShellStreaming(container: String, script: String, onOutput: @escaping (String) -> Void) throws -> String {
        let args = ["exec", container, "sh", "-c", script]
        do {
            return try runner.executeStreaming(command: dockerPath, arguments: args, onOutput: onOutput)
        } catch {
            throw mapRuntimeError(error, command: script, context: "Docker shell command failed.")
        }
    }
    
    /// 디렉토리 파일 목록 조회
    func listFiles(container: String, path: String) throws -> String {
        // ls -la 형식으로 출력
        let args = ["exec", container, "ls", "-la", path]
        return try runner.execute(command: dockerPath, arguments: args)
    }
    
    /// 파일 내용 읽기
    func readFile(container: String, path: String) throws -> String {
        let args = ["exec", container, "cat", path]
        return try runner.execute(command: dockerPath, arguments: args)
    }
    
    /// 파일 저장 (base64 인코딩 사용으로 특수문자 처리)
    func writeFile(container: String, path: String, content: String) throws {
        // echo로 직접 쓰면 특수문자 문제가 생기므로 base64 사용
        guard let data = content.data(using: .utf8) else { return }
        let base64 = data.base64EncodedString()
        let args = ["exec", container, "sh", "-c", "echo '\(base64)' | base64 -d > \(quotedPath(path))"]
        _ = try runner.execute(command: dockerPath, arguments: args)
    }

    func ensureDirectory(container: String, path: String) throws {
        let script = "mkdir -p \(quotedPath(path))"
        _ = try executeShell(container: container, script: script)
    }

    func rename(container: String, from: String, to: String) throws {
        let script = "mv \(quotedPath(from)) \(quotedPath(to))"
        _ = try executeShell(container: container, script: script)
    }

    func remove(container: String, path: String, recursive: Bool) throws {
        let flag = recursive ? "-rf" : "-f"
        let script = "rm \(flag) \(quotedPath(path))"
        _ = try executeShell(container: container, script: script)
    }
    
    /// 컨테이너 중지
    func stopContainer(name: String) throws {
        let args = ["stop", name]
        _ = try runner.execute(command: dockerPath, arguments: args)
    }
    
    /// 컨테이너 강제 삭제
    func removeContainer(name: String) throws {
        let args = ["rm", "-f", name]
        _ = try runner.execute(command: dockerPath, arguments: args)
    }
    
    /// 파일/디렉토리 존재 여부 확인
    func fileExists(container: String, path: String) throws -> Bool {
        let args = ["exec", container, "test", "-e", path]
        do {
            _ = try runner.execute(command: dockerPath, arguments: args)
            return true
        } catch {
            return false
        }
    }

    func cancelCurrentExecution() {
        runner.cancelCurrentCommand()
    }

    private func quotedPath(_ path: String) -> String {
        let escaped = path.replacingOccurrences(of: "'", with: "'\\''")
        return "'\(escaped)'"
    }

    private func mapRuntimeError(_ error: Error, command: String, context: String) -> ZeroError {
        if let zeroError = error as? ZeroError {
            return zeroError
        }

        if case let CommandRunnerError.commandFailed(binary, arguments, exitCode, output) = error {
            let debugDetails = "\(context) [binary=\(binary)] [args=\(arguments.joined(separator: " "))] [script=\(command)] [exit=\(exitCode)] [output=\(output)]"
            return .runtimeCommandFailed(userMessage: context, debugDetails: debugDetails)
        }

        let debugDetails = "\(context) [script=\(command)] [error=\(error.localizedDescription)]"
        return .runtimeCommandFailed(userMessage: context, debugDetails: debugDetails)
    }
}
