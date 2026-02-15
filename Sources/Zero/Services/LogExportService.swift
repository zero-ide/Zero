import Foundation

enum LogExportServiceError: LocalizedError {
    case failedToWrite(URL)

    var errorDescription: String? {
        switch self {
        case .failedToWrite(let url):
            return "Failed to write log bundle to \(url.path)."
        }
    }
}

final class LogExportService {
    private let fileManager: FileManager
    private let now: () -> Date

    init(fileManager: FileManager = .default, now: @escaping () -> Date = Date.init) {
        self.fileManager = fileManager
        self.now = now
    }

    func export(
        snapshot: DiagnosticsSnapshot?,
        executionOutput: String,
        appLogs: [String],
        to directory: URL? = nil
    ) throws -> URL {
        let exportDirectory = directory ?? defaultExportDirectory()
        try fileManager.createDirectory(at: exportDirectory, withIntermediateDirectories: true)

        let filename = "zero-logs-\(timestampForFilename(now())).txt"
        let destination = exportDirectory.appendingPathComponent(filename)
        let text = buildBundleText(snapshot: snapshot, executionOutput: executionOutput, appLogs: appLogs)

        do {
            try text.write(to: destination, atomically: true, encoding: .utf8)
            return destination
        } catch {
            throw LogExportServiceError.failedToWrite(destination)
        }
    }

    func buildBundleText(snapshot: DiagnosticsSnapshot?, executionOutput: String, appLogs: [String]) -> String {
        let generatedAt = ISO8601DateFormatter().string(from: now())

        var sections: [String] = []
        sections.append("# Zero Runtime Log Bundle")
        sections.append("Generated At: \(generatedAt)")

        sections.append("## Diagnostics Snapshot")
        if let snapshot {
            sections.append("Checked At: \(snapshot.checkedAt.formatted(date: .abbreviated, time: .standard))")
            sections.append("Docker Path: \(snapshot.dockerPath)")
            sections.append("Docker Installed: \(snapshot.isDockerInstalled ? "yes" : "no")")
            sections.append("Docker Daemon Running: \(snapshot.isDockerDaemonRunning ? "yes" : "no")")
            if let dockerVersion = snapshot.dockerVersion {
                sections.append("Docker Version: \(dockerVersion)")
            }
            let containers = snapshot.runningContainers.isEmpty
                ? "none"
                : snapshot.runningContainers.joined(separator: ", ")
            sections.append("Running Containers: \(containers)")
            sections.append("Diagnostics Message: \(snapshot.dockerStatusMessage)")
        } else {
            sections.append("No diagnostics snapshot captured.")
        }

        sections.append("## Execution Output")
        let trimmedExecutionOutput = executionOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        sections.append(trimmedExecutionOutput.isEmpty ? "(empty)" : trimmedExecutionOutput)

        sections.append("## App Service Logs")
        if appLogs.isEmpty {
            sections.append("(empty)")
        } else {
            sections.append(contentsOf: appLogs)
        }

        return sections.joined(separator: "\n") + "\n"
    }

    private func defaultExportDirectory() -> URL {
        if let downloads = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first {
            return downloads
        }

        return fileManager.homeDirectoryForCurrentUser
    }

    private func timestampForFilename(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: date)
    }
}
