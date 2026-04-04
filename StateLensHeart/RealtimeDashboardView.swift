import SwiftUI

struct RealtimeDashboardView: View {
    @ObservedObject var store: WatchSessionStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    statusHero
                    signalSection
                    connectivitySection
                    infoSection
                }
                .padding()
            }
            .background(groupedBackground)
            .navigationTitle("リアルタイム")
        }
    }

    private var statusHero: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("現在の感情推定")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.9))

            Text(currentEmotion.japaneseName)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(currentHeartRateText)
                .font(.system(size: 44, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            Text("自律神経状態: \(localizedStateName)")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.95))

            if let liveStatus = store.liveStatus {
                LabeledContent("入力モード", value: liveStatus.inputMode)
                LabeledContent("サンプル数", value: "\(liveStatus.sampleCount)")
                LabeledContent("更新時刻", value: liveStatus.timestamp.formatted(date: .omitted, time: .standard))
            } else {
                Text("Watchから接続されると、ここにライブ状態が表示されます。")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .foregroundStyle(.white)
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(statusCardBackground)
        )
    }

    private var signalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("信号品質")
                .font(.headline)

            metricRow(
                title: "状態推定信頼度",
                value: percentageText(store.liveStatus?.stateConfidence),
                progress: store.liveStatus?.stateConfidence
            )

            metricRow(
                title: "信号信頼度",
                value: percentageText(store.liveStatus?.signalConfidence),
                progress: store.liveStatus?.signalConfidence
            )

            LabeledContent("動きスコア", value: motionText)
            LabeledContent("交感神経スコア", value: percentageText(store.liveStatus?.autonomicScores?.sympatheticScore))
            LabeledContent("副交感神経スコア", value: percentageText(store.liveStatus?.autonomicScores?.parasympatheticScore))
            LabeledContent("感情推定", value: store.liveStatus?.emotionEstimate?.displayText ?? "未取得")
            LabeledContent("最新イベント", value: store.liveStatus?.latestEvent?.summary ?? "なし")
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(cardBackground)
        )
    }

    private var connectivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("接続状態")
                .font(.headline)

            LabeledContent("アクティベーション", value: store.activationStateText)
            LabeledContent("Watchペアリング", value: boolText(store.isWatchPaired))
            LabeledContent("Watchアプリ導入", value: boolText(store.isWatchAppInstalled))
            LabeledContent("現在到達可能", value: boolText(store.isWatchReachable))
            LabeledContent("最終受信", value: lastReceivedText)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(cardBackground)
        )
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("メモ")
                .font(.headline)

            Text("この画面ではWatchからのライブデータを表示します。セッション終了後のログ転送は履歴タブで確認できます。")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let error = store.latestErrorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(cardBackground)
        )
    }

    private func metricRow(title: String, value: String, progress: Double?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            LabeledContent(title, value: value)
            ProgressView(value: min(max(progress ?? 0, 0), 1))
                .tint(stateColor)
        }
    }

    private var currentState: AutonomicState {
        store.liveStatus?.state ?? store.sessions.first?.latestEstimation?.state ?? .unknown
    }

    private var currentEmotion: EmotionLabel {
        store.liveStatus?.emotionEstimate?.label
        ?? store.sessions.first?.timeline.last?.emotionEstimate?.label
        ?? .unknown
    }

    private var currentHeartRateText: String {
        if let heartRate = store.liveStatus?.heartRate {
            return "\(Int(heartRate.rounded())) bpm"
        }

        if let lastSample = store.sessions.first?.samples.last {
            return "\(Int(lastSample.bpm.rounded())) bpm"
        }

        return "ライブ信号なし"
    }

    private var motionText: String {
        guard let motion = store.liveStatus?.motionScore else {
            return store.sessions.first?.samples.last.map { String(format: "%.3f", $0.motionScore) } ?? "未取得"
        }
        return String(format: "%.3f", motion)
    }

    private var lastReceivedText: String {
        guard let lastReceivedAt = store.lastReceivedAt else {
            return "未受信"
        }
        return lastReceivedAt.formatted(date: .abbreviated, time: .standard)
    }

    private func boolText(_ value: Bool) -> String {
        value ? "はい" : "いいえ"
    }

    private func percentageText(_ value: Double?) -> String {
        guard let value else { return "未取得" }
        return "\(Int((value * 100).rounded()))%"
    }

    private var localizedStateName: String {
        switch currentState {
        case .calm:
            return "Calm"
        case .focused:
            return "Focused"
        case .aroused:
            return "Aroused"
        case .stressedLike:
            return "Stressed-like"
        case .unknown:
            return "Unknown"
        }
    }

    private var stateColor: Color {
        switch currentState {
        case .calm:
            return .blue
        case .focused:
            return .green
        case .aroused:
            return .orange
        case .stressedLike:
            return .red
        case .unknown:
            return .secondary
        }
    }

    private var groupedBackground: Color {
#if os(iOS)
        return Color(.systemGroupedBackground)
#else
        return Color.black
#endif
    }

    private var cardBackground: Color {
#if os(iOS)
        return Color(.secondarySystemGroupedBackground)
#else
        return Color.white.opacity(0.08)
#endif
    }

    private var statusCardBackground: Color {
        switch currentEmotion {
        case .calm:
            return Color.blue.opacity(0.92)
        case .focused:
            return Color.cyan.opacity(0.92)
        case .tense:
            return Color.red.opacity(0.92)
        case .energized:
            return Color.orange.opacity(0.92)
        case .fatigued:
            return Color.purple.opacity(0.92)
        case .neutral:
            return Color.green.opacity(0.92)
        case .unknown:
            return Color.gray.opacity(0.92)
        }
    }
}
