import Foundation

protocol ContainerRunning {
    func executeCommand(container: String, command: String) throws -> String
}

extension DockerService: ContainerRunning {}

struct GitService {
    let runner: ContainerRunning
    
    init(runner: ContainerRunning) {
        self.runner = runner
    }
    
    func clone(repoURL: URL, token: String, to containerName: String) throws {
        // 인증 토큰을 URL에 삽입
        // https://github.com/user/repo.git -> https://x-access-token:{token}@github.com/user/repo.git
        
        guard var components = URLComponents(url: repoURL, resolvingAgainstBaseURL: false) else {
            return 
        }
        
        components.user = "x-access-token"
        components.password = token
        
        guard let authenticatedURL = components.string else {
            return
        }
        
        // 컨테이너 내부의 작업 디렉토리(ex: /workspace)로 Clone
        // (현재는 기본 경로에 Clone 가정)
        let command = "git clone \(authenticatedURL) ."
        
        _ = try runner.executeCommand(container: containerName, command: command)
    }
}
