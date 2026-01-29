import Foundation

struct DockerService {
    let runner: CommandRunning
    let dockerPath = "/usr/local/bin/docker" // 추후 환경변수 등에서 탐색 가능
    
    init(runner: CommandRunning = CommandRunner()) {
        self.runner = runner
    }
    
    func checkInstallation() throws -> Bool {
        let output = try runner.execute(command: dockerPath, arguments: ["--version"])
        return output.contains("Docker version")
    }
    
    func runContainer(image: String, name: String) throws -> String {
        // docker run -d --rm --name {name} {image}
        // -d: Detached mode (백그라운드)
        // --rm: 컨테이너 종료 시 자동 삭제 (일회용)
        let args = ["run", "-d", "--rm", "--name", name, image]
        return try runner.execute(command: dockerPath, arguments: args)
    }
}
