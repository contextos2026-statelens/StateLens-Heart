import Foundation

enum AutonomicState: String, Codable, CaseIterable, Identifiable {
    case calm
    case focused
    case aroused
    case stressedLike = "stressed_like"
    case unknown

    var id: String { rawValue }

    var displayName: String {
        switch self {
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
}

enum EmotionLabel: String, Codable, CaseIterable, Identifiable {
    case calm
    case focused
    case tense
    case energized
    case fatigued
    case neutral
    case unknown

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .calm:
            return "Calm"
        case .focused:
            return "Focused"
        case .tense:
            return "Tense"
        case .energized:
            return "Energized"
        case .fatigued:
            return "Fatigued"
        case .neutral:
            return "Neutral"
        case .unknown:
            return "Unknown"
        }
    }

    var japaneseName: String {
        switch self {
        case .calm:
            return "落ち着き"
        case .focused:
            return "集中"
        case .tense:
            return "緊張"
        case .energized:
            return "活性"
        case .fatigued:
            return "疲労傾向"
        case .neutral:
            return "中立"
        case .unknown:
            return "判定保留"
        }
    }
}

enum AnomalyEventType: String, Codable, CaseIterable, Identifiable {
    case suddenRise = "sudden_rise"
    case suddenDrop = "sudden_drop"
    case irregularPattern = "irregular_pattern"
    case lowSignal = "low_signal"

    var id: String { rawValue }
}

enum AnomalySeverity: String, Codable, CaseIterable, Identifiable {
    case info
    case warn
    case high

    var id: String { rawValue }
}

struct AutonomicScores: Codable, Hashable {
    let timestamp: Date
    let sympatheticScore: Double
    let parasympatheticScore: Double
    let balanceIndex: Double
    let confidence: Double
}

struct EmotionEstimate: Codable, Hashable {
    let timestamp: Date
    let label: EmotionLabel
    let confidence: Double
    let displayText: String
}

struct AnomalyEvent: Codable, Identifiable, Hashable {
    let id: UUID
    let timestamp: Date
    let type: AnomalyEventType
    let severity: AnomalySeverity
    let summary: String
    let heartRate: Double?
    let deltaFromPrevious: Double?
    let motionScore: Double?
    let signalConfidence: Double?

    init(
        id: UUID = UUID(),
        timestamp: Date,
        type: AnomalyEventType,
        severity: AnomalySeverity,
        summary: String,
        heartRate: Double? = nil,
        deltaFromPrevious: Double? = nil,
        motionScore: Double? = nil,
        signalConfidence: Double? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.severity = severity
        self.summary = summary
        self.heartRate = heartRate
        self.deltaFromPrevious = deltaFromPrevious
        self.motionScore = motionScore
        self.signalConfidence = signalConfidence
    }
}

struct TimelinePoint: Codable, Identifiable, Hashable {
    let id: UUID
    let timestamp: Date
    let bpm: Double
    let signalConfidence: Double
    let motionScore: Double
    let state: AutonomicState
    let stateConfidence: Double?
    let autonomicScores: AutonomicScores?
    let emotionEstimate: EmotionEstimate?

    init(
        id: UUID = UUID(),
        timestamp: Date,
        bpm: Double,
        signalConfidence: Double,
        motionScore: Double,
        state: AutonomicState,
        stateConfidence: Double?,
        autonomicScores: AutonomicScores?,
        emotionEstimate: EmotionEstimate?
    ) {
        self.id = id
        self.timestamp = timestamp
        self.bpm = bpm
        self.signalConfidence = signalConfidence
        self.motionScore = motionScore
        self.state = state
        self.stateConfidence = stateConfidence
        self.autonomicScores = autonomicScores
        self.emotionEstimate = emotionEstimate
    }
}

struct UserBaseline: Codable, Hashable {
    let restingHeartRate: Double
    let lowerBoundHeartRate: Double
    let upperBoundHeartRate: Double
    let confidence: Double
    let sampleCount: Int
    let calibrationDurationSeconds: TimeInterval
    let updatedAt: Date
}

struct UserProfile: Codable, Identifiable, Hashable {
    let id: String
    var displayName: String
    let createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        displayName: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.displayName = displayName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct HeartSample: Codable, Identifiable, Hashable {
    let id: UUID
    let timestamp: Date
    let bpm: Double
    let confidence: Double
    let motionScore: Double
    let isStationary: Bool

    init(
        id: UUID = UUID(),
        timestamp: Date,
        bpm: Double,
        confidence: Double,
        motionScore: Double,
        isStationary: Bool
    ) {
        self.id = id
        self.timestamp = timestamp
        self.bpm = bpm
        self.confidence = confidence
        self.motionScore = motionScore
        self.isStationary = isStationary
    }
}

struct WindowFeatures: Codable, Hashable {
    let windowSeconds: TimeInterval
    let sampleCount: Int
    let meanHR: Double
    let shortTermVariation: Double
    let heartRateSlopePerMinute: Double
    let motionMean: Double
    let stationaryRatio: Double
    let validRatio: Double
}

struct StateEstimation: Codable, Hashable {
    let state: AutonomicState
    let confidence: Double
    let features: WindowFeatures
    let rationale: String
    let timestamp: Date
}

struct SessionLog: Codable, Identifiable, Hashable {
    let id: UUID
    var userId: String
    var userDisplayName: String
    let startedAt: Date
    var endedAt: Date?
    var samples: [HeartSample]
    var latestEstimation: StateEstimation?
    var timeline: [TimelinePoint]
    var events: [AnomalyEvent]
    var schemaVersion: Int

    init(
        id: UUID = UUID(),
        userId: String = "default-user",
        userDisplayName: String = "デフォルト",
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        samples: [HeartSample] = [],
        latestEstimation: StateEstimation? = nil,
        timeline: [TimelinePoint] = [],
        events: [AnomalyEvent] = [],
        schemaVersion: Int = 3
    ) {
        self.id = id
        self.userId = userId
        self.userDisplayName = userDisplayName
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.samples = samples
        self.latestEstimation = latestEstimation
        self.timeline = timeline
        self.events = events
        self.schemaVersion = schemaVersion
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case userDisplayName
        case startedAt
        case endedAt
        case samples
        case latestEstimation
        case timeline
        case events
        case schemaVersion
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        userId = try container.decodeIfPresent(String.self, forKey: .userId) ?? "default-user"
        userDisplayName = try container.decodeIfPresent(String.self, forKey: .userDisplayName) ?? "デフォルト"
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        endedAt = try container.decodeIfPresent(Date.self, forKey: .endedAt)
        samples = try container.decodeIfPresent([HeartSample].self, forKey: .samples) ?? []
        latestEstimation = try container.decodeIfPresent(StateEstimation.self, forKey: .latestEstimation)
        timeline = try container.decodeIfPresent([TimelinePoint].self, forKey: .timeline) ?? []
        events = try container.decodeIfPresent([AnomalyEvent].self, forKey: .events) ?? []
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
    }
}
