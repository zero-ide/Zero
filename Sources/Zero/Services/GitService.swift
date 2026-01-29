import Foundation

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
        
        // /workspace 디렉토리 생성 후 해당 경로에 Clone
        let command = "mkdir -p /workspace && cd /workspace && git clone \(authenticatedURL) ."
        
        _ = try runner.executeShell(container: containerName, script: command)
    }
}
