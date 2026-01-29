import XCTest
@testable import Zero

final class KeychainHelperTests: XCTestCase {
    
    // 테스트 실행 전후로 키체인 정리는 필수
    override func tearDown() {
        super.tearDown()
        let helper = KeychainHelper.standard
        try? helper.delete(service: "test-service", account: "test-account")
    }

    func testSaveAndLoad() throws {
        // Given
        let helper = KeychainHelper.standard
        let data = "secret-token".data(using: .utf8)!
        let service = "test-service"
        let account = "test-account"
        
        // When
        try helper.save(data, service: service, account: account)
        let loadedData = try helper.read(service: service, account: account)
        
        // Then
        XCTAssertEqual(loadedData, data)
    }
    
    func testDelete() throws {
        // Given
        let helper = KeychainHelper.standard
        let data = "to-be-deleted".data(using: .utf8)!
        try helper.save(data, service: "test-service", account: "test-account")
        
        // When
        try helper.delete(service: "test-service", account: "test-account")
        let loadedData = try helper.read(service: "test-service", account: "test-account")
        
        // Then
        XCTAssertNil(loadedData)
    }
}
