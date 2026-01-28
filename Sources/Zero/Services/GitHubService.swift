import Foundation

class GitHubService {
    private let token: String
    private let baseURL = "https://api.github.com"
    
    init(token: String) {
        self.token = token
    }
    
    func createFetchReposRequest() -> URLRequest {
        let url = URL(string: "\(baseURL)/user/repos")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        return request
    }
    
    func fetchRepositories() async throws -> [Repository] {
        let request = createFetchReposRequest()
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode([Repository].self, from: data)
    }
}
