import Foundation

struct StateEstimator {
    func estimate(from features: WindowFeatures, now: Date = Date()) -> StateEstimation {
        let confidence = confidenceScore(features: features)

        guard confidence >= 0.55 else {
            return StateEstimation(
                state: .unknown,
                confidence: confidence,
                features: features,
                rationale: "low confidence",
                timestamp: now
            )
        }

        if features.meanHR >= 98, features.motionMean <= 0.05, features.shortTermVariation <= 2.5 {
            return StateEstimation(
                state: .stressedLike,
                confidence: confidence,
                features: features,
                rationale: "high HR with low motion and low short-term variation",
                timestamp: now
            )
        }

        if features.meanHR >= 95 || (features.heartRateSlopePerMinute >= 12 && features.motionMean >= 0.08) {
            return StateEstimation(
                state: .aroused,
                confidence: confidence,
                features: features,
                rationale: "elevated or rising HR with movement",
                timestamp: now
            )
        }

        if features.meanHR <= 78, features.motionMean <= 0.04, features.stationaryRatio >= 0.75 {
            return StateEstimation(
                state: .calm,
                confidence: confidence,
                features: features,
                rationale: "lower HR with stable and stationary signal",
                timestamp: now
            )
        }

        if features.meanHR < 92, features.motionMean <= 0.06, features.shortTermVariation < 5.5 {
            return StateEstimation(
                state: .focused,
                confidence: confidence,
                features: features,
                rationale: "moderate HR with low movement and relatively stable signal",
                timestamp: now
            )
        }

        return StateEstimation(
            state: .unknown,
            confidence: min(confidence, 0.7),
            features: features,
            rationale: "pattern did not match a stable class",
            timestamp: now
        )
    }

    func confidenceScore(features: WindowFeatures) -> Double {
        var score = 0.18
        score += min(0.22, features.validRatio * 0.22)
        score += min(0.25, Double(features.sampleCount) / 12.0 * 0.25)
        score += max(0, min(0.10, features.stationaryRatio * 0.10))

        if features.motionMean < 0.08 {
            score += 0.08
        } else {
            score -= min(0.15, (features.motionMean - 0.08) * 0.8)
        }

        if features.shortTermVariation > 18 {
            score -= 0.1
        }

        return min(max(score, 0), 1)
    }
}
