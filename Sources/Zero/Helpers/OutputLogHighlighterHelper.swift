import Foundation

struct OutputLogLine: Equatable {
    let text: String
    let isError: Bool
}

enum OutputLogHighlighterHelper {
    private static let errorPatternRegexes = [
        #"\berror\b"#,
        #"\bfailed\b"#,
        #"\bexception\b"#,
        #"\bfatal\b"#,
        #"\btraceback\b"#,
        #"\bpanic\b"#
    ]

    private static let nonErrorPatternRegexes = [
        #"\b0\s+failures?\b"#,
        #"\b0\s+errors?\b"#,
        #"\bno\s+errors?\b"#,
        #"\bwithout\s+errors?\b"#,
        #"\berrors?\s*:\s*0\b"#,
        #"\bfailed\s*:\s*0\b"#,
        #"\bfailures\s*:\s*0\b"#
    ]

    static func lines(from output: String) -> [OutputLogLine] {
        let normalizedOutput = output
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        var rawLines = normalizedOutput.components(separatedBy: "\n")

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

        if nonErrorPatternRegexes.contains(where: { lineMatches($0, in: lowercased) }) {
            return false
        }

        return errorPatternRegexes.contains(where: { lineMatches($0, in: lowercased) })
    }

    private static func lineMatches(_ pattern: String, in line: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return false
        }

        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        return regex.firstMatch(in: line, options: [], range: range) != nil
    }
}
