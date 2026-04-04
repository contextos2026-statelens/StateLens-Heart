import SwiftUI

struct HistoryView: View {
    @ObservedObject var store: WatchSessionStore

    var body: some View {
        NavigationStack {
            Group {
                if store.sessions.isEmpty {
                    ContentUnavailableView(
                        "セッション履歴はまだありません",
                        systemImage: "waveform.path.ecg",
                        description: Text("WatchセッションがiPhoneへ転送されると、ここに保存されます。")
                    )
                } else {
                    List(store.sessions) { session in
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button("更新") {
                        store.refreshHistory()
                    }
                }
            }
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
                Text(session.latestEstimation?.state.displayName ?? "Unknown")
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
}
