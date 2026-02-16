import SwiftUI

struct DiagnosticsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var snapshot: DiagnosticsSnapshot?
    @State private var isLoading = false
    @State private var isExporting = false
    @State private var exportMessage: String?

    private let service: DiagnosticsService
    private let logExportService: LogExportService

    init(
        service: DiagnosticsService = DiagnosticsService(),
        logExportService: LogExportService = LogExportService()
    ) {
        self.service = service
        self.logExportService = logExportService
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Environment Diagnostics")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                Button(action: refresh) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(isLoading)

                Button(action: exportLogs) {
                    if isExporting {
                        ProgressView()
                    } else {
                        Label("Export Logs", systemImage: "square.and.arrow.up")
                    }
                }
                .disabled(isLoading || isExporting)
            }

            if let exportMessage {
                Text(exportMessage)
                    .font(.caption)
                    .foregroundStyle(exportMessage.hasPrefix("Failed") ? Color.red : Color.secondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                Toggle("Enable lightweight telemetry", isOn: $appState.telemetryOptIn)

                let summary = appState.executionService.telemetrySummary
                Text("Success Rate: \(formatPercent(summary.successRate))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Average Runtime: \(formatDuration(summary.averageDurationSeconds))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if summary.topErrorCodes.isEmpty {
                    Text("Top Error Codes: none")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(summary.topErrorCodes) { metric in
                        Text("Error: \(metric.code) (\(metric.count))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)

            if let snapshot {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Docker")
                        .font(.headline)

                    DiagnosticsStatusRow(
                        title: "CLI Installation",
                        value: snapshot.isDockerInstalled ? "Installed" : "Missing",
                        isHealthy: snapshot.isDockerInstalled
                    )

                    DiagnosticsStatusRow(
                        title: "Daemon",
                        value: snapshot.isDockerDaemonRunning ? "Running" : "Unavailable",
                        isHealthy: snapshot.isDockerDaemonRunning
                    )

                    DiagnosticsStatusRow(
                        title: "Socket Permission",
                        value: snapshot.isDockerSocketAccessible ? "Granted" : "Unavailable",
                        isHealthy: snapshot.isDockerSocketAccessible
                    )

                    Text("Docker Path: \(snapshot.dockerPath)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let dockerVersion = snapshot.dockerVersion {
                        Text("Docker Version: \(dockerVersion)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(snapshot.dockerStatusMessage)
                        .font(.caption)
                        .foregroundStyle(snapshot.isDockerDaemonRunning ? Color.secondary : Color.red)

                    Text(snapshot.dockerSocketStatusMessage)
                        .font(.caption)
                        .foregroundStyle(snapshot.isDockerSocketAccessible ? Color.secondary : Color.red)
                }
                .padding(12)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Network")
                        .font(.headline)

                    DiagnosticsStatusRow(
                        title: "Reachability",
                        value: snapshot.isNetworkReachable ? "Reachable" : "Unavailable",
                        isHealthy: snapshot.isNetworkReachable
                    )

                    Text(snapshot.networkStatusMessage)
                        .font(.caption)
                        .foregroundStyle(snapshot.isNetworkReachable ? Color.secondary : Color.red)
                }
                .padding(12)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Running Containers")
                        .font(.headline)

                    if snapshot.runningContainers.isEmpty {
                        Text("No running containers detected.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(snapshot.runningContainers, id: \.self) { containerName in
                            Text(containerName)
                                .font(.system(.subheadline, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(nsColor: .textBackgroundColor))
                                .cornerRadius(6)
                        }
                    }
                }

                Text("Last checked: \(snapshot.checkedAt.formatted(date: .abbreviated, time: .standard))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else if isLoading {
                VStack(alignment: .leading, spacing: 8) {
                    ProgressView()
                    Text("Checking local Docker environment...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Run diagnostics to inspect your local Docker environment.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .frame(minWidth: 500, minHeight: 400)
        .onAppear {
            if snapshot == nil {
                refresh()
            }
        }
    }

    private func refresh() {
        guard !isLoading else { return }

        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let latestSnapshot = service.collectSnapshot()

            DispatchQueue.main.async {
                snapshot = latestSnapshot
                isLoading = false
            }
        }
    }

    private func exportLogs() {
        guard !isExporting else { return }

        isExporting = true
        exportMessage = nil

        let currentSnapshot = snapshot
        let executionOutput = appState.executionService.output
        let appLogs = AppLogStore.shared.recentEntries()

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let destination = try logExportService.export(
                    snapshot: currentSnapshot,
                    executionOutput: executionOutput,
                    appLogs: appLogs
                )

                DispatchQueue.main.async {
                    exportMessage = "Exported logs to \(destination.path)"
                    isExporting = false
                }
            } catch {
                DispatchQueue.main.async {
                    exportMessage = "Failed to export logs: \(error.localizedDescription)"
                    isExporting = false
                }
            }
        }
    }

    private func formatPercent(_ value: Double) -> String {
        String(format: "%.1f%%", value * 100)
    }

    private func formatDuration(_ value: TimeInterval) -> String {
        String(format: "%.2fs", value)
    }
}

private struct DiagnosticsStatusRow: View {
    let title: String
    let value: String
    let isHealthy: Bool

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundStyle(isHealthy ? .green : .red)
        }
        .font(.subheadline)
    }
}

#Preview {
    DiagnosticsView(
        service: DiagnosticsService(
            runner: PreviewDiagnosticsCommandRunner(),
            dockerPath: "/opt/homebrew/bin/docker"
        )
    )
    .environmentObject(AppState())
}

private final class PreviewDiagnosticsCommandRunner: CommandRunning {
    func execute(command: String, arguments: [String]) throws -> String {
        if arguments == ["--version"] {
            return "Docker version 27.0.1"
        }
        if arguments == ["info", "--format", "{{.ServerVersion}}"] {
            return "27.0.1"
        }
        if arguments == ["ps", "--format", "{{.Names}}"] {
            return "zero-dev\nzero-lsp-java"
        }
        return ""
    }

    func executeStreaming(command: String, arguments: [String], onOutput: @escaping (String) -> Void) throws -> String {
        let output = try execute(command: command, arguments: arguments)
        onOutput(output)
        return output
    }

    func cancelCurrentCommand() {}
}
