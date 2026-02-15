import XCTest
@testable import Zero

final class AuthManagerTests: XCTestCase {
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

    func testAuthURLIncludesPKCEStateAndRedirectURI() throws {
        // Given
        let authManager = AuthManager(clientID: "client-id", scope: "repo")

        // When
        let url = authManager.getLoginURL(
            state: "test-state",
            codeChallenge: "test-code-challenge",
            redirectURI: "zero://auth/callback"
        )

        // Then
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let queryItems = try XCTUnwrap(components.queryItems)

        XCTAssertEqual(queryItems.first(where: { $0.name == "state" })?.value, "test-state")
        XCTAssertEqual(queryItems.first(where: { $0.name == "code_challenge" })?.value, "test-code-challenge")
        XCTAssertEqual(queryItems.first(where: { $0.name == "code_challenge_method" })?.value, "S256")
        XCTAssertEqual(queryItems.first(where: { $0.name == "redirect_uri" })?.value, "zero://auth/callback")
    }

    func testCallbackExtractionIncludesState() {
        // Given
        let authManager = AuthManager(clientID: "client-id", scope: "repo")
        let callbackURL = URL(string: "zero://auth/callback?code=abc123&state=state-1")!

        // When
        let response = authManager.extractAuthorizationResponse(from: callbackURL)

        // Then
        XCTAssertEqual(response?.code, "abc123")
        XCTAssertEqual(response?.state, "state-1")
    }

    func testValidateCallbackStateRejectsMismatch() {
        // Given
        let authManager = AuthManager(clientID: "client-id", scope: "repo")

        // When
        let isValid = authManager.isValidCallbackState(expected: "state-1", actual: "state-2")

        // Then
        XCTAssertFalse(isValid)
    }

    func testTokenExchangeRequestIncludesCodeVerifierAndRedirectURI() throws {
        // Given
        let authManager = AuthManager(clientID: "client-id", scope: "repo")

        // When
        let request = try authManager.createTokenExchangeRequest(
            code: "auth-code",
            clientSecret: "client-secret",
            codeVerifier: "verifier-123",
            redirectURI: "zero://auth/callback"
        )

        // Then
        let bodyData = try XCTUnwrap(request.httpBody)
        let bodyJSON = try JSONSerialization.jsonObject(with: bodyData) as? [String: String]

        XCTAssertEqual(bodyJSON?["code_verifier"], "verifier-123")
        XCTAssertEqual(bodyJSON?["redirect_uri"], "zero://auth/callback")
    }
}
