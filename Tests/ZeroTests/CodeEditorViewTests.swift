import XCTest
import Darwin
import Foundation
@testable import Zero

@MainActor
final class CodeEditorViewTests: XCTestCase {
    override func setUp() {
        super.setUp()
        AppLogStore.shared.clear()
    }

    override func tearDown() {
        AppLogStore.shared.clear()
        super.tearDown()
    }

    func testSetupWithInvalidThemeDoesNotPrintToStdout() {
        let textView = HighlightedTextView(frame: .zero)

        let stdout = captureStdout {
            textView.setup(language: "swift", themeName: "__invalid_theme__")
        }

        XCTAssertTrue(stdout.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty)
    }

    func testSetupWithInvalidThemeAppendsFailureToAppLogStore() {
        let textView = HighlightedTextView(frame: .zero)

        textView.setup(language: "swift", themeName: "__invalid_theme__")

        let logEntries = AppLogStore.shared.recentEntries()
        XCTAssertTrue(logEntries.contains { entry in
            entry.contains("Failed to load theme") && entry.contains("__invalid_theme__")
        })
    }

    private func captureStdout(_ operation: () -> Void) -> String {
        fflush(stdout)

        let outputPipe = Pipe()
        let originalStdout = dup(STDOUT_FILENO)
        dup2(outputPipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)

        operation()

        fflush(stdout)
        dup2(originalStdout, STDOUT_FILENO)
        close(originalStdout)

        outputPipe.fileHandleForWriting.closeFile()
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        outputPipe.fileHandleForReading.closeFile()

        return String(data: outputData, encoding: .utf8) ?? ""
    }
}
