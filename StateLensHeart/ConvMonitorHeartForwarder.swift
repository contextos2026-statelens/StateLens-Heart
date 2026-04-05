import Foundation
import OSLog

actor ConvMonitorHeartForwarder {
    static let shared = ConvMonitorHeartForwarder()

    private let endpointURL = URL(string: "http://192.168.4.57:5080/api/heart")!
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "StateLensHeart", category: "ConvMonitorForwarder")
    private let encoder = JSONEncoder()
    private let session: URLSession

    private var latestPendingStatus: LiveWatchStatus?
    private var lastSentAt: Date?
    private var isProcessing = false

    private let minSendInterval: TimeInterval = 1.0
    private let maxRetryCount = 5
    private let maxPayloadAge: TimeInterval = 30.0
    private let requestTimeout: TimeInterval = 5.0

    init(session: URLSession = .shared) {
        self.session = session
    }

    func enqueue(_ status: LiveWatchStatus) {
        latestPendingStatus = status
        guard !isProcessing else { return }

        isProcessing = true
        Task {
            await self.processQueue()
        }
    }

    private func processQueue() async {
        defer { isProcessing = false }

        while let status = latestPendingStatus {
            latestPendingStatus = nil

            let age = Date().timeIntervalSince(status.timestamp)
            if age > maxPayloadAge {
                logger.warning("Skip stale payload. message_id=\(status.messageID, privacy: .public) age=\(age, format: .fixed(precision: 2))s")
                continue
            }

            await waitForSendWindow()
            await sendWithRetry(status)
        }
    }

    private func waitForSendWindow() async {
        guard let lastSentAt else { return }
        let elapsed = Date().timeIntervalSince(lastSentAt)
        let waitSeconds = minSendInterval - elapsed
        if waitSeconds > 0 {
            let nanos = UInt64(waitSeconds * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanos)
        }
    }

    private func sendWithRetry(_ status: LiveWatchStatus) async {
        for retryIndex in 0...maxRetryCount {
            if latestPendingStatus != nil {
                logger.debug("Abort retry for older payload. message_id=\(status.messageID, privacy: .public)")
                return
            }

            do {
                let payload = ConvMonitorHeartPayload(from: status)
                var request = URLRequest(url: endpointURL)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.timeoutInterval = requestTimeout
                request.httpBody = try encoder.encode(payload)

                let startedAt = Date()
                let (_, response) = try await session.data(for: request)
                let latencyMS = Date().timeIntervalSince(startedAt) * 1000
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1

                if (200...299).contains(statusCode) {
                    lastSentAt = Date()
                    logger.info("Forward success. message_id=\(status.messageID, privacy: .public) code=\(statusCode) latency_ms=\(latencyMS, format: .fixed(precision: 1))")
                    return
                }

                if (400...499).contains(statusCode) {
                    logger.error("Forward failed (no retry). message_id=\(status.messageID, privacy: .public) code=\(statusCode)")
                    return
                }

                if retryIndex == maxRetryCount {
                    logger.error("Forward failed after retries. message_id=\(status.messageID, privacy: .public) code=\(statusCode)")
                    return
                }

                let delaySeconds = pow(2.0, Double(retryIndex))
                logger.warning("Forward retry scheduled. message_id=\(status.messageID, privacy: .public) attempt=\(retryIndex + 1) next_delay_s=\(delaySeconds, format: .fixed(precision: 1)) reason=server-\(statusCode)")
                try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
            } catch {
                if retryIndex == maxRetryCount {
                    logger.error("Forward failed after retries. message_id=\(status.messageID, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
                    return
                }

                let delaySeconds = pow(2.0, Double(retryIndex))
                logger.warning("Forward retry scheduled. message_id=\(status.messageID, privacy: .public) attempt=\(retryIndex + 1) next_delay_s=\(delaySeconds, format: .fixed(precision: 1)) reason=\(error.localizedDescription, privacy: .public)")
                try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
            }
        }
    }
}

private struct ConvMonitorHeartPayload: Encodable {
    let messageID: String
    let sequence: Int
    let timestamp: String
    let userID: String
    let userName: String
    let sessionRunning: Bool
    let inputMode: String
    let heartRateBPM: Double?
    let state: String
    let stateConfidence: Double?
    let signalConfidence: Double?
    let motionScore: Double
    let sampleCount: Int
    let autonomicScores: ConvMonitorAutonomicScores?
    let emotionEstimate: ConvMonitorEmotionEstimate?
    let latestEvent: ConvMonitorLatestEvent?

    enum CodingKeys: String, CodingKey {
        case messageID = "message_id"
        case sequence
        case timestamp
        case userID = "user_id"
        case userName = "user_name"
        case sessionRunning = "session_running"
        case inputMode = "input_mode"
        case heartRateBPM = "heart_rate_bpm"
        case state
        case stateConfidence = "state_confidence"
        case signalConfidence = "signal_confidence"
        case motionScore = "motion_score"
        case sampleCount = "sample_count"
        case autonomicScores = "autonomic_scores"
        case emotionEstimate = "emotion_estimate"
        case latestEvent = "latest_event"
    }

    init(from status: LiveWatchStatus) {
        messageID = status.messageID
        sequence = status.sequenceNumber
        timestamp = Self.iso8601.string(from: status.timestamp)
        userID = status.userId
        userName = status.userDisplayName
        sessionRunning = status.isSessionRunning
        inputMode = status.inputMode
        heartRateBPM = status.heartRate
        state = status.state.rawValue
        stateConfidence = status.stateConfidence
        signalConfidence = status.signalConfidence
        motionScore = status.motionScore
        sampleCount = status.sampleCount
        autonomicScores = status.autonomicScores.map(ConvMonitorAutonomicScores.init)
        emotionEstimate = status.emotionEstimate.map(ConvMonitorEmotionEstimate.init)
        latestEvent = status.latestEvent.map(ConvMonitorLatestEvent.init)
    }

    static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

private struct ConvMonitorAutonomicScores: Encodable {
    let timestamp: String
    let sympatheticScore: Double
    let parasympatheticScore: Double
    let balanceIndex: Double
    let confidence: Double

    enum CodingKeys: String, CodingKey {
        case timestamp
        case sympatheticScore = "sympathetic_score"
        case parasympatheticScore = "parasympathetic_score"
        case balanceIndex = "balance_index"
        case confidence
    }

    init(_ source: AutonomicScores) {
        timestamp = ConvMonitorHeartPayload.iso8601.string(from: source.timestamp)
        sympatheticScore = source.sympatheticScore
        parasympatheticScore = source.parasympatheticScore
        balanceIndex = source.balanceIndex
        confidence = source.confidence
    }
}

private struct ConvMonitorEmotionEstimate: Encodable {
    let timestamp: String
    let label: String
    let confidence: Double
    let displayText: String

    enum CodingKeys: String, CodingKey {
        case timestamp
        case label
        case confidence
        case displayText = "display_text"
    }

    init(_ source: EmotionEstimate) {
        timestamp = ConvMonitorHeartPayload.iso8601.string(from: source.timestamp)
        label = source.label.rawValue
        confidence = source.confidence
        displayText = source.displayText
    }
}

private struct ConvMonitorLatestEvent: Encodable {
    let id: String
    let timestamp: String
    let type: String
    let severity: String
    let summary: String
    let heartRate: Double?
    let deltaFromPrevious: Double?
    let motionScore: Double?
    let signalConfidence: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case timestamp
        case type
        case severity
        case summary
        case heartRate = "heart_rate"
        case deltaFromPrevious = "delta_from_previous"
        case motionScore = "motion_score"
        case signalConfidence = "signal_confidence"
    }

    init(_ source: AnomalyEvent) {
        id = source.id.uuidString
        timestamp = ConvMonitorHeartPayload.iso8601.string(from: source.timestamp)
        type = source.type.rawValue
        severity = source.severity.rawValue
        summary = source.summary
        heartRate = source.heartRate
        deltaFromPrevious = source.deltaFromPrevious
        motionScore = source.motionScore
        signalConfidence = source.signalConfidence
    }
}
