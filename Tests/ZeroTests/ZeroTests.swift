import XCTest
@testable import Zero

final class ZeroTests: XCTestCase {
    func testAuthURLGeneration() throws {
        // Given
        let clientID = "test-client-id"
        let scope = "repo user"
        let authManager = AuthManager(clientID: clientID, scope: scope)

        // When
        let url = authManager.getLoginURL()

        // Then
        XCTAssertTrue(url.absoluteString.starts(with: "https://github.com/login/oauth/authorize"))
        XCTAssertTrue(url.absoluteString.contains("client_id=\(clientID)"))
        XCTAssertTrue(url.absoluteString.contains("scope=\(scope.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)"))
    }

    func testCodeExtractionFromCallbackURL() {
        // Given
        let authManager = AuthManager(clientID: "test", scope: "test")
        let callbackURL = URL(string: "zero://auth/callback?code=valid-code-123")!
        
        // When
        let code = authManager.extractCode(from: callbackURL)
        
        // Then
        XCTAssertEqual(code, "valid-code-123")
    }
}
