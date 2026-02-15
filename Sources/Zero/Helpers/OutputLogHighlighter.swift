import Foundation

struct OutputLogLine: Equatable {
    let text: String
    let isError: Bool
}

enum OutputLogHighlighter {
    private static let errorPatterns = [
        "error",
        "failed",
        "exception",
        "fatal",
        "traceback",
        "panic"
    ]

    private static let nonErrorPatterns = [
        "0 failures",
        "0 failed",
        "0 errors",
        "no errors",
        "without errors",
        "error: 0",
        "failed: 0",
        "failures: 0"
    ]

    static func lines(from output: String) -> [OutputLogLine] {
        var rawLines = output.components(separatedBy: .newlines)

        while rawLines.last == "" {
            rawLines.removeLast()
        }

        return rawLines.map { line in
            OutputLogLine(text: line, isError: isErrorLine(line))
        }
    }

    static func filteredLines(from output: String, errorsOnly: Bool) -> [OutputLogLine] {
        let allLines = lines(from: output)
        return errorsOnly ? allLines.filter(\.isError) : allLines
    }

    private static func isErrorLine(_ line: String) -> Bool {
        let lowercased = line.lowercased()

        if nonErrorPatterns.contains(where: { lowercased.contains($0) }) {
            return false
        }

        return errorPatterns.contains(where: { lowercased.contains($0) })
    }
}
