import XCTest
@testable import Zero

final class CommandRunnerTests: XCTestCase {
    func testExecuteEcho() throws {
        // Given
        let runner = CommandRunner()
        
        // When
        let output = try runner.execute(command: "/bin/echo", arguments: ["Hello, Zero!"])
        
        // Then
        XCTAssertEqual(output.trimmingCharacters(in: .whitespacesAndNewlines), "Hello, Zero!")
    }
}
