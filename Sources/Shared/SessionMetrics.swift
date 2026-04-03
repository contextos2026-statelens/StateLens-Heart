import Foundation

struct SessionMetrics {
    static func averageHeartRate(for samples: [HeartSample]) -> Double? {
        guard !samples.isEmpty else { return nil }
        return samples.map(\.bpm).reduce(0, +) / Double(samples.count)
    }

    static func peakHeartRate(for samples: [HeartSample]) -> Double? {
        samples.map(\.bpm).max()
    }
}
