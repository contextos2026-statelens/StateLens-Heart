import Foundation

enum DebugSanityChecks {
    static func runIfNeeded() {
#if DEBUG
        testStateEstimator()
        testSlidingWindow()
#endif
    }

    private static func testStateEstimator() {
        let estimator = StateEstimator()
        let calmFeatures = WindowFeatures(
            windowSeconds: 45,
            sampleCount: 12,
            meanHR: 66,
            shortTermVariation: 1.8,
            heartRateSlopePerMinute: -0.3,
            motionMean: 0.01,
            stationaryRatio: 0.92,
            validRatio: 0.95
        )
        let calm = estimator.estimate(from: calmFeatures)
        assert(calm.state == .calm || calm.state == .focused, "Unexpected calm classification")

        let stressedFeatures = WindowFeatures(
            windowSeconds: 45,
            sampleCount: 12,
            meanHR: 98,
            shortTermVariation: 1.9,
            heartRateSlopePerMinute: 0.8,
            motionMean: 0.02,
            stationaryRatio: 0.9,
            validRatio: 0.95
        )
        let stressed = estimator.estimate(from: stressedFeatures)
        assert(stressed.state == .stressedLike || stressed.state == .aroused, "Unexpected stressed classification")
    }

    private static func testSlidingWindow() {
        var window = SlidingHeartWindow(duration: 45)
        let now = Date()
        for index in 0..<5 {
            window.append(
                HeartSample(
                    timestamp: now.addingTimeInterval(Double(index * 8)),
                    bpm: 70 + Double(index),
                    confidence: 0.8,
                    motionScore: 0.02,
                    isStationary: true
                )
            )
        }
        assert(window.features(referenceDate: now.addingTimeInterval(40)) != nil, "Sliding window should produce features")
    }
}
