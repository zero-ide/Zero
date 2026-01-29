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
    
    @Published var organizations: [Organization] = []
    @Published var selectedOrg: Organization? = nil
    
    // 페이지 크기 (테스트 시 조정 가능)
    var pageSize: Int = Constants.GitHub.pageSize
    
    private let keychainService = Constants.Keychain.service
    private let keychainAccount = Constants.Keychain.account
    private let sessionManager = SessionManager()
    private lazy var orchestrator: ContainerOrchestrator = {
        let docker = DockerService()
        return ContainerOrchestrator(dockerService: docker, sessionManager: sessionManager)
    }()
    
    // 테스트를 위한 Factory
    var gitHubServiceFactory: (String) -> GitHubService = { token in
        GitHubService(token: token)
    }
    
    init() {
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
        do {
            let service = gitHubServiceFactory(token)
            self.organizations = try await service.fetchOrganizations()
        } catch {
            print("Failed to fetch orgs: \(error)")
        }
    }
    
    func fetchRepositories() async {
        guard let token = accessToken else { return }
        isLoading = true
        currentPage = 1
        hasMoreRepos = true
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
        }
    }
    
    func loadSessions() {
        do {
            self.sessions = try sessionManager.loadSessions()
        } catch {
            print("Failed to load sessions: \(error)")
        }
    }
    
    /// 새 세션 시작 (컨테이너 생성 + Clone)
    func startSession(for repo: Repository) async {
        guard let token = accessToken else { return }
        
        isLoading = true
        loadingMessage = "Creating container..."
        
        do {
            let session = try await orchestrator.startSession(repo: repo, token: token)
            self.activeSession = session
            self.isEditing = true
            loadSessions() // 세션 목록 갱신
        } catch {
            print("Failed to start session: \(error)")
            loadingMessage = "Error: \(error.localizedDescription)"
        }
        
        isLoading = false
        loadingMessage = ""
    }
    
    /// 기존 세션 재개
    func resumeSession(_ session: Session) {
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
            loadSessions()
        } catch {
            print("Failed to delete session: \(error)")
        }
    }
}
