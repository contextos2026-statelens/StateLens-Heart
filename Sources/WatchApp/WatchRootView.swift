import SwiftUI

struct WatchRootView: View {
    @StateObject private var manager = WorkoutSessionManager()

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text(manager.currentHeartRate.map { "\(Int($0.rounded())) bpm" } ?? "-- bpm")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .monospacedDigit()

                VStack(spacing: 4) {
                    Text(manager.currentEstimation?.state.displayName ?? "Unknown")
                        .font(.headline)
                        .foregroundStyle(stateColor)
                    Text(confidenceText)
                        .font(.caption2)
                        .foregroundStyle(stateColor.opacity(0.9))
                }

                Text("Input: \(manager.inputModeText)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                HStack {
                    metricCard(title: "Motion", value: String(format: "%.03f", manager.latestMotionScore))
                    metricCard(
                        title: "Samples",
                        value: "\(manager.latestSampleCount)"
                    )
                }

                Button(manager.isRunning ? "Stop" : "Start") {
                    manager.toggleSession()
                }
                .buttonStyle(.borderedProminent)
                .tint(manager.isRunning ? .red : .green)

                Text("Health: \(manager.authorizationStatusText)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

#if targetEnvironment(simulator)
                Text("Simulator uses a scripted heart-rate stream for UI and logic testing.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
#endif

                if let error = manager.latestErrorMessage {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }
            .padding()
        }
        .task {
            await manager.requestAuthorizationIfNeeded()
        }
    }

    private var confidenceText: String {
        if let estimation = manager.currentEstimation {
            let percent = Int((estimation.confidence * 100).rounded())
            let suffix = manager.latestSampleCount < 8 ? " warming up" : ""
            return "state conf. \(percent)%\(suffix)"
        }

        if let signalConfidence = manager.latestSignalConfidence {
            return String(format: "signal conf. %.0f%%", signalConfidence * 100)
        }

        return "state conf. --"
    }

    private var stateColor: Color {
        switch manager.currentEstimation?.state ?? .unknown {
        case .calm:
            return .blue
        case .focused:
            return .cyan
        case .aroused:
            return .orange
        case .stressedLike:
            return .red
        case .unknown:
            return .gray
        }
    }

    private func metricCard(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.footnote.monospacedDigit())
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
