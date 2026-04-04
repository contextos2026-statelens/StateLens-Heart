import SwiftUI

struct SessionDetailView: View {
    let session: SessionLog
    @State private var timelineRange: TimelineRange = .all

    var body: some View {
        List {
            summarySection
            metricsSection
            timelineSection
            eventsSection
        }
        .navigationTitle("セッション詳細")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var summarySection: some View {
        Section("サマリー") {
            LabeledContent("ユーザー", value: session.userDisplayName)
            LabeledContent("開始", value: session.startedAt.formatted(date: .abbreviated, time: .standard))
            LabeledContent("終了", value: endText)
            LabeledContent("継続時間", value: durationText)
            LabeledContent("最終状態", value: localizedStateName(session.latestEstimation?.state ?? .unknown))
            LabeledContent("推定根拠", value: session.latestEstimation?.rationale ?? "未取得")
        }
    }

    private var metricsSection: some View {
        Section("指標") {
            LabeledContent("サンプル数", value: "\(session.samples.count)")
            LabeledContent("平均心拍", value: averageHeartRateText)
            LabeledContent("最大心拍", value: peakHeartRateText)
            LabeledContent("最新信号信頼度", value: latestSignalConfidenceText)

            if let estimation = session.latestEstimation {
                LabeledContent("状態推定信頼度", value: percentage(estimation.confidence))
                LabeledContent("ウィンドウ長", value: "\(Int(estimation.features.windowSeconds)) 秒")
                LabeledContent("平均動き", value: String(format: "%.3f", estimation.features.motionMean))
                LabeledContent("静止割合", value: percentage(estimation.features.stationaryRatio))
            }

            LabeledContent("時系列ポイント数", value: "\(session.timeline.count)")
            LabeledContent("検知イベント数", value: "\(session.events.count)")
        }
    }

    private var timelineSection: some View {
        Section("時系列") {
            Picker("表示範囲", selection: $timelineRange) {
                ForEach(TimelineRange.allCases) { range in
                    Text(range.label).tag(range)
                }
            }

            if filteredTimeline.isEmpty {
                Text("時系列データはありません。")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(filteredTimeline.reversed()) { point in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("\(Int(point.bpm.rounded())) bpm")
                                .font(.headline)
                            Spacer()
                            Text(point.timestamp.formatted(date: .omitted, time: .standard))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Text("信号 \(percentage(point.signalConfidence))")
                            Spacer()
                            Text("動き \(String(format: "%.3f", point.motionScore))")
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                        HStack {
                            Text("状態 \(localizedStateName(point.state))")
                            Spacer()
                            Text(point.emotionEstimate?.displayText ?? "感情推定なし")
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                        if let autonomic = point.autonomicScores {
                            HStack {
                                Text("交感 \(percentage(autonomic.sympatheticScore))")
                                Spacer()
                                Text("副交感 \(percentage(autonomic.parasympatheticScore))")
                            }
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var eventsSection: some View {
        Section("イベント") {
            if session.events.isEmpty {
                Text("異常イベントは検知されていません。")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(session.events.reversed()) { event in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(event.summary)
                                .font(.subheadline)
                            Spacer()
                            Text(event.timestamp.formatted(date: .omitted, time: .standard))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Text("種別: \(localizedEventType(event.type))")
                            Spacer()
                            Text("重要度: \(localizedSeverity(event.severity))")
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var endText: String {
        guard let endedAt = session.endedAt else { return "進行中" }
        return endedAt.formatted(date: .abbreviated, time: .standard)
    }

    private var durationText: String {
        guard let endedAt = session.endedAt else { return "進行中" }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = endedAt.timeIntervalSince(session.startedAt) >= 3600 ? [.hour, .minute] : [.minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: endedAt.timeIntervalSince(session.startedAt)) ?? "未取得"
    }

    private var averageHeartRateText: String {
        guard !session.samples.isEmpty else { return "未取得" }
        let average = session.samples.map(\.bpm).reduce(0, +) / Double(session.samples.count)
        return "\(Int(average.rounded())) bpm"
    }

    private var peakHeartRateText: String {
        guard let peak = session.samples.map(\.bpm).max() else { return "未取得" }
        return "\(Int(peak.rounded())) bpm"
    }

    private var latestSignalConfidenceText: String {
        guard let confidence = session.samples.last?.confidence else { return "未取得" }
        return percentage(confidence)
    }

    private func percentage(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private func localizedEventType(_ type: AnomalyEventType) -> String {
        switch type {
        case .suddenRise:
            return "急上昇"
        case .suddenDrop:
            return "急低下"
        case .irregularPattern:
            return "不規則パターン"
        case .lowSignal:
            return "低信号"
        }
    }

    private func localizedSeverity(_ severity: AnomalySeverity) -> String {
        switch severity {
        case .info:
            return "情報"
        case .warn:
            return "注意"
        case .high:
            return "高"
        }
    }

    private func localizedStateName(_ state: AutonomicState) -> String {
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

    private var filteredTimeline: [TimelinePoint] {
        guard timelineRange != .all else { return Array(session.timeline.suffix(240)) }
        let cutoff = Date().addingTimeInterval(-timelineRange.duration)
        return session.timeline
            .filter { $0.timestamp >= cutoff }
            .suffix(240)
            .map { $0 }
    }
}

private enum TimelineRange: String, CaseIterable, Identifiable {
    case tenMinutes
    case oneHour
    case all

    var id: String { rawValue }

    var duration: TimeInterval {
        switch self {
        case .tenMinutes:
            return 10 * 60
        case .oneHour:
            return 60 * 60
        case .all:
            return .infinity
        }
    }

    var label: String {
        switch self {
        case .tenMinutes:
            return "10分"
        case .oneHour:
            return "1時間"
        case .all:
            return "全体"
        }
    }
}
