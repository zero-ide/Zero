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

    func testTokenExchangeRequestCreation() throws {
        // Given
        let clientID = "my-client-id"
        let clientSecret = "my-client-secret"
        let code = "auth-code-123"
        let authManager = AuthManager(clientID: clientID, scope: "repo")
        
        // When
        let request = try authManager.createTokenExchangeRequest(code: code, clientSecret: clientSecret)
        
        // Then
        XCTAssertEqual(request.url?.absoluteString, "https://github.com/login/oauth/access_token")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        
        // Body Check
        let bodyData = try XCTUnwrap(request.httpBody)
        let bodyJSON = try JSONSerialization.jsonObject(with: bodyData) as? [String: String]
        
        XCTAssertEqual(bodyJSON?["client_id"], clientID)
        XCTAssertEqual(bodyJSON?["client_secret"], clientSecret)
        XCTAssertEqual(bodyJSON?["code"], code)
    }
}
