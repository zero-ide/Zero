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
    @Published var selectedOrg: Organization? = nil {
        didSet {
            persistSelectedOrgContextIfNeeded()
        }
    }

    @Published var telemetryOptIn: Bool = false {
        didSet {
            persistTelemetryOptInIfNeeded()
            executionService.telemetryEnabled = telemetryOptIn
        }
    }
    
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

    var oauthClientIDProvider: () -> String? = {
        ProcessInfo.processInfo.environment["GITHUB_OAUTH_CLIENT_ID"] ??
        ProcessInfo.processInfo.environment["GITHUB_CLIENT_ID"]
    }
    var oauthClientSecretProvider: () -> String? = {
        ProcessInfo.processInfo.environment["GITHUB_OAUTH_CLIENT_SECRET"] ??
        ProcessInfo.processInfo.environment["GITHUB_CLIENT_SECRET"]
    }
    var oauthRedirectURIProvider: () -> String = {
        ProcessInfo.processInfo.environment["GITHUB_OAUTH_REDIRECT_URI"] ?? "zero://auth/callback"
    }
    var oauthTokenExchanger: (URLRequest) async throws -> String = { request in
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let tokenResponse = try JSONDecoder().decode(OAuthTokenResponse.self, from: data)
        return tokenResponse.accessToken
    }

    private var pendingOAuthState: String?
    private var pendingOAuthCodeVerifier: String?
    private var pendingOAuthRedirectURI: String?
    private var shouldPersistSelectedOrgContext = true
    private var shouldPersistTelemetryOptIn = true

    var pendingOAuthStateForTesting: String? {
        pendingOAuthState
    }

    var pendingOAuthCodeVerifierForTesting: String? {
        pendingOAuthCodeVerifier
    }
    
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

        let storedTelemetryOptIn = UserDefaults.standard.bool(forKey: Constants.Preferences.telemetryOptIn)
        shouldPersistTelemetryOptIn = false
        telemetryOptIn = storedTelemetryOptIn
        shouldPersistTelemetryOptIn = true
        executionService.telemetryEnabled = storedTelemetryOptIn
        
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

    func beginOAuthLogin() throws -> URL {
        guard let clientID = oauthClientIDProvider(), !clientID.isEmpty else {
            throw OAuthFlowError.missingConfiguration
        }

        let authManager = AuthManager(clientID: clientID, scope: "repo")
        let context = authManager.createAuthorizationContext()
        let redirectURI = oauthRedirectURIProvider()

        pendingOAuthState = context.state
        pendingOAuthCodeVerifier = context.codeVerifier
        pendingOAuthRedirectURI = redirectURI
        userFacingError = nil

        return authManager.getLoginURL(
            state: context.state,
            codeChallenge: context.codeChallenge,
            redirectURI: redirectURI
        )
    }

    func handleOAuthCallback(_ url: URL) async {
        let expectedRedirectURI = pendingOAuthRedirectURI ?? oauthRedirectURIProvider()
        if let expectedRedirectURL = URL(string: expectedRedirectURI) {
            let incomingKey = (url.scheme, url.host, url.path)
            let expectedKey = (expectedRedirectURL.scheme, expectedRedirectURL.host, expectedRedirectURL.path)
            if incomingKey != expectedKey {
                return
            }
        }

        guard let clientID = oauthClientIDProvider(),
              !clientID.isEmpty,
              let clientSecret = oauthClientSecretProvider(),
              !clientSecret.isEmpty else {
            clearPendingOAuthContext()
            userFacingError = "OAuth is not configured. Set GitHub OAuth credentials in environment."
            return
        }

        guard let expectedState = pendingOAuthState,
              let codeVerifier = pendingOAuthCodeVerifier else {
            clearPendingOAuthContext()
            userFacingError = "Authentication failed. Please try signing in again."
            return
        }

        let authManager = AuthManager(clientID: clientID, scope: "repo")
        guard let response = authManager.extractAuthorizationResponse(from: url),
              authManager.isValidCallbackState(expected: expectedState, actual: response.state) else {
            clearPendingOAuthContext()
            userFacingError = "Authentication failed. Please try signing in again."
            return
        }

        do {
            let request = try authManager.createTokenExchangeRequest(
                code: response.code,
                clientSecret: clientSecret,
                codeVerifier: codeVerifier,
                redirectURI: expectedRedirectURI
            )

            let token = try await oauthTokenExchanger(request)
            try login(with: token)
            clearPendingOAuthContext()
            userFacingError = nil
        } catch {
            clearPendingOAuthContext()
            userFacingError = "GitHub sign in failed. Please try again."
        }
    }
    
    func fetchOrganizations() async {
        guard let token = accessToken else { return }
        userFacingError = nil
        do {
            let service = gitHubServiceFactory(token)
            self.organizations = try await service.fetchOrganizations()
            reconcileSelectedOrgContext()
        } catch {
            logError("Failed to fetch orgs", error: error)
            handleGitHubFetchError(error, defaultMessage: "Failed to load organizations. Please try again.")
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
            logError("Failed to fetch repos", error: error)
            handleGitHubFetchError(error, defaultMessage: "Failed to load repositories. Please check your token and network.")
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
            logError("Failed to load more repos", error: error)
            handleGitHubFetchError(error, defaultMessage: "Failed to load more repositories.")
        }
    }
    
    func loadSessions() {
        do {
            self.sessions = try persistedSessionLoader()
            userFacingError = nil
        } catch {
            logError("Failed to load sessions", error: error)
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
                    logError("Failed to delete stale session", error: error)
                }
            }

            self.sessions = healthySessions
            userFacingError = nil
        } catch {
            logError("Failed to load sessions", error: error)
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
            logError("Failed to start session", error: error)
            let message = userMessage(for: error, fallback: "Failed to start session.")
            loadingMessage = "Error: \(message)"
            userFacingError = message
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
                logError("Failed to clean stale session", error: error)
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
            logError("Failed to delete session", error: error)
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

    private func clearPendingOAuthContext() {
        pendingOAuthState = nil
        pendingOAuthCodeVerifier = nil
        pendingOAuthRedirectURI = nil
    }

    private func persistSelectedOrgContextIfNeeded() {
        guard shouldPersistSelectedOrgContext else { return }

        if let login = selectedOrg?.login {
            UserDefaults.standard.set(login, forKey: Constants.Preferences.selectedOrgLogin)
        } else {
            UserDefaults.standard.removeObject(forKey: Constants.Preferences.selectedOrgLogin)
        }
    }

    private func setSelectedOrgWithoutPersisting(_ org: Organization?) {
        shouldPersistSelectedOrgContext = false
        selectedOrg = org
        shouldPersistSelectedOrgContext = true
    }

    private func persistTelemetryOptInIfNeeded() {
        guard shouldPersistTelemetryOptIn else { return }
        UserDefaults.standard.set(telemetryOptIn, forKey: Constants.Preferences.telemetryOptIn)
    }

    private func reconcileSelectedOrgContext() {
        if let currentOrg = selectedOrg,
           let matchingCurrentOrg = organizations.first(where: { $0.login == currentOrg.login }) {
            if currentOrg != matchingCurrentOrg {
                setSelectedOrgWithoutPersisting(matchingCurrentOrg)
            }
            return
        }

        if selectedOrg != nil {
            setSelectedOrgWithoutPersisting(nil)
        }

        guard let storedOrgLogin = UserDefaults.standard.string(forKey: Constants.Preferences.selectedOrgLogin) else {
            return
        }

        guard let matchingOrg = organizations.first(where: { $0.login == storedOrgLogin }) else {
            UserDefaults.standard.removeObject(forKey: Constants.Preferences.selectedOrgLogin)
            return
        }

        setSelectedOrgWithoutPersisting(matchingOrg)
    }

    private func handleGitHubFetchError(_ error: Error, defaultMessage: String) {
        if let gitHubError = error as? GitHubServiceError, gitHubError.requiresRelogin {
            clearAuthenticationStateAfterFailure()
            userFacingError = "Authentication expired. Please sign in again."
            return
        }

        userFacingError = defaultMessage
    }

    private func clearAuthenticationStateAfterFailure() {
        try? KeychainHelper.standard.delete(service: keychainService, account: keychainAccount)
        accessToken = nil
        isLoggedIn = false
        repositories = []
        organizations = []
        setSelectedOrgWithoutPersisting(nil)
        hasMoreRepos = false
        isLoadingMore = false
    }

    private func userMessage(for error: Error, fallback: String) -> String {
        if let zeroError = error as? ZeroError {
            switch zeroError {
            case .runtimeCommandFailed(let userMessage, _):
                return userMessage
            default:
                return zeroError.localizedDescription
            }
        }

        let generic = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return generic.isEmpty ? fallback : generic
    }

    private func logError(_ prefix: String, error: Error) {
        if let zeroError = error as? ZeroError,
           case let .runtimeCommandFailed(_, debugDetails) = zeroError {
            let message = "\(prefix): \(debugDetails)"
            AppLogStore.shared.append(message)
            print(message)
            return
        }

        let message = "\(prefix): \(error)"
        AppLogStore.shared.append(message)
        print(message)
    }
}

private struct OAuthTokenResponse: Decodable {
    let accessToken: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
    }
}

private enum OAuthFlowError: LocalizedError {
    case missingConfiguration

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return "OAuth is not configured. Set GitHub OAuth credentials in environment."
        }
    }
}
