import XCTest
@testable import Zero

final class OutputLogHighlighterTests: XCTestCase {
    func testLinesDetectErrorLikePatternsCaseInsensitive() {
        let output = """
        build started
        ERROR: compile failed
        Unhandled Exception in worker
        """

        let lines = OutputLogHighlighter.lines(from: output)

        XCTAssertEqual(lines.count, 3)
        XCTAssertFalse(lines[0].isError)
        XCTAssertTrue(lines[1].isError)
        XCTAssertTrue(lines[2].isError)
    }

    func testLinesTreatSuccessFailureSummaryAsNonError() {
        let output = "Test Suite passed. Executed 144 tests, with 0 failures in 0.9s"

        let lines = OutputLogHighlighter.lines(from: output)

        XCTAssertEqual(lines.count, 1)
        XCTAssertFalse(lines[0].isError)
    }

    func testFilteredLinesReturnsOnlyErrorsWhenEnabled() {
        let output = """
        compiling project
        warning: deprecated API
        fatal error: index out of range
        build failed
        done
        """

        let lines = OutputLogHighlighter.filteredLines(from: output, errorsOnly: true)

        XCTAssertEqual(lines.map(\.text), ["fatal error: index out of range", "build failed"])
        XCTAssertTrue(lines.allSatisfy(\.isError))
    }

    func testFilteredLinesReturnsAllLinesWhenErrorsOnlyDisabled() {
        let output = "line 1\nline 2"

        let lines = OutputLogHighlighter.filteredLines(from: output, errorsOnly: false)

        XCTAssertEqual(lines.map(\.text), ["line 1", "line 2"])
    }
}
