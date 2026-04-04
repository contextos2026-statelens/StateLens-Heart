import Foundation
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

final class ConnectivityBridge: NSObject {
    static let shared = ConnectivityBridge()
    private var sequenceNumber = 0
    private var lastQueuedAt: Date?
    var onProfileSync: ((String, String) -> Void)?

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
        WCSession.default.transferFile(
            fileURL,
            metadata: [
                "type": "session-log",
                "messageID": UUID().uuidString
            ]
        )
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
                self.queueForRetry(payload, session: session)
            }
        } else {
            queueForRetry(payload, session: session)
        }
#else
        _ = status
#endif
    }

    private func makePayload(from status: LiveWatchStatus) -> [String: Any] {
        sequenceNumber += 1
        var payload: [String: Any] = [
            ConnectivityEnvelope.kindKey: ConnectivityEnvelope.liveStatusKind,
            "schemaVersion": 3,
            "messageID": status.messageID,
            "sequenceNumber": status.sequenceNumber == 0 ? sequenceNumber : status.sequenceNumber,
            "timestamp": status.timestamp.timeIntervalSince1970,
            "userId": status.userId,
            "userDisplayName": status.userDisplayName,
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

    private func queueForRetry(_ payload: [String: Any], session: WCSession) {
        let now = Date()
        let queueInterval: TimeInterval = 5
        if let lastQueuedAt, now.timeIntervalSince(lastQueuedAt) < queueInterval {
            return
        }
        session.transferUserInfo(payload)
        lastQueuedAt = now
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

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        handleProfileSyncPayload(applicationContext)
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleProfileSyncPayload(message)
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        handleProfileSyncPayload(userInfo)
    }

    private nonisolated func handleProfileSyncPayload(_ payload: [String: Any]) {
        guard let kind = payload[ConnectivityEnvelope.kindKey] as? String,
              kind == ConnectivityEnvelope.profileSyncKind,
              let userId = payload["userId"] as? String,
              let userDisplayName = payload["userDisplayName"] as? String
        else {
            return
        }
        Task { @MainActor in
            self.onProfileSync?(userId, userDisplayName)
        }
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
