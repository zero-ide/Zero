import XCTest
@testable import Zero

final class OutputLogHighlighterTests: XCTestCase {
    func testLinesDetectErrorLikePatternsCaseInsensitive() {
        // Given
        let output = """
        build started
        ERROR: compile failed
        Unhandled Exception in worker
        """

        // When
        let lines = OutputLogHighlighterHelper.lines(from: output)

        // Then
        XCTAssertEqual(lines.count, 3)
        XCTAssertFalse(lines[0].isError)
        XCTAssertTrue(lines[1].isError)
        XCTAssertTrue(lines[2].isError)
    }

    func testLinesTreatSuccessFailureSummaryAsNonError() {
        // Given
        let output = "Test Suite passed. Executed 144 tests, with 0 failures in 0.9s"

        // When
        let lines = OutputLogHighlighterHelper.lines(from: output)

        // Then
        XCTAssertEqual(lines.count, 1)
        XCTAssertFalse(lines[0].isError)
    }

    func testFilteredLinesReturnsOnlyErrorsWhenEnabled() {
        // Given
        let output = """
        compiling project
        warning: deprecated API
        fatal error: index out of range
        build failed
        done
        """

        // When
        let lines = OutputLogHighlighterHelper.filteredLines(from: output, errorsOnly: true)

        // Then
        XCTAssertEqual(lines.map(\.text), ["fatal error: index out of range", "build failed"])
        XCTAssertTrue(lines.allSatisfy(\.isError))
    }

    func testFilteredLinesReturnsAllLinesWhenErrorsOnlyDisabled() {
        // Given
        let output = "line 1\nline 2"

        // When
        let lines = OutputLogHighlighterHelper.filteredLines(from: output, errorsOnly: false)

        // Then
        XCTAssertEqual(lines.map(\.text), ["line 1", "line 2"])
    }
}
