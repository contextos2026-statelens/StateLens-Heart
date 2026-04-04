import SwiftUI

struct ContentView: View {
    @StateObject private var manager = WorkoutSessionManager()

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text(manager.currentHeartRate.map { "\(Int($0.rounded())) bpm" } ?? "-- bpm")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .monospacedDigit()

                VStack(spacing: 4) {
                    Text(localizedState(manager.currentEstimation?.state ?? .unknown))
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(stateColor)
                    Text(confidenceText)
                        .font(.caption2)
                        .foregroundStyle(stateColor.opacity(0.9))
                }

                Text("入力: \(manager.inputModeText)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                HStack {
                    metricCard(title: "動き", value: String(format: "%.03f", manager.latestMotionScore))
                    metricCard(title: "サンプル", value: "\(manager.latestSampleCount)")
                }

                HStack {
                    metricCard(title: "交感", value: scoreText(manager.latestAutonomicScores?.sympatheticScore))
                    metricCard(title: "副交感", value: scoreText(manager.latestAutonomicScores?.parasympatheticScore))
                }

                if let emotion = manager.latestEmotionEstimate {
                    Text("感情推定: \(emotion.label.japaneseName)")
                        .font(.caption2)
                        .foregroundStyle(emotionColor(emotion.label))
                }

                if let event = manager.latestAnomalyEvent {
                    Text("イベント: \(event.summary)")
                        .font(.caption2)
                        .foregroundStyle(eventColor(event.severity))
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 6) {
                    Text("基準値: \(baselineText)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text(manager.calibrationStatusText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if manager.isCalibrating {
                        ProgressView(value: manager.calibrationProgress)
                            .tint(.blue)
                        Text("残り \(manager.calibrationRemainingText)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        HStack {
                            Button("3分校正") {
                                manager.startInitialCalibration(durationSeconds: 180)
                            }
                            .buttonStyle(.bordered)

                            Button("5分校正") {
                                manager.startInitialCalibration(durationSeconds: 300)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }

                Button(manager.isRunning ? "Stop" : "Start") {
                    manager.toggleSession()
                }
                .buttonStyle(.borderedProminent)
                .tint(manager.isRunning ? .red : .green)

                VStack(spacing: 6) {
                    Text("ユーザー: \(manager.selectedProfile.displayName)")
                        .font(.caption2)
                    Text("ユーザー設定・切替はiPhoneアプリで行ってください")
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }

                Text("HealthKit: \(manager.authorizationStatusText)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if manager.inputModeText == "Mock" {
                    Text("シミュレータではモック心拍ストリームを使用します。")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

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

    private func scoreText(_ value: Double?) -> String {
        guard let value else { return "--" }
        return "\(Int((value * 100).rounded()))%"
    }

    private func eventColor(_ severity: AnomalySeverity) -> Color {
        switch severity {
        case .info:
            return .yellow
        case .warn:
            return .orange
        case .high:
            return .red
        }
    }

    private func emotionColor(_ label: EmotionLabel) -> Color {
        switch label {
        case .calm:
            return .blue
        case .focused:
            return .cyan
        case .tense:
            return .red
        case .energized:
            return .orange
        case .fatigued:
            return .purple
        case .neutral:
            return .green
        case .unknown:
            return .gray
        }
    }

    private var baselineText: String {
        guard let baseline = manager.currentBaseline else {
            return "未設定"
        }
        let bpm = Int(baseline.restingHeartRate.rounded())
        let confidence = Int((baseline.confidence * 100).rounded())
        return "安静時 \(bpm) bpm / 信頼度 \(confidence)%"
    }

    private func localizedState(_ state: AutonomicState) -> String {
        switch state {
        case .calm:
            return "安定"
        case .focused:
            return "集中寄り"
        case .aroused:
            return "覚醒寄り"
        case .stressedLike:
            return "緊張寄り"
        case .unknown:
            return "判定保留"
        }
    }
}
