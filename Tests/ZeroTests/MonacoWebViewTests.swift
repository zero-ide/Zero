import XCTest
@testable import Zero

final class MonacoWebViewTests: XCTestCase {
    func testEscapeForJavaScriptLiteralEscapesCriticalCharacters() {
        // Given
        let source = "path\\to\\file\nlet value = 'hello'"

        // When
        let escaped = MonacoWebView.escapeForJavaScriptLiteral(source)

        // Then
        XCTAssertEqual(escaped, "path\\\\to\\\\file\\nlet value = \\\'hello\\\'")
    }

    func testFileURIFromPathNormalizesAbsoluteWorkspacePath() {
        // Given
        let path = "/workspace/src/Main.java"

        // When
        let uri = MonacoWebView.fileURI(from: path)

        // Then
        XCTAssertEqual(uri, "file:///workspace/src/Main.java")
    }

    func testFileURIFromPathFallsBackToMainJava() {
        // When
        let uri = MonacoWebView.fileURI(from: nil)

        // Then
        XCTAssertEqual(uri, "file:///workspace/Main.java")
    }
}
