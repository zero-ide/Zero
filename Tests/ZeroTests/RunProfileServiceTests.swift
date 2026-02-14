import XCTest
@testable import Zero

final class RunProfileServiceTests: XCTestCase {
    private var service: FileBasedRunProfileService!
    private var testConfigPath: String!

    override func setUp() {
        super.setUp()
        testConfigPath = "/tmp/test-zero-run-profiles-\(UUID().uuidString).json"
        service = FileBasedRunProfileService(configPath: testConfigPath)
    }

    override func tearDown() {
        if let testConfigPath {
            try? FileManager.default.removeItem(atPath: testConfigPath)
        }
        service = nil
        super.tearDown()
    }

    func testLoadCommandReturnsNilWhenNoProfileExists() throws {
        // Given
        let repositoryURL = URL(string: "https://github.com/zero-ide/Zero.git")!

        // When
        let command = try service.loadCommand(for: repositoryURL)

        // Then
        XCTAssertNil(command)
    }

    func testSaveAndLoadCommandForRepository() throws {
        // Given
        let repositoryURL = URL(string: "https://github.com/zero-ide/Zero.git")!

        // When
        try service.save(command: "swift run --configuration release", for: repositoryURL)
        let command = try service.loadCommand(for: repositoryURL)

        // Then
        XCTAssertEqual(command, "swift run --configuration release")
    }

    func testRemoveCommandClearsOnlyTargetRepository() throws {
        // Given
        let firstRepository = URL(string: "https://github.com/zero-ide/Zero.git")!
        let secondRepository = URL(string: "https://github.com/zero-ide/ZeroDocs.git")!
        try service.save(command: "swift run", for: firstRepository)
        try service.save(command: "npm start", for: secondRepository)

        // When
        try service.removeCommand(for: firstRepository)

        // Then
        XCTAssertNil(try service.loadCommand(for: firstRepository))
        XCTAssertEqual(try service.loadCommand(for: secondRepository), "npm start")
    }
}
