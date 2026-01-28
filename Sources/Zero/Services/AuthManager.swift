import Foundation

class AuthManager {
    let clientID: String
    let scope: String

    init(clientID: String, scope: String) {
        self.clientID = clientID
        self.scope = scope
    }

    func getLoginURL() -> URL {
        var components = URLComponents(string: "https://github.com/login/oauth/authorize")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "scope", value: scope)
        ]
        return components.url!
    }

    func extractCode(from url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return nil
        }
        return queryItems.first(where: { $0.name == "code" })?.value
    }

    func createTokenExchangeRequest(code: String, clientSecret: String) throws -> URLRequest {
        let url = URL(string: "https://github.com/login/oauth/access_token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = [
            "client_id": clientID,
            "client_secret": clientSecret,
            "code": code
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        return request
    }
}
