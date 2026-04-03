import SwiftUI

struct SessionDetailView: View {
    let session: SessionLog

    var body: some View {
        List {
            Section("Summary") {
                detailRow("Started", value: session.startedAt.formatted(date: .abbreviated, time: .standard))
                detailRow("Ended", value: session.endedAt?.formatted(date: .abbreviated, time: .standard) ?? "--")
                detailRow("Samples", value: "\(session.samples.count)")
                detailRow(
                    "Average HR",
                    value: SessionMetrics.averageHeartRate(for: session.samples).map { "\(Int($0.rounded())) bpm" } ?? "--"
                )
                detailRow(
                    "Peak HR",
                    value: SessionMetrics.peakHeartRate(for: session.samples).map { "\(Int($0.rounded())) bpm" } ?? "--"
                )
            }

            Section("Latest Estimation") {
                detailRow("State", value: session.latestEstimation?.state.displayName ?? "Unknown")
                detailRow(
                    "Confidence",
                    value: session.latestEstimation.map { "\(Int($0.confidence * 100))%" } ?? "--"
                )
                detailRow("Rationale", value: session.latestEstimation?.rationale ?? "--")
            }

            if let features = session.latestEstimation?.features {
                Section("Features") {
                    detailRow("Mean HR", value: String(format: "%.1f", features.meanHR))
                    detailRow("Variation", value: String(format: "%.2f", features.shortTermVariation))
                    detailRow("HR Slope/min", value: String(format: "%.2f", features.heartRateSlopePerMinute))
                    detailRow("Motion Mean", value: String(format: "%.3f", features.motionMean))
                    detailRow("Stationary Ratio", value: String(format: "%.2f", features.stationaryRatio))
                    detailRow("Valid Ratio", value: String(format: "%.2f", features.validRatio))
                }
            }
        }
        .navigationTitle("Session")
    }

    private func detailRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}
