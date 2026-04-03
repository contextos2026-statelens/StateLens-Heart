import Foundation
import WatchConnectivity

final class ConnectivityBridge: NSObject, WCSessionDelegate {
    static let shared = ConnectivityBridge()

    private override init() {
        super.init()

        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func transferSessionLog(fileURL: URL) {
        guard WCSession.isSupported() else { return }
        WCSession.default.transferFile(fileURL, metadata: ["type": "session-log"])
    }

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
    }

#if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {
    }

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
#endif
}
