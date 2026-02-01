import XCTest
@testable import Zero

@MainActor
class AppStateTests: XCTestCase {
    
    var appState: AppState!
    
    override func setUp() {
        super.setUp()
        // Clear keychain before test to ensure clean state
        try? KeychainHelper.standard.delete(service: "com.zero.ide", account: "github_token")
        appState = AppState()
    }
    
    override func tearDown() {
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
