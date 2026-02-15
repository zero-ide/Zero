import XCTest
@testable import Zero

final class GitHubServiceTests: XCTestCase {
    
    func testFetchRepositoriesRequestCreation() throws {
        // Given
        let token = "ghp_test_token"
        let service = GitHubService(token: token)
        
        // When
        let request = service.createFetchReposRequest(page: 2, type: "owner")
        
        // Then
        let url = request.url?.absoluteString
        XCTAssertTrue(url?.contains("per_page=30") ?? false)
        XCTAssertTrue(url?.contains("page=2") ?? false)
        XCTAssertTrue(url?.contains("type=owner") ?? false) // type 파라미터 확인
        XCTAssertTrue(url?.contains("sort=updated") ?? false)
        XCTAssertEqual(request.url?.path, "/user/repos")
    }
    
    func testFetchOrgsRequestCreation() throws {
        // Given
        let token = "ghp_test_token"
        let service = GitHubService(token: token)
        
        // When
        let request = service.createFetchOrgsRequest()
        
        // Then
        XCTAssertEqual(request.url?.path, "/user/orgs")
        XCTAssertTrue(request.url?.query?.contains("per_page=100") ?? false)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer ghp_test_token")
    }
    
    func testFetchOrgReposRequestCreation() throws {
        // Given
        let token = "ghp_test_token"
        let service = GitHubService(token: token)
        let orgName = "zero-ide"
        
        // When
        let request = service.createFetchOrgReposRequest(org: orgName, page: 3)
        
        // Then
        let url = request.url?.absoluteString
        XCTAssertTrue(url?.contains("/orgs/zero-ide/repos") ?? false)
        XCTAssertTrue(url?.contains("page=3") ?? false)
        XCTAssertEqual(request.httpMethod, "GET")
    }
    
    func testDecodeRepositories() throws {
        // Given
        let json = """
        [
            {
                "id": 123,
                "name": "test-repo",
                "full_name": "user/test-repo",
                "private": false,
                "html_url": "https://github.com/user/test-repo",
                "clone_url": "https://github.com/user/test-repo.git"
            }
        ]
        """.data(using: .utf8)!
        
        // When
        let repos = try JSONDecoder().decode([Repository].self, from: json)
        
        // Then
        XCTAssertEqual(repos.count, 1)
        XCTAssertEqual(repos.first?.name, "test-repo")
        XCTAssertEqual(repos.first?.fullName, "user/test-repo")
        XCTAssertEqual(repos.first?.isPrivate, false)
    }
    
    func testDecodeOrganizations() throws {
        // Given
        let json = """
        [
            {
                "id": 1,
                "login": "github",
                "description": "How people build software.",
                "avatar_url": "https://github.com/images/error/octocat_happy.gif"
            }
        ]
        """.data(using: .utf8)!
        
        // When
        let orgs = try JSONDecoder().decode([Organization].self, from: json)
        
        // Then
        XCTAssertEqual(orgs.count, 1)
        XCTAssertEqual(orgs.first?.login, "github")
        XCTAssertEqual(orgs.first?.description, "How people build software.")
    }
}
