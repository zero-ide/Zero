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
    
    private let keychainService = "com.zero.ide"
    private let keychainAccount = "github_token"
    private let sessionManager = SessionManager()
    private lazy var orchestrator: ContainerOrchestrator = {
        let docker = DockerService()
        return ContainerOrchestrator(dockerService: docker, sessionManager: sessionManager)
    }()
    
    init() {
        checkLoginStatus()
    }
    
    func checkLoginStatus() {
        do {
            if let data = try KeychainHelper.standard.read(service: keychainService, account: keychainAccount),
               let token = String(data: data, encoding: .utf8) {
                self.accessToken = token
                self.isLoggedIn = true
            }
        } catch {
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
    
    func fetchRepositories() async {
        guard let token = accessToken else { return }
        isLoading = true
        defer { isLoading = false }
        
        do {
            let service = GitHubService(token: token)
            self.repositories = try await service.fetchRepositories()
        } catch {
            print("Failed to fetch repos: \(error)")
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
