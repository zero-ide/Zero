import Foundation
import Security
import CryptoKit

struct OAuthAuthorizationContext {
    let state: String
    let codeVerifier: String
    let codeChallenge: String
}

class AuthManager {
    let clientID: String
    let scope: String

    init(clientID: String, scope: String) {
        self.clientID = clientID
        self.scope = scope
    }

    func getLoginURL(
        state: String? = nil,
        codeChallenge: String? = nil,
        redirectURI: String? = nil
    ) -> URL {
        var components = URLComponents(string: "https://github.com/login/oauth/authorize")!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "scope", value: scope)
        ]

        if let state {
            queryItems.append(URLQueryItem(name: "state", value: state))
        }

        if let codeChallenge {
            queryItems.append(URLQueryItem(name: "code_challenge", value: codeChallenge))
            queryItems.append(URLQueryItem(name: "code_challenge_method", value: "S256"))
        }

        if let redirectURI {
            queryItems.append(URLQueryItem(name: "redirect_uri", value: redirectURI))
        }

        components.queryItems = queryItems
        return components.url!
    }

    func createAuthorizationContext() -> OAuthAuthorizationContext {
        let codeVerifier = randomURLSafeString(byteCount: 32)
        let verifierData = Data(codeVerifier.utf8)
        let codeChallengeData = Data(SHA256.hash(data: verifierData))
        let codeChallenge = base64URLEncodedString(from: codeChallengeData)
        let state = randomURLSafeString(byteCount: 16)

        return OAuthAuthorizationContext(
            state: state,
            codeVerifier: codeVerifier,
            codeChallenge: codeChallenge
        )
    }

    func extractCode(from url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return nil
        }
        return queryItems.first(where: { $0.name == "code" })?.value
    }

    func extractAuthorizationResponse(from url: URL) -> (code: String, state: String?)? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems,
              let code = queryItems.first(where: { $0.name == "code" })?.value else {
            return nil
        }

        let state = queryItems.first(where: { $0.name == "state" })?.value
        return (code: code, state: state)
    }

    func isValidCallbackState(expected: String, actual: String?) -> Bool {
        guard let actual else {
            return false
        }

        return expected == actual
    }

    func createTokenExchangeRequest(
        code: String,
        clientSecret: String,
        codeVerifier: String? = nil,
        redirectURI: String? = nil
    ) throws -> URLRequest {
        let url = URL(string: "https://github.com/login/oauth/access_token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: String] = [
            "client_id": clientID,
            "client_secret": clientSecret,
            "code": code
        ]

        if let codeVerifier {
            body["code_verifier"] = codeVerifier
        }

        if let redirectURI {
            body["redirect_uri"] = redirectURI
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        return request
    }

    private func randomURLSafeString(byteCount: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)

        if status != errSecSuccess {
            var generator = SystemRandomNumberGenerator()
            for index in bytes.indices {
                bytes[index] = UInt8.random(in: 0...255, using: &generator)
            }
        }

        return base64URLEncodedString(from: Data(bytes))
    }

    private func base64URLEncodedString(from data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
