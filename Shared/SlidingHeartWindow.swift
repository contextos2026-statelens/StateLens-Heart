import Foundation

struct SlidingHeartWindow {
    let duration: TimeInterval
    private(set) var samples: [HeartSample] = []

    init(duration: TimeInterval = 45) {
        self.duration = duration
    }

    mutating func append(_ sample: HeartSample) {
        samples.append(sample)
        trim(referenceDate: sample.timestamp)
    }

    mutating func reset() {
        samples.removeAll()
    }

    private mutating func trim(referenceDate: Date) {
        let cutoff = referenceDate.addingTimeInterval(-duration)
        samples.removeAll { $0.timestamp < cutoff }
    }

    func features(referenceDate: Date = Date()) -> WindowFeatures? {
        let cutoff = referenceDate.addingTimeInterval(-duration)
        let windowed = samples.filter { $0.timestamp >= cutoff }
        guard windowed.count >= 3 else { return nil }

        let hrValues = windowed.map(\.bpm)
        let meanHR = hrValues.reduce(0, +) / Double(hrValues.count)
        let variance = hrValues.map { pow($0 - meanHR, 2) }.reduce(0, +) / Double(hrValues.count)
        let shortTermVariation = sqrt(variance)

        let motionMean = windowed.map(\.motionScore).reduce(0, +) / Double(windowed.count)
        let stationaryRatio = Double(windowed.filter(\.isStationary).count) / Double(windowed.count)
        let validRatio = Double(windowed.filter { $0.confidence >= 0.6 }.count) / Double(windowed.count)

        return WindowFeatures(
            windowSeconds: duration,
            sampleCount: windowed.count,
            meanHR: meanHR,
            shortTermVariation: shortTermVariation,
            heartRateSlopePerMinute: linearRegressionSlopePerMinute(samples: windowed),
            motionMean: motionMean,
            stationaryRatio: stationaryRatio,
            validRatio: validRatio
        )
    }

    private func linearRegressionSlopePerMinute(samples: [HeartSample]) -> Double {
        guard let first = samples.first else { return 0 }

        let xs = samples.map { $0.timestamp.timeIntervalSince(first.timestamp) / 60.0 }
        let ys = samples.map(\.bpm)

        let meanX = xs.reduce(0, +) / Double(xs.count)
        let meanY = ys.reduce(0, +) / Double(ys.count)
        let numerator = zip(xs, ys).map { ($0 - meanX) * ($1 - meanY) }.reduce(0, +)
        let denominator = xs.map { pow($0 - meanX, 2) }.reduce(0, +)

        guard denominator > 0 else { return 0 }
        return numerator / denominator
    }
}
