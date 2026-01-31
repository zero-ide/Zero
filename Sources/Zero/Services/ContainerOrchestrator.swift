import Foundation

class ContainerOrchestrator {
    private let dockerService: DockerServiceProtocol
    private let sessionManager: SessionManager
    private let buildConfigService: BuildConfigurationService
    private let baseImage = Constants.Docker.baseImage
    
    init(dockerService: DockerServiceProtocol, sessionManager: SessionManager, buildConfigService: BuildConfigurationService = FileBasedBuildConfigurationService()) {
        self.dockerService = dockerService
        self.sessionManager = sessionManager
        self.buildConfigService = buildConfigService
    }
    
    /// 전체 플로우 실행: 컨테이너 생성 -> Clone -> 세션 저장
    func startSession(repo: Repository, token: String) async throws -> Session {
        // 1. 컨테이너 이름 생성 (고유 ID)
        let containerName = "zero-dev-\(UUID().uuidString.prefix(8).lowercased())"
        
        // 2. 프로젝트 타입에 따른 이미지 선택
        let image = try await selectImage(for: repo)
        
        // 3. 컨테이너 실행
        _ = try dockerService.runContainer(image: image, name: containerName)
        
        // 3-1. Git 설치 (Alpine 기반 이미지에 git이 없을 경우)
        if image.contains("alpine") {
            _ = try? dockerService.executeShell(container: containerName, script: "apk add --no-cache git")
        } else if image.contains("openjdk") || image.contains("temurin") || image.contains("corretto") {
            // JDK 이미지들은 보통 Debian/Ubuntu 기반이므로 apt 사용
            _ = try? dockerService.executeShell(container: containerName, script: "apt-get update && apt-get install -y git")
        }
        
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
    
    /// 프로젝트 타입에 따른 이미지 선택
    private func selectImage(for repo: Repository) async throws -> String {
        // 저장소 이름/설명에서 프로젝트 타입 추정
        let repoLower = repo.name.lowercased()
        
        // Java 프로젝트 감지
        if repoLower.contains("java") || repoLower.contains("spring") || repoLower.contains("maven") || repoLower.contains("gradle") {
            let config = try buildConfigService.load()
            return config.selectedJDK.image
        }
        
        // Node.js 프로젝트 감지
        if repoLower.contains("node") || repoLower.contains("react") || repoLower.contains("vue") || repoLower.contains("angular") {
            return "node:20-alpine"
        }
        
        // Python 프로젝트 감지
        if repoLower.contains("python") || repoLower.contains("django") || repoLower.contains("flask") {
            return "python:3.11-alpine"
        }
        
        // 기본 이미지
        return baseImage
    }
}
