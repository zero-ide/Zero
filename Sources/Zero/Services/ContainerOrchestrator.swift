import Foundation

// Docker 작업을 위한 프로토콜 (테스트 용이성)
protocol DockerRunning {
    func runContainer(image: String, name: String) throws -> String
    func executeCommand(container: String, command: String) throws -> String
}

extension DockerService: DockerRunning {}

class ContainerOrchestrator {
    private let dockerService: DockerRunning
    private let sessionManager: SessionManager
    private let baseImage = "ubuntu:22.04"
    
    init(dockerService: DockerRunning, sessionManager: SessionManager) {
        self.dockerService = dockerService
        self.sessionManager = sessionManager
    }
    
    /// 전체 플로우 실행: 컨테이너 생성 -> Clone -> 세션 저장
    func startSession(repo: Repository, token: String) async throws -> Session {
        // 1. 컨테이너 이름 생성 (고유 ID)
        let containerName = "zero-dev-\(UUID().uuidString.prefix(8).lowercased())"
        
        // 2. 컨테이너 실행
        _ = try dockerService.runContainer(image: baseImage, name: containerName)
        
        // 3. Git Clone (토큰 주입)
        let gitService = GitService(runner: dockerService as! ContainerRunning)
        try gitService.clone(repoURL: repo.cloneURL, token: token, to: containerName)
        
        // 4. 세션 저장
        let session = try sessionManager.createSession(
            repoURL: repo.cloneURL,
            containerName: containerName
        )
        
        return session
    }
    
    /// 세션 중지 (컨테이너 stop)
    func stopSession(_ session: Session) throws {
        _ = try dockerService.executeCommand(container: session.containerName, command: "exit")
        // docker stop은 별도 명령어가 필요 - 추후 구현
    }
    
    /// 세션 삭제 (컨테이너 rm + 메타데이터 삭제)
    func deleteSession(_ session: Session) throws {
        // docker rm -f 명령어 실행 필요 - 추후 구현
        try sessionManager.deleteSession(session)
    }
}
