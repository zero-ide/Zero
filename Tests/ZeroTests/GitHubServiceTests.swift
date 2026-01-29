import XCTest
@testable import Zero

final class GitHubServiceTests: XCTestCase {
    
    func testFetchRepositoriesRequestCreation() throws {
        // Given
        let token = "ghp_test_token"
        let service = GitHubService(token: token)
        
        // When
        let request = service.createFetchReposRequest(page: 2)
        
        // Then
        let url = request.url?.absoluteString
        XCTAssertTrue(url?.contains("per_page=30") ?? false) // 30개씩 끊어서 가져오기
        XCTAssertTrue(url?.contains("page=2") ?? false)
        XCTAssertTrue(url?.contains("sort=updated") ?? false)
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
}
