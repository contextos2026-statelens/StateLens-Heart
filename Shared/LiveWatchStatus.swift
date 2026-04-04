import Foundation

struct LiveWatchStatus: Codable, Hashable {
    let messageID: String
    let sequenceNumber: Int
    let timestamp: Date
    let userId: String
    let userDisplayName: String
    let isSessionRunning: Bool
    let inputMode: String
    let heartRate: Double?
    let state: AutonomicState
    let stateConfidence: Double?
    let signalConfidence: Double?
    let motionScore: Double
    let sampleCount: Int
    let autonomicScores: AutonomicScores?
    let emotionEstimate: EmotionEstimate?
    let latestEvent: AnomalyEvent?

    init(
        messageID: String = UUID().uuidString,
        sequenceNumber: Int = 0,
        timestamp: Date,
        userId: String,
        userDisplayName: String,
        isSessionRunning: Bool,
        inputMode: String,
        heartRate: Double?,
        state: AutonomicState,
        stateConfidence: Double?,
        signalConfidence: Double?,
        motionScore: Double,
        sampleCount: Int,
        autonomicScores: AutonomicScores?,
        emotionEstimate: EmotionEstimate?,
        latestEvent: AnomalyEvent?
    ) {
        self.messageID = messageID
        self.sequenceNumber = sequenceNumber
        self.timestamp = timestamp
        self.userId = userId
        self.userDisplayName = userDisplayName
        self.isSessionRunning = isSessionRunning
        self.inputMode = inputMode
        self.heartRate = heartRate
        self.state = state
        self.stateConfidence = stateConfidence
        self.signalConfidence = signalConfidence
        self.motionScore = motionScore
        self.sampleCount = sampleCount
        self.autonomicScores = autonomicScores
        self.emotionEstimate = emotionEstimate
        self.latestEvent = latestEvent
    }

    enum CodingKeys: String, CodingKey {
        case messageID
        case sequenceNumber
        case timestamp
        case userId
        case userDisplayName
        case isSessionRunning
        case inputMode
        case heartRate
        case state
        case stateConfidence
        case signalConfidence
        case motionScore
        case sampleCount
        case autonomicScores
        case emotionEstimate
        case latestEvent
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        messageID = try container.decodeIfPresent(String.self, forKey: .messageID) ?? UUID().uuidString
        sequenceNumber = try container.decodeIfPresent(Int.self, forKey: .sequenceNumber) ?? 0
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        userId = try container.decodeIfPresent(String.self, forKey: .userId) ?? "default-user"
        userDisplayName = try container.decodeIfPresent(String.self, forKey: .userDisplayName) ?? "デフォルト"
        isSessionRunning = try container.decodeIfPresent(Bool.self, forKey: .isSessionRunning) ?? true
        inputMode = try container.decodeIfPresent(String.self, forKey: .inputMode) ?? "Unknown"
        heartRate = try container.decodeIfPresent(Double.self, forKey: .heartRate)
        state = try container.decodeIfPresent(AutonomicState.self, forKey: .state) ?? .unknown
        stateConfidence = try container.decodeIfPresent(Double.self, forKey: .stateConfidence)
        signalConfidence = try container.decodeIfPresent(Double.self, forKey: .signalConfidence)
        motionScore = try container.decodeIfPresent(Double.self, forKey: .motionScore) ?? 0
        sampleCount = try container.decodeIfPresent(Int.self, forKey: .sampleCount) ?? 0
        autonomicScores = try container.decodeIfPresent(AutonomicScores.self, forKey: .autonomicScores)
        emotionEstimate = try container.decodeIfPresent(EmotionEstimate.self, forKey: .emotionEstimate)
        latestEvent = try container.decodeIfPresent(AnomalyEvent.self, forKey: .latestEvent)
    }
}

enum ConnectivityEnvelope {
    static let kindKey = "kind"
    static let liveStatusKind = "live-status"
    static let sessionLogKind = "session-log"
    static let profileSyncKind = "profile-sync"
}
