import XCTest
@testable import Zero

class MockGitHubService: GitHubService {
    var mockRepos: [Repository] = []
    var fetchCallCount = 0
    var lastPage = 0
    
    override func fetchRepositories(page: Int = 1) async throws -> [Repository] {
        fetchCallCount += 1
        lastPage = page
        return mockRepos
    }
}

@MainActor
final class AppStateTests: XCTestCase {
    
    func testInitialFetch() async {
        // Given
        let mockService = MockGitHubService(token: "test")
        let repo1 = Repository(id: 1, name: "repo1", fullName: "u/repo1", isPrivate: false, htmlURL: URL(string: "http://a")!, cloneURL: URL(string: "http://a")!)
        mockService.mockRepos = [repo1]
        
        let appState = AppState()
        appState.accessToken = "test"
        appState.gitHubServiceFactory = { _ in mockService }
        
        // When
        await appState.fetchRepositories()
        
        // Then
        XCTAssertEqual(appState.repositories.count, 1)
        XCTAssertEqual(appState.currentPage, 1)
        XCTAssertEqual(mockService.lastPage, 1)
    }
    
    func testLoadMore() async {
        // Given
        let mockService = MockGitHubService(token: "test")
        let repo1 = Repository(id: 1, name: "repo1", fullName: "u/repo1", isPrivate: false, htmlURL: URL(string: "http://a")!, cloneURL: URL(string: "http://a")!)
        let repo2 = Repository(id: 2, name: "repo2", fullName: "u/repo2", isPrivate: false, htmlURL: URL(string: "http://b")!, cloneURL: URL(string: "http://b")!)
        
        let appState = AppState()
        appState.accessToken = "test"
        appState.gitHubServiceFactory = { _ in mockService }
        appState.pageSize = 1 // 테스트용 페이지 사이즈 설정
        
        // 1페이지 로드 시뮬레이션
        mockService.mockRepos = [repo1]
        await appState.fetchRepositories()
        
        // When
        mockService.mockRepos = [repo2] // 2페이지 데이터 설정
        await appState.loadMoreRepositories()
        
        // Then
        XCTAssertEqual(appState.repositories.count, 2) // repo1 + repo2
        XCTAssertEqual(appState.currentPage, 2)
        XCTAssertEqual(mockService.lastPage, 2)
    }
}