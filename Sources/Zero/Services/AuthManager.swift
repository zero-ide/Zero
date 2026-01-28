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
}
