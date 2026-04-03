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
    let startedAt: Date
    var endedAt: Date?
    var samples: [HeartSample]
    var latestEstimation: StateEstimation?
    var notes: String?

    init(
        id: UUID = UUID(),
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        samples: [HeartSample] = [],
        latestEstimation: StateEstimation? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.samples = samples
        self.latestEstimation = latestEstimation
        self.notes = notes
    }
}
