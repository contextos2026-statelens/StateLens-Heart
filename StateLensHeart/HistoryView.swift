import SwiftUI

struct HistoryView: View {
    @ObservedObject var store: WatchSessionStore
    @State private var selectedRange: HistoryRange = .all

    var body: some View {
        NavigationStack {
            Group {
                if filteredSessions.isEmpty {
                    ContentUnavailableView(
                        "セッション履歴はまだありません",
                        systemImage: "waveform.path.ecg",
                        description: Text("WatchセッションがiPhoneへ転送されると、ここに保存されます。")
                    )
                } else {
                    List(filteredSessions) { session in
                        NavigationLink {
                            SessionDetailView(session: session)
                        } label: {
                            SessionRowView(session: session)
                        }
                    }
                    .modifier(HistoryListStyle())
                }
            }
            .navigationTitle("履歴")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Picker("期間", selection: $selectedRange) {
                        ForEach(HistoryRange.allCases) { range in
                            Text(range.label).tag(range)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("更新") {
                        store.refreshHistory()
                    }
                }
            }
        }
    }

    private var filteredSessions: [SessionLog] {
        let source = store.sessions
        guard selectedRange != .all else { return source }
        let cutoff = Date().addingTimeInterval(-selectedRange.duration)
        return source.filter { $0.startedAt >= cutoff }
    }
}

private enum HistoryRange: String, CaseIterable, Identifiable {
    case day
    case week
    case all

    var id: String { rawValue }

    var duration: TimeInterval {
        switch self {
        case .day:
            return 60 * 60 * 24
        case .week:
            return 60 * 60 * 24 * 7
        case .all:
            return .infinity
        }
    }

    var label: String {
        switch self {
        case .day:
            return "24時間"
        case .week:
            return "7日"
        case .all:
            return "全期間"
        }
    }
}

private struct HistoryListStyle: ViewModifier {
    func body(content: Content) -> some View {
#if os(iOS)
        content.listStyle(.insetGrouped)
#else
        content
#endif
    }
}

private struct SessionRowView: View {
    let session: SessionLog

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(localizedState(session.latestEstimation?.state ?? .unknown))
                    .font(.headline)
                Spacer()
                Text(durationText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                Label("\(session.samples.count) サンプル", systemImage: "waveform")
                Spacer()
                if let heartRate = meanHeartRate {
                    Label("平均 \(heartRate) bpm", systemImage: "heart.fill")
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)

            HStack {
                Text("感情推定: \(latestEmotionText)")
                Spacer()
                Text("イベント: \(session.events.count)")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var durationText: String {
        let interval = (session.endedAt ?? session.startedAt).timeIntervalSince(session.startedAt)
        if interval <= 0 {
            return "0分"
        }

        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = interval >= 3600 ? [.hour, .minute] : [.minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: interval) ?? "0分"
    }

    private var meanHeartRate: Int? {
        guard !session.samples.isEmpty else { return nil }
        let average = session.samples.map(\.bpm).reduce(0, +) / Double(session.samples.count)
        return Int(average.rounded())
    }

    private var latestEmotionText: String {
        session.timeline.last?.emotionEstimate?.displayText ?? "未取得"
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
