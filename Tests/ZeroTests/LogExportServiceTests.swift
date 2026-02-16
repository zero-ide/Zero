import XCTest
@testable import Zero

final class LogExportServiceTests: XCTestCase {
    func testBuildBundleTextIncludesDiagnosticsExecutionAndAppLogs() {
        // Given
        let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
        let service = LogExportService(now: { fixedDate })
        let snapshot = DiagnosticsSnapshot(
            checkedAt: fixedDate,
            dockerPath: "/opt/homebrew/bin/docker",
            isDockerInstalled: true,
            dockerVersion: "27.0.1",
            isDockerDaemonRunning: true,
            isDockerSocketAccessible: true,
            dockerSocketStatusMessage: "Docker socket access is available",
            isNetworkReachable: true,
            networkStatusMessage: "Network reachable",
            runningContainers: ["zero-dev", "zero-lsp-java"],
            dockerStatusMessage: "Docker is ready"
        )

        // When
        let bundle = service.buildBundleText(
            snapshot: snapshot,
            executionOutput: "swift test\nBuild complete",
            appLogs: [
                "Failed to fetch repos: unauthorized",
                "Docker shell command failed: exit=127"
            ]
        )

        // Then
        XCTAssertTrue(bundle.contains("## Diagnostics Snapshot"))
        XCTAssertTrue(bundle.contains("Docker Path: /opt/homebrew/bin/docker"))
        XCTAssertTrue(bundle.contains("Docker Version: 27.0.1"))
        XCTAssertTrue(bundle.contains("Docker Socket Access: yes"))
        XCTAssertTrue(bundle.contains("Network Reachable: yes"))
        XCTAssertTrue(bundle.contains("Running Containers: zero-dev, zero-lsp-java"))
        XCTAssertTrue(bundle.contains("## Execution Output"))
        XCTAssertTrue(bundle.contains("swift test"))
        XCTAssertTrue(bundle.contains("## App Service Logs"))
        XCTAssertTrue(bundle.contains("Failed to fetch repos: unauthorized"))
    }

    func testExportWritesBundleToProvidedDirectoryWithDeterministicFilename() throws {
        // Given
        let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
        let service = LogExportService(now: { fixedDate })
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("zero-log-export-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        // When
        let exportURL = try service.export(
            snapshot: nil,
            executionOutput: "npm test",
            appLogs: ["sample log entry"],
            to: directory
        )
        let exportedText = try String(contentsOf: exportURL, encoding: .utf8)

        // Then
        XCTAssertEqual(
            exportURL.deletingLastPathComponent().standardizedFileURL.path,
            directory.standardizedFileURL.path
        )
        XCTAssertEqual(exportURL.lastPathComponent, "zero-logs-20231114-221320.txt")
        XCTAssertTrue(exportedText.contains("## Diagnostics Snapshot"))
        XCTAssertTrue(exportedText.contains("No diagnostics snapshot captured."))
        XCTAssertTrue(exportedText.contains("npm test"))
        XCTAssertTrue(exportedText.contains("sample log entry"))
    }
}
