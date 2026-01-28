import XCTest
@testable import Zero

final class SessionManagerTests: XCTestCase {
    
    // 테스트용 임시 파일 경로 사용
    var testStoreURL: URL!
    
    override func setUp() {
        super.setUp()
        testStoreURL = FileManager.default.temporaryDirectory.appendingPathComponent("sessions_test.json")
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: testStoreURL)
        super.tearDown()
    }

    func testCreateAndLoadSession() throws {
        // Given
        let manager = SessionManager(storeURL: testStoreURL)
        let repoURL = URL(string: "https://github.com/zero-ide/test-repo.git")!
        let containerName = "test-container-001"
        
        // When
        let session = try manager.createSession(repoURL: repoURL, containerName: containerName)
        let loadedSessions = try manager.loadSessions()
        
        // Then
        XCTAssertEqual(loadedSessions.count, 1)
        XCTAssertEqual(loadedSessions.first?.id, session.id)
        XCTAssertEqual(loadedSessions.first?.repoURL, repoURL)
        XCTAssertEqual(loadedSessions.first?.containerName, containerName)
    }
    
    func testDeleteSession() throws {
        // Given
        let manager = SessionManager(storeURL: testStoreURL)
        let repoURL = URL(string: "https://github.com/zero-ide/test-repo.git")!
        let session = try manager.createSession(repoURL: repoURL, containerName: "to-be-deleted")
        
        // When
        try manager.deleteSession(session)
        let loadedSessions = try manager.loadSessions()
        
        // Then
        XCTAssertTrue(loadedSessions.isEmpty)
    }
}
