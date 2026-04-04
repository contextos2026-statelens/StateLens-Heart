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

    func autonomicScores(from features: WindowFeatures, now: Date = Date()) -> AutonomicScores {
        let hrNorm = normalized((features.meanHR - 60) / 50)
        let slopeNorm = normalized((features.heartRateSlopePerMinute + 20) / 40)
        let variationNorm = normalized(features.shortTermVariation / 15)
        let motionNorm = normalized(features.motionMean / 0.15)
        let stillnessNorm = normalized(features.stationaryRatio)

        var sympathetic = 0.40 * hrNorm
        sympathetic += 0.25 * slopeNorm
        sympathetic += 0.20 * motionNorm
        sympathetic += 0.15 * variationNorm

        var parasympathetic = 0.45 * (1 - hrNorm)
        parasympathetic += 0.25 * stillnessNorm
        parasympathetic += 0.20 * (1 - motionNorm)
        parasympathetic += 0.10 * (1 - slopeNorm)

        let sym = normalized(sympathetic)
        let para = normalized(parasympathetic)
        let total = max(sym + para, 0.0001)
        let normalizedSym = sym / total
        let normalizedPara = para / total
        let balance = normalizedSym - normalizedPara
        let confidence = confidenceScore(features: features)

        return AutonomicScores(
            timestamp: now,
            sympatheticScore: normalizedSym,
            parasympatheticScore: normalizedPara,
            balanceIndex: max(min(balance, 1), -1),
            confidence: confidence
        )
    }

    func emotionEstimate(
        from state: AutonomicState,
        autonomic: AutonomicScores,
        features: WindowFeatures,
        now: Date = Date()
    ) -> EmotionEstimate {
        let confidence = min(autonomic.confidence, 0.95)
        let label: EmotionLabel

        if confidence < 0.5 {
            label = .unknown
        } else if autonomic.sympatheticScore >= 0.72, features.motionMean <= 0.05 {
            label = .tense
        } else if autonomic.parasympatheticScore >= 0.68, features.meanHR <= 78 {
            label = .calm
        } else if state == .focused {
            label = .focused
        } else if autonomic.sympatheticScore >= 0.58, features.motionMean >= 0.08 {
            label = .energized
        } else if features.meanHR < 74, features.shortTermVariation > 6.5 {
            label = .fatigued
        } else {
            label = .neutral
        }

        return EmotionEstimate(
            timestamp: now,
            label: label,
            confidence: confidence,
            displayText: "\(label.japaneseName)（推定）"
        )
    }

    private func confidenceScore(features: WindowFeatures) -> Double {
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

    private func normalized(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}
