import Foundation
import SwiftUI

@MainActor
class AppState: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var accessToken: String? = nil
    @Published var repositories: [Repository] = []
    @Published var sessions: [Session] = []
    @Published var isLoading: Bool = false
    
    private let keychainService = "com.zero.ide"
    private let keychainAccount = "github_token"
    
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
            let manager = SessionManager()
            self.sessions = try manager.loadSessions()
        } catch {
            print("Failed to load sessions: \(error)")
        }
    }
}
