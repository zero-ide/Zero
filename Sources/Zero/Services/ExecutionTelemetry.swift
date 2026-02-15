import Foundation

struct TelemetryErrorMetric: Equatable, Identifiable {
    let code: String
    let count: Int

    var id: String { code }
}

struct ExecutionTelemetrySummary: Equatable {
    let totalRuns: Int
    let successfulRuns: Int
    let failedRuns: Int
    let averageDurationSeconds: TimeInterval
    let topErrorCodes: [TelemetryErrorMetric]

    static let empty = ExecutionTelemetrySummary(
        totalRuns: 0,
        successfulRuns: 0,
        failedRuns: 0,
        averageDurationSeconds: 0,
        topErrorCodes: []
    )

    var successRate: Double {
        guard totalRuns > 0 else { return 0 }
        return Double(successfulRuns) / Double(totalRuns)
    }
}
