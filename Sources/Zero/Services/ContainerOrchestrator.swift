import Foundation

class ContainerOrchestrator {
    private let dockerService: DockerServiceProtocol
    private let sessionManager: SessionManager
    private let baseImage = Constants.Docker.baseImage
    
    init(dockerService: DockerServiceProtocol, sessionManager: SessionManager) {
        self.dockerService = dockerService
        self.sessionManager = sessionManager
    }
    
    /// 전체 플로우 실행: 컨테이너 생성 -> Clone -> 세션 저장
    func startSession(repo: Repository, token: String) async throws -> Session {
        // 1. 컨테이너 이름 생성 (고유 ID)
        let containerName = "zero-dev-\(UUID().uuidString.prefix(8).lowercased())"
        
        // 2. 컨테이너 실행
        _ = try dockerService.runContainer(image: baseImage, name: containerName)
        
        // 2-1. Git 설치 (Alpine 이미지에 git이 없으므로 설치 필요)
        _ = try dockerService.executeShell(container: containerName, script: "apk add --no-cache git")
        
        // 3. Git Clone (토큰 주입)
        // DockerServiceProtocol이 ContainerRunning을 상속받으므로 직접 전달 가능
        let gitService = GitService(runner: dockerService)
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
        try dockerService.stopContainer(name: session.containerName)
    }
    
    /// 세션 삭제 (컨테이너 rm + 메타데이터 삭제)
    func deleteSession(_ session: Session) throws {
        try dockerService.removeContainer(name: session.containerName)
        try sessionManager.deleteSession(session)
    }
}
