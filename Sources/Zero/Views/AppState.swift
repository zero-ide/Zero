import Foundation
import SwiftUI

@MainActor
class AppState: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var accessToken: String? = nil
    @Published var repositories: [Repository] = []
    @Published var sessions: [Session] = []
    @Published var isLoading: Bool = false
    @Published var activeSession: Session? = nil
    @Published var isEditing: Bool = false
    @Published var loadingMessage: String = ""
    @Published var currentPage: Int = 1
    @Published var isLoadingMore: Bool = false
    @Published var hasMoreRepos: Bool = true
    @Published var userFacingError: String? = nil
    
    @Published var organizations: [Organization] = []
    @Published var selectedOrg: Organization? = nil
    
    // 페이지 크기 (테스트 시 조정 가능)
    var pageSize: Int = Constants.GitHub.pageSize
    
    private let keychainService = Constants.Keychain.service
    private let keychainAccount = Constants.Keychain.account
    private let sessionManager = SessionManager()
    
    let executionService: ExecutionService
    let lspContainerManager: LSPContainerManager
    private let orchestrator: ContainerOrchestrator
    
    // 테스트를 위한 Factory
    var gitHubServiceFactory: (String) -> GitHubService = { token in
        GitHubService(token: token)
    }

    var sessionContainerHealthCheck: (Session) async -> Bool
    var persistedSessionLoader: () throws -> [Session]
    var persistedSessionDeleter: (Session) throws -> Void
    
    init() {
        let docker = DockerService()
        let manager = sessionManager
        self.executionService = ExecutionService(dockerService: docker)
        self.lspContainerManager = LSPContainerManager(dockerService: docker)
        self.orchestrator = ContainerOrchestrator(dockerService: docker, sessionManager: sessionManager)
        self.sessionContainerHealthCheck = { session in
            (try? docker.executeCommand(container: session.containerName, command: "true")) != nil
        }
        self.persistedSessionLoader = {
            try manager.loadSessions()
        }
        self.persistedSessionDeleter = { session in
            try manager.deleteSession(session)
        }
        
        checkLoginStatus()
    }
    
    func checkLoginStatus() {
        // Keychain 접근 실패 시 크래시 방지
        if let data = try? KeychainHelper.standard.read(service: keychainService, account: keychainAccount),
           let token = String(data: data, encoding: .utf8) {
            self.accessToken = token
            self.isLoggedIn = true
        } else {
            self.isLoggedIn = false
        }
    }
    
    func login(with token: String) throws {
        let data = token.data(using: .utf8)!
        try KeychainHelper.standard.save(data, service: keychainService, account: keychainAccount)
        self.accessToken = token
        self.isLoggedIn = true
    }
    
    func logout() throws {
        try KeychainHelper.standard.delete(service: keychainService, account: keychainAccount)
        self.accessToken = nil
        self.isLoggedIn = false
        self.repositories = []
    }
    
    func fetchOrganizations() async {
        guard let token = accessToken else { return }
        userFacingError = nil
        do {
            let service = gitHubServiceFactory(token)
            self.organizations = try await service.fetchOrganizations()
        } catch {
            print("Failed to fetch orgs: \(error)")
            userFacingError = "Failed to load organizations. Please try again."
        }
    }
    
    func fetchRepositories() async {
        guard let token = accessToken else { return }
        isLoading = true
        currentPage = 1
        hasMoreRepos = true
        userFacingError = nil
        defer { isLoading = false }
        
        do {
            let service = gitHubServiceFactory(token)
            let repos: [Repository]
            
            if let org = selectedOrg {
                repos = try await service.fetchOrgRepositories(org: org.login, page: 1)
            } else {
                // Personal 선택 시 owner 타입만 조회 (내 소유 레포)
                repos = try await service.fetchRepositories(page: 1, type: "owner")
            }
            
            self.repositories = repos
            
            // 페이지 크기보다 적으면 더 이상 데이터가 없는 것으로 판단
            if repos.isEmpty || repos.count < pageSize {
                hasMoreRepos = false
            }
        } catch {
            print("Failed to fetch repos: \(error)")
            userFacingError = "Failed to load repositories. Please check your token and network."
        }
    }
    
    func loadMoreRepositories() async {
        guard let token = accessToken, !isLoadingMore, hasMoreRepos else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        
        let nextPage = currentPage + 1
        
        do {
            let service = gitHubServiceFactory(token)
            let repos: [Repository]
            
            if let org = selectedOrg {
                repos = try await service.fetchOrgRepositories(org: org.login, page: nextPage)
            } else {
                repos = try await service.fetchRepositories(page: nextPage, type: "owner")
            }
            
            if repos.isEmpty {
                hasMoreRepos = false
                return
            }
            
            self.repositories.append(contentsOf: repos)
            self.currentPage = nextPage
            
            if repos.count < pageSize {
                hasMoreRepos = false
            }
        } catch {
            print("Failed to load more repos: \(error)")
            userFacingError = "Failed to load more repositories."
        }
    }
    
    func loadSessions() {
        do {
            self.sessions = try persistedSessionLoader()
            userFacingError = nil
        } catch {
            print("Failed to load sessions: \(error)")
            userFacingError = "Failed to load sessions."
        }
    }

    func loadSessionsWithHealthCheck() async {
        do {
            let persistedSessions = try persistedSessionLoader()
            var healthySessions: [Session] = []
            var staleSessions: [Session] = []

            for session in persistedSessions {
                if await sessionContainerHealthCheck(session) {
                    healthySessions.append(session)
                } else {
                    staleSessions.append(session)
                }
            }

            for session in staleSessions {
                do {
                    try persistedSessionDeleter(session)
                } catch {
                    print("Failed to delete stale session: \(error)")
                }
            }

            self.sessions = healthySessions
            userFacingError = nil
        } catch {
            print("Failed to load sessions: \(error)")
            userFacingError = "Failed to load sessions."
        }
    }
    
    /// 새 세션 시작 (컨테이너 생성 + Clone)
    func startSession(for repo: Repository) async {
        guard let token = accessToken else { return }
        
        isLoading = true
        loadingMessage = "Creating container..."
        userFacingError = nil
        
        do {
            let session = try await orchestrator.startSession(repo: repo, token: token)
            self.activeSession = session
            self.isEditing = true
            loadSessions() // 세션 목록 갱신
        } catch {
            print("Failed to start session: \(error)")
            loadingMessage = "Error: \(error.localizedDescription)"
            userFacingError = "Failed to start session: \(error.localizedDescription)"
        }
        
        isLoading = false
        loadingMessage = ""
    }
    
    /// 기존 세션 재개
    func resumeSession(_ session: Session) async {
        userFacingError = nil

        guard await sessionContainerHealthCheck(session) else {
            sessions.removeAll { $0.id == session.id }
            do {
                try persistedSessionDeleter(session)
            } catch {
                print("Failed to clean stale session: \(error)")
            }

            activeSession = nil
            isEditing = false
            userFacingError = "Session is no longer available. Please start a new session."
            return
        }

        self.activeSession = session
        self.isEditing = true
    }
    
    /// 에디터 닫기
    func closeEditor() {
        self.activeSession = nil
        self.isEditing = false
    }
    
    /// 세션 삭제
    func deleteSession(_ session: Session) {
        do {
            try orchestrator.deleteSession(session)
            userFacingError = nil
            loadSessions()
        } catch {
            print("Failed to delete session: \(error)")
            userFacingError = "Failed to delete session."
        }
    }

    func ensureJavaLSPReady() async -> Bool {
        await lspContainerManager.ensureLSPContainerRunning(language: "java")
    }

    func javaLSPBootstrapMessage() -> String {
        if let error = lspContainerManager.errorMessage, !error.isEmpty {
            return error
        }

        if !lspContainerManager.statusMessage.isEmpty {
            return lspContainerManager.statusMessage
        }

        return "Starting..."
    }
}
