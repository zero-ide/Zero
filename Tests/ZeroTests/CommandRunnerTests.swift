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

    func testExecuteThrowsStructuredErrorForNonZeroExit() {
        // Given
        let runner = CommandRunner()

        // When & Then
        XCTAssertThrowsError(
            try runner.execute(command: "/bin/sh", arguments: ["-c", "echo boom >&2; exit 7"])
        ) { error in
            guard case let CommandRunnerError.commandFailed(command, arguments, exitCode, stdout, stderr) = error else {
                XCTFail("Expected CommandRunnerError.commandFailed")
                return
            }

            XCTAssertEqual(command, "/bin/sh")
            XCTAssertEqual(arguments, ["-c", "echo boom >&2; exit 7"])
            XCTAssertEqual(exitCode, 7)
            XCTAssertTrue(stdout.isEmpty)
            XCTAssertTrue(stderr.contains("boom"))
        }
    }

    func testExecuteThrowsErrorWithSeparatedStdoutAndStderr() {
        // Given
        let runner = CommandRunner()

        // When & Then
        XCTAssertThrowsError(
            try runner.execute(command: "/bin/sh", arguments: ["-c", "echo out; echo err >&2; exit 3"])
        ) { error in
            guard case let CommandRunnerError.commandFailed(_, _, exitCode, stdout, stderr) = error else {
                XCTFail("Expected CommandRunnerError.commandFailed")
                return
            }

            XCTAssertEqual(exitCode, 3)
            XCTAssertTrue(stdout.contains("out"))
            XCTAssertTrue(stderr.contains("err"))
        }
    }
}
