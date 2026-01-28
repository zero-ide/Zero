import Foundation

class AuthManager {
    let clientID: String
    let scope: String

    init(clientID: String, scope: String) {
        self.clientID = clientID
        self.scope = scope
    }

    func getLoginURL() -> URL {
        return URL(string: "https://invalid-url.com")! // 일부러 틀리게 작성 (테스트 실패 유도)
    }
}
