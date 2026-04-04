import Foundation
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

final class ConnectivityBridge: NSObject {
    static let shared = ConnectivityBridge()

    private override init() {
        super.init()
#if canImport(WatchConnectivity)
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
#endif
    }

    func transferSessionLog(fileURL: URL) {
#if canImport(WatchConnectivity)
        guard WCSession.isSupported() else { return }
        WCSession.default.transferFile(fileURL, metadata: ["type": "session-log"])
#else
        _ = fileURL
#endif
    }

    func sendLiveStatus(_ status: LiveWatchStatus) {
#if canImport(WatchConnectivity)
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        let payload = makePayload(from: status)

        do {
            try session.updateApplicationContext(payload)
        } catch {
        }

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { _ in
            }
        }
#else
        _ = status
#endif
    }

    private func makePayload(from status: LiveWatchStatus) -> [String: Any] {
        var payload: [String: Any] = [
            ConnectivityEnvelope.kindKey: ConnectivityEnvelope.liveStatusKind,
            "schemaVersion": 2,
            "timestamp": status.timestamp.timeIntervalSince1970,
            "isSessionRunning": status.isSessionRunning,
            "inputMode": status.inputMode,
            "state": status.state.rawValue,
            "motionScore": status.motionScore,
            "sampleCount": status.sampleCount
        ]

        if let heartRate = status.heartRate {
            payload["heartRate"] = heartRate
        }
        if let stateConfidence = status.stateConfidence {
            payload["stateConfidence"] = stateConfidence
        }
        if let signalConfidence = status.signalConfidence {
            payload["signalConfidence"] = signalConfidence
        }
        if let autonomicScores = status.autonomicScores {
            payload["autonomicScores"] = [
                "timestamp": autonomicScores.timestamp.timeIntervalSince1970,
                "sympatheticScore": autonomicScores.sympatheticScore,
                "parasympatheticScore": autonomicScores.parasympatheticScore,
                "balanceIndex": autonomicScores.balanceIndex,
                "confidence": autonomicScores.confidence
            ]
        }
        if let emotionEstimate = status.emotionEstimate {
            payload["emotionEstimate"] = [
                "timestamp": emotionEstimate.timestamp.timeIntervalSince1970,
                "label": emotionEstimate.label.rawValue,
                "confidence": emotionEstimate.confidence,
                "displayText": emotionEstimate.displayText
            ]
        }
        if let latestEvent = status.latestEvent {
            var eventPayload: [String: Any] = [
                "id": latestEvent.id.uuidString,
                "timestamp": latestEvent.timestamp.timeIntervalSince1970,
                "type": latestEvent.type.rawValue,
                "severity": latestEvent.severity.rawValue,
                "summary": latestEvent.summary
            ]
            if let heartRate = latestEvent.heartRate {
                eventPayload["heartRate"] = heartRate
            }
            if let deltaFromPrevious = latestEvent.deltaFromPrevious {
                eventPayload["deltaFromPrevious"] = deltaFromPrevious
            }
            if let motionScore = latestEvent.motionScore {
                eventPayload["motionScore"] = motionScore
            }
            if let signalConfidence = latestEvent.signalConfidence {
                eventPayload["signalConfidence"] = signalConfidence
            }
            payload["latestEvent"] = eventPayload
        }
        return payload
    }
}

#if canImport(WatchConnectivity)
extension ConnectivityBridge: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
    }

#if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
#endif
}
#endif
