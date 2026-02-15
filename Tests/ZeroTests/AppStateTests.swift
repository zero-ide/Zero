import XCTest
@testable import Zero

@MainActor
class AppStateTests: XCTestCase {
    
    var appState: AppState!
    
    override func setUp() {
        super.setUp()
        // Clear keychain before test to ensure clean state
        try? KeychainHelper.standard.delete(service: "com.zero.ide", account: "github_token")
        UserDefaults.standard.removeObject(forKey: Constants.Preferences.selectedOrgLogin)
        appState = AppState()
    }
    
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: Constants.Preferences.selectedOrgLogin)
        appState = nil
        super.tearDown()
    }
    
    // MARK: - Initial State Tests
    
    func testInitialState() {
        // Then
        XCTAssertEqual(appState.isLoggedIn, false, "isLoggedIn should be false initially")
        XCTAssertEqual(appState.isEditing, false, "isEditing should be false initially")
        XCTAssertNil(appState.activeSession, "activeSession should be nil initially")
        // Note: sessions and repositories may not be empty due to persistence
    }
    
    // MARK: - Login State Tests
    
    func testLoginState() {
        // When
        appState.isLoggedIn = true
        
        // Then
        XCTAssertTrue(appState.isLoggedIn)
    }
    
    func testLogoutState() {
        // Given
        appState.isLoggedIn = true
        appState.sessions = [Session.mock]
        
        // When
        appState.isLoggedIn = false
        
        // Then
        XCTAssertFalse(appState.isLoggedIn)
    }

    func testBeginOAuthLoginReturnsAuthorizeURLAndStoresPendingState() throws {
        // Given
        appState.oauthClientIDProvider = { "client-id" }
        appState.oauthClientSecretProvider = { "client-secret" }
        appState.oauthRedirectURIProvider = { "zero://auth/callback" }

        // When
        let url = try appState.beginOAuthLogin()

        // Then
        XCTAssertTrue(url.absoluteString.starts(with: "https://github.com/login/oauth/authorize"))
        XCTAssertNotNil(appState.pendingOAuthStateForTesting)
        XCTAssertNotNil(appState.pendingOAuthCodeVerifierForTesting)
    }

    func testHandleOAuthCallbackWithStateMismatchShowsError() async {
        // Given
        appState.oauthClientIDProvider = { "client-id" }
        appState.oauthClientSecretProvider = { "client-secret" }
        appState.oauthRedirectURIProvider = { "zero://auth/callback" }
        _ = try? appState.beginOAuthLogin()
        let callback = URL(string: "zero://auth/callback?code=code-1&state=wrong-state")!

        // When
        await appState.handleOAuthCallback(callback)

        // Then
        XCTAssertFalse(appState.isLoggedIn)
        XCTAssertEqual(appState.userFacingError, "Authentication failed. Please try signing in again.")
    }

    func testHandleOAuthCallbackSuccessStoresTokenAndLogsIn() async {
        // Given
        appState.oauthClientIDProvider = { "client-id" }
        appState.oauthClientSecretProvider = { "client-secret" }
        appState.oauthRedirectURIProvider = { "zero://auth/callback" }
        appState.oauthTokenExchanger = { _ in "gho_test_token" }

        guard let loginURL = try? appState.beginOAuthLogin(),
              let loginComponents = URLComponents(url: loginURL, resolvingAgainstBaseURL: false),
              let expectedState = loginComponents.queryItems?.first(where: { $0.name == "state" })?.value else {
            XCTFail("Failed to prepare OAuth login context")
            return
        }

        let callback = URL(string: "zero://auth/callback?code=code-1&state=\(expectedState)")!

        // When
        await appState.handleOAuthCallback(callback)

        // Then
        XCTAssertTrue(appState.isLoggedIn)
        XCTAssertEqual(appState.accessToken, "gho_test_token")
        XCTAssertNil(appState.userFacingError)
    }

    func testHandleOAuthCallbackMissingConfigurationClearsPendingOAuthContext() async {
        // Given
        appState.oauthClientIDProvider = { "client-id" }
        appState.oauthClientSecretProvider = { "client-secret" }
        appState.oauthRedirectURIProvider = { "zero://auth/callback" }

        guard let loginURL = try? appState.beginOAuthLogin(),
              let loginComponents = URLComponents(url: loginURL, resolvingAgainstBaseURL: false),
              let expectedState = loginComponents.queryItems?.first(where: { $0.name == "state" })?.value else {
            XCTFail("Failed to prepare OAuth login context")
            return
        }

        appState.oauthClientSecretProvider = { nil }
        let callback = URL(string: "zero://auth/callback?code=code-1&state=\(expectedState)")!

        // When
        await appState.handleOAuthCallback(callback)

        // Then
        XCTAssertEqual(appState.userFacingError, "OAuth is not configured. Set GitHub OAuth credentials in environment.")
        XCTAssertNil(appState.pendingOAuthStateForTesting)
        XCTAssertNil(appState.pendingOAuthCodeVerifierForTesting)
    }

    func testHandleOAuthCallbackIgnoresNonMatchingRedirectAndKeepsPendingContext() async {
        // Given
        appState.oauthClientIDProvider = { "client-id" }
        appState.oauthClientSecretProvider = { "client-secret" }
        appState.oauthRedirectURIProvider = { "zero://auth/callback" }

        guard let loginURL = try? appState.beginOAuthLogin(),
              let loginComponents = URLComponents(url: loginURL, resolvingAgainstBaseURL: false),
              let expectedState = loginComponents.queryItems?.first(where: { $0.name == "state" })?.value else {
            XCTFail("Failed to prepare OAuth login context")
            return
        }

        let unrelatedURL = URL(string: "zero://other/path?code=code-1&state=\(expectedState)")!

        // When
        await appState.handleOAuthCallback(unrelatedURL)

        // Then
        XCTAssertNil(appState.userFacingError)
        XCTAssertNotNil(appState.pendingOAuthStateForTesting)
        XCTAssertNotNil(appState.pendingOAuthCodeVerifierForTesting)
        XCTAssertFalse(appState.isLoggedIn)
    }

    func testHandleOAuthCallbackUsesPendingRedirectURIForTokenExchangeRequest() async {
        // Given
        appState.oauthClientIDProvider = { "client-id" }
        appState.oauthClientSecretProvider = { "client-secret" }
        appState.oauthRedirectURIProvider = { "zero://auth/callback" }

        guard let loginURL = try? appState.beginOAuthLogin(),
              let loginComponents = URLComponents(url: loginURL, resolvingAgainstBaseURL: false),
              let expectedState = loginComponents.queryItems?.first(where: { $0.name == "state" })?.value else {
            XCTFail("Failed to prepare OAuth login context")
            return
        }

        appState.oauthRedirectURIProvider = { "zero://changed/callback" }

        var capturedRedirectURI: String?
        appState.oauthTokenExchanger = { request in
            let bodyData = try XCTUnwrap(request.httpBody)
            let bodyJSON = try JSONSerialization.jsonObject(with: bodyData) as? [String: String]
            capturedRedirectURI = bodyJSON?["redirect_uri"]
            return "gho_test_token"
        }

        let callback = URL(string: "zero://auth/callback?code=code-1&state=\(expectedState)")!

        // When
        await appState.handleOAuthCallback(callback)

        // Then
        XCTAssertEqual(capturedRedirectURI, "zero://auth/callback")
    }
    
    // MARK: - Editor State Tests
    
    func testOpenEditor() {
        // Given
        let session = Session.mock
        
        // When
        appState.activeSession = session
        appState.isEditing = true
        
        // Then
        XCTAssertTrue(appState.isEditing)
        XCTAssertEqual(appState.activeSession?.id, session.id)
    }
    
    func testCloseEditor() {
        // Given
        appState.activeSession = Session.mock
        appState.isEditing = true
        
        // When
        appState.closeEditor()
        
        // Then
        XCTAssertFalse(appState.isEditing)
        XCTAssertNil(appState.activeSession)
    }

    func testResumeSessionWithHealthyContainerOpensEditor() async {
        // Given
        let session = Session.mock
        appState.sessionContainerHealthCheck = { _ in true }

        // When
        await appState.resumeSession(session)

        // Then
        XCTAssertTrue(appState.isEditing)
        XCTAssertEqual(appState.activeSession?.id, session.id)
        XCTAssertNil(appState.userFacingError)
    }

    func testResumeSessionWithDeadContainerShowsErrorAndSkipsEditor() async {
        // Given
        let session = Session.mock
        appState.sessions = [session]
        appState.sessionContainerHealthCheck = { _ in false }

        // When
        await appState.resumeSession(session)

        // Then
        XCTAssertFalse(appState.isEditing)
        XCTAssertNil(appState.activeSession)
        XCTAssertEqual(appState.sessions.count, 0)
        XCTAssertEqual(appState.userFacingError, "Session is no longer available. Please start a new session.")
    }

    func testLoadSessionsWithHealthCheckPrunesStalePersistedSessions() async {
        // Given
        let healthySession = Session.mock
        let staleSession = Session(
            id: UUID(),
            repoURL: healthySession.repoURL,
            containerName: "zero-dev-stale",
            createdAt: Date(),
            lastActiveAt: Date()
        )

        var persistedSessions: [Session] = [healthySession, staleSession]
        appState.persistedSessionLoader = { persistedSessions }
        appState.persistedSessionDeleter = { session in
            persistedSessions.removeAll { $0.id == session.id }
        }
        appState.sessionContainerHealthCheck = { session in
            session.id == healthySession.id
        }

        // When
        await appState.loadSessionsWithHealthCheck()

        // Then
        XCTAssertEqual(appState.sessions.map(\.id), [healthySession.id])
        XCTAssertEqual(persistedSessions.map(\.id), [healthySession.id])
        XCTAssertNil(appState.userFacingError)
    }

    func testLoadSessionsWithHealthCheckShowsErrorWhenLoadingFails() async {
        // Given
        appState.persistedSessionLoader = {
            throw NSError(domain: "test", code: 1, userInfo: nil)
        }

        // When
        await appState.loadSessionsWithHealthCheck()

        // Then
        XCTAssertEqual(appState.userFacingError, "Failed to load sessions.")
    }
    
    // MARK: - Session Management Tests
    
    func testAddSession() {
        // Given
        let session = Session.mock
        
        // When
        appState.sessions.append(session)
        
        // Then
        XCTAssertEqual(appState.sessions.count, 1)
        XCTAssertEqual(appState.sessions.first?.id, session.id)
    }
    
    func testRemoveSession() {
        // Given
        let session = Session.mock
        appState.sessions = [session]
        
        // When
        appState.sessions.removeAll { $0.id == session.id }
        
        // Then
        XCTAssertTrue(appState.sessions.isEmpty)
    }
    
    // MARK: - Repository Tests
    
    func testLoadRepositories() {
        // Given
        let repos = [
            Repository.mock(id: 1, name: "repo1"),
            Repository.mock(id: 2, name: "repo2")
        ]
        
        // When
        appState.repositories = repos
        
        // Then
        XCTAssertEqual(appState.repositories.count, 2)
        XCTAssertEqual(appState.repositories.first?.name, "repo1")
    }

    func testFetchRepositoriesAuthErrorForcesLogoutAndShowsReloginMessage() async {
        // Given
        appState.isLoggedIn = true
        appState.accessToken = "gho_test_token"
        appState.gitHubServiceFactory = { _ in
            MockGitHubService(fetchReposError: GitHubServiceError.unauthorized)
        }

        // When
        await appState.fetchRepositories()

        // Then
        XCTAssertFalse(appState.isLoggedIn)
        XCTAssertNil(appState.accessToken)
        XCTAssertEqual(appState.userFacingError, "Authentication expired. Please sign in again.")
    }

    func testFetchRepositoriesNonAuthErrorKeepsLoginState() async {
        // Given
        appState.isLoggedIn = true
        appState.accessToken = "gho_test_token"
        appState.gitHubServiceFactory = { _ in
            MockGitHubService(fetchReposError: URLError(.timedOut))
        }

        // When
        await appState.fetchRepositories()

        // Then
        XCTAssertTrue(appState.isLoggedIn)
        XCTAssertEqual(appState.accessToken, "gho_test_token")
        XCTAssertEqual(appState.userFacingError, "Failed to load repositories. Please check your token and network.")
    }

    func testFetchOrganizationsAuthErrorForcesLogoutAndClearsSelection() async {
        // Given
        appState.isLoggedIn = true
        appState.accessToken = "gho_test_token"
        appState.organizations = [Organization(id: 1, login: "zero-ide", avatarURL: nil, description: nil)]
        appState.selectedOrg = appState.organizations.first
        appState.gitHubServiceFactory = { _ in
            MockGitHubService(fetchOrgsError: GitHubServiceError.unauthorized)
        }

        // When
        await appState.fetchOrganizations()

        // Then
        XCTAssertFalse(appState.isLoggedIn)
        XCTAssertNil(appState.accessToken)
        XCTAssertTrue(appState.organizations.isEmpty)
        XCTAssertNil(appState.selectedOrg)
        XCTAssertEqual(appState.userFacingError, "Authentication expired. Please sign in again.")
    }

    func testFetchOrganizationsForbiddenErrorKeepsLoginState() async {
        // Given
        appState.isLoggedIn = true
        appState.accessToken = "gho_test_token"
        appState.gitHubServiceFactory = { _ in
            MockGitHubService(fetchOrgsError: GitHubServiceError.forbidden)
        }

        // When
        await appState.fetchOrganizations()

        // Then
        XCTAssertTrue(appState.isLoggedIn)
        XCTAssertEqual(appState.accessToken, "gho_test_token")
        XCTAssertEqual(appState.userFacingError, "Failed to load organizations. Please try again.")
    }

    func testLoadMoreRepositoriesAuthErrorForcesLogoutAndStopsPagination() async {
        // Given
        appState.isLoggedIn = true
        appState.accessToken = "gho_test_token"
        appState.repositories = [Repository.mock(id: 1, name: "repo1")]
        appState.currentPage = 1
        appState.hasMoreRepos = true
        appState.gitHubServiceFactory = { _ in
            MockGitHubService(fetchReposError: GitHubServiceError.unauthorized)
        }

        // When
        await appState.loadMoreRepositories()

        // Then
        XCTAssertFalse(appState.isLoggedIn)
        XCTAssertNil(appState.accessToken)
        XCTAssertFalse(appState.hasMoreRepos)
        XCTAssertFalse(appState.isLoadingMore)
        XCTAssertEqual(appState.userFacingError, "Authentication expired. Please sign in again.")
    }

    func testFetchOrganizationsRestoresPreviouslySelectedOrgContext() async {
        // Given
        UserDefaults.standard.set("zero-ide", forKey: Constants.Preferences.selectedOrgLogin)
        appState.gitHubServiceFactory = { _ in
            MockGitHubService(
                organizationsResult: [
                    Organization(id: 1, login: "zero-ide", avatarURL: nil, description: nil),
                    Organization(id: 2, login: "another-org", avatarURL: nil, description: nil)
                ]
            )
        }
        appState.accessToken = "gho_test_token"

        // When
        await appState.fetchOrganizations()

        // Then
        XCTAssertEqual(appState.selectedOrg?.login, "zero-ide")
    }

    func testFetchOrganizationsFallsBackToPersonalWhenStoredOrgIsMissing() async {
        // Given
        UserDefaults.standard.set("missing-org", forKey: Constants.Preferences.selectedOrgLogin)
        appState.selectedOrg = Organization(id: 99, login: "stale-org", avatarURL: nil, description: nil)
        appState.gitHubServiceFactory = { _ in
            MockGitHubService(
                organizationsResult: [
                    Organization(id: 1, login: "zero-ide", avatarURL: nil, description: nil)
                ]
            )
        }
        appState.accessToken = "gho_test_token"

        // When
        await appState.fetchOrganizations()

        // Then
        XCTAssertNil(appState.selectedOrg)
    }

    func testSelectedOrgChangePersistsContextAndPersonalClearsStoredContext() {
        // Given
        let org = Organization(id: 1, login: "zero-ide", avatarURL: nil, description: nil)

        // When
        appState.selectedOrg = org

        // Then
        XCTAssertEqual(UserDefaults.standard.string(forKey: Constants.Preferences.selectedOrgLogin), "zero-ide")

        // When
        appState.selectedOrg = nil

        // Then
        XCTAssertNil(UserDefaults.standard.string(forKey: Constants.Preferences.selectedOrgLogin))
    }
    
    func testSelectRepository() {
        // Given
        let repo = Repository.mock(id: 1, name: "selected-repo")
        
        // When - Simulate selection
        let selectedName = repo.name
        
        // Then
        XCTAssertEqual(selectedName, "selected-repo")
    }
}

// MARK: - Mocks

extension Session {
    static var mock: Session {
        Session(
            id: UUID(),
            repoURL: URL(string: "https://github.com/user/repo.git")!,
            containerName: "zero-dev-test",
            createdAt: Date(),
            lastActiveAt: Date()
        )
    }
}

extension Repository {
    static func mock(id: Int, name: String) -> Repository {
        Repository(
            id: id,
            name: name,
            fullName: "user/\(name)",
            isPrivate: false,
            htmlURL: URL(string: "https://github.com/user/\(name)")!,
            cloneURL: URL(string: "https://github.com/user/\(name).git")!
        )
    }
}

private final class MockGitHubService: GitHubService {
    private let fetchReposError: Error?
    private let fetchOrgsError: Error?
    private let fetchOrgReposError: Error?
    private let organizationsResult: [Organization]

    init(
        fetchReposError: Error? = nil,
        fetchOrgsError: Error? = nil,
        fetchOrgReposError: Error? = nil,
        organizationsResult: [Organization] = []
    ) {
        self.fetchReposError = fetchReposError
        self.fetchOrgsError = fetchOrgsError
        self.fetchOrgReposError = fetchOrgReposError
        self.organizationsResult = organizationsResult
        super.init(token: "gho_test_token")
    }

    override func fetchRepositories(page: Int = 1, type: String? = nil) async throws -> [Repository] {
        if let fetchReposError {
            throw fetchReposError
        }

        return []
    }

    override func fetchOrganizations() async throws -> [Organization] {
        if let fetchOrgsError {
            throw fetchOrgsError
        }

        return organizationsResult
    }

    override func fetchOrgRepositories(org: String, page: Int = 1) async throws -> [Repository] {
        if let fetchOrgReposError {
            throw fetchOrgReposError
        }

        return []
    }
}
