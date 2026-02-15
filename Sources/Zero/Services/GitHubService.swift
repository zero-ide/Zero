import Foundation

enum GitHubServiceError: Error, Equatable {
    case invalidResponse
    case unauthorized
    case forbidden
    case rateLimited
    case badStatusCode(Int)

    var requiresRelogin: Bool {
        switch self {
        case .unauthorized:
            return true
        case .invalidResponse, .forbidden, .rateLimited, .badStatusCode:
            return false
        }
    }
}

class GitHubService {
    private let token: String
    private let baseURL = "https://api.github.com"
    
    init(token: String) {
        self.token = token
    }
    
    func createFetchReposRequest(page: Int = 1, type: String? = nil) -> URLRequest {
        // per_page=30 (기본값), sort=updated
        var urlString = "\(baseURL)/user/repos?per_page=30&sort=updated&page=\(page)"
        if let type = type {
            urlString += "&type=\(type)"
        }
        
        let url = URL(string: urlString)!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        return request
    }
    
    func createFetchOrgsRequest() -> URLRequest {
        let url = URL(string: "\(baseURL)/user/orgs")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        return request
    }
    
    func createFetchOrgReposRequest(org: String, page: Int = 1) -> URLRequest {
        let urlString = "\(baseURL)/orgs/\(org)/repos?per_page=30&sort=updated&page=\(page)"
        let url = URL(string: urlString)!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        return request
    }
    
    func fetchRepositories(page: Int = 1, type: String? = nil) async throws -> [Repository] {
        let request = createFetchReposRequest(page: page, type: type)
        let (data, response) = try await URLSession.shared.data(for: request)

        try validateResponse(response)
        
        return try JSONDecoder().decode([Repository].self, from: data)
    }
    
    func fetchOrganizations() async throws -> [Organization] {
        let request = createFetchOrgsRequest()
        let (data, response) = try await URLSession.shared.data(for: request)

        try validateResponse(response)
        
        return try JSONDecoder().decode([Organization].self, from: data)
    }
    
    func fetchOrgRepositories(org: String, page: Int = 1) async throws -> [Repository] {
        let request = createFetchOrgReposRequest(org: org, page: page)
        let (data, response) = try await URLSession.shared.data(for: request)

        try validateResponse(response)
        
        return try JSONDecoder().decode([Repository].self, from: data)
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubServiceError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            return
        case 401:
            throw GitHubServiceError.unauthorized
        case 403:
            throw GitHubServiceError.forbidden
        case 429:
            throw GitHubServiceError.rateLimited
        default:
            throw GitHubServiceError.badStatusCode(httpResponse.statusCode)
        }
    }
}
