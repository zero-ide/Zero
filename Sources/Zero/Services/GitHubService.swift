import Foundation

class GitHubService {
    private let token: String
    private let baseURL = "https://api.github.com"
    
    init(token: String) {
        self.token = token
    }
    
    func createFetchReposRequest(page: Int = 1) -> URLRequest {
        // per_page=30 (기본값), sort=updated
        let urlString = "\(baseURL)/user/repos?per_page=30&sort=updated&page=\(page)"
        let url = URL(string: urlString)!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        return request
    }
    
    func fetchRepositories(page: Int = 1) async throws -> [Repository] {
        let request = createFetchReposRequest(page: page)
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode([Repository].self, from: data)
    }
}
