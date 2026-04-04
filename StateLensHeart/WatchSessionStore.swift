import Combine
import Foundation
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

@MainActor
final class WatchSessionStore: NSObject, ObservableObject {
    @Published private(set) var sessions: [SessionLog] = []
    @Published private(set) var allSessions: [SessionLog] = []
    @Published private(set) var profiles: [UserProfile] = []
    @Published private(set) var selectedUserID: String = "default-user"
    @Published private(set) var liveStatus: LiveWatchStatus?
    @Published private(set) var activationStateText = "Preparing connectivity"
    @Published private(set) var isWatchPaired = false
    @Published private(set) var isWatchAppInstalled = false
    @Published private(set) var isWatchReachable = false
    @Published private(set) var lastReceivedAt: Date?
    @Published private(set) var latestErrorMessage: String?

    private let fileManager = FileManager.default
    private let profileStore = UserProfileStore()
    private var receivedLiveMessageIDs: [String] = []
    private var latestSequenceByUserID: [String: Int] = [:]
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    override init() {
        super.init()
        let snapshot = profileStore.load()
        profiles = snapshot.profiles
        selectedUserID = snapshot.selectedUserID
        loadSavedSessions()
        activateConnectivityIfSupported()
    }

    func refreshHistory() {
        loadSavedSessions()
    }

    func selectUser(_ userID: String) {
        guard profiles.contains(where: { $0.id == userID }) else { return }
        selectedUserID = userID
        persistProfiles()
        applyUserFilter()
        syncSelectedUserToWatch()
    }

    func createUser(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let profile = UserProfile(displayName: trimmed)
        profiles.append(profile)
        selectedUserID = profile.id
        persistProfiles()
        applyUserFilter()
        syncSelectedUserToWatch()
    }

    private func activateConnectivityIfSupported() {
#if canImport(WatchConnectivity)
        guard WCSession.isSupported() else {
            activationStateText = "WatchConnectivity unavailable"
            return
        }

        let session = WCSession.default
        session.delegate = self
        session.activate()
        syncConnectivityState(from: session)
#else
        activationStateText = "WatchConnectivity unavailable"
#endif
    }

    private func syncConnectivityState(from session: WCSession) {
#if os(iOS)
        isWatchPaired = session.isPaired
        isWatchAppInstalled = session.isWatchAppInstalled
#else
        isWatchPaired = true
        isWatchAppInstalled = true
#endif
        isWatchReachable = session.isReachable
    }

    private func loadSavedSessions() {
        do {
            let directoryURL = try sessionsDirectoryURL()
            let urls = try fileManager.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )

            allSessions = try urls
                .filter { $0.pathExtension == "json" }
                .map(loadSessionLog(from:))
                .sorted { lhs, rhs in
                    lhs.startedAt > rhs.startedAt
                }
            allSessions.forEach { ensureProfile(id: $0.userId, name: $0.userDisplayName) }
            applyUserFilter()
            latestErrorMessage = nil
        } catch {
            latestErrorMessage = error.localizedDescription
        }
    }

    private func loadSessionLog(from url: URL) throws -> SessionLog {
        let data = try Data(contentsOf: url)
        return try decoder.decode(SessionLog.self, from: data)
    }

    private func save(sessionLog: SessionLog) throws {
        let fileURL = try sessionsDirectoryURL().appendingPathComponent("\(sessionLog.id.uuidString).json")
        let data = try encoder.encode(sessionLog)
        try data.write(to: fileURL, options: .atomic)
    }

    private func sessionsDirectoryURL() throws -> URL {
        let base = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent("ReceivedSessions", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func ingestSessionLogData(_ data: Data) {
        do {
            let log = try decoder.decode(SessionLog.self, from: data)
            ensureProfile(id: log.userId, name: log.userDisplayName)
            try save(sessionLog: log)
            loadSavedSessions()
            lastReceivedAt = Date()
            latestErrorMessage = nil
        } catch {
            latestErrorMessage = "Failed to import session log: \(error.localizedDescription)"
        }
    }

    private func ingestLivePayload(_ payload: [String: Any]) {
        guard let status = makeLiveStatus(from: payload) else { return }
        guard shouldAcceptLiveStatus(status) else { return }
        ensureProfile(id: status.userId, name: status.userDisplayName)
        liveStatus = status
        lastReceivedAt = status.timestamp
        latestErrorMessage = nil
    }

    private func makeLiveStatus(from payload: [String: Any]) -> LiveWatchStatus? {
        guard let kind = payload[ConnectivityEnvelope.kindKey] as? String,
              kind == ConnectivityEnvelope.liveStatusKind
        else {
            return nil
        }

        let timestamp = parseDate(payload["timestamp"]) ?? Date()
        let stateRawValue = payload["state"] as? String ?? AutonomicState.unknown.rawValue
        let state = AutonomicState(rawValue: stateRawValue) ?? .unknown

        return LiveWatchStatus(
            messageID: payload["messageID"] as? String ?? UUID().uuidString,
            sequenceNumber: parseInt(payload["sequenceNumber"]) ?? 0,
            timestamp: timestamp,
            userId: payload["userId"] as? String ?? "default-user",
            userDisplayName: payload["userDisplayName"] as? String ?? "デフォルト",
            isSessionRunning: payload["isSessionRunning"] as? Bool ?? true,
            inputMode: payload["inputMode"] as? String ?? "Unknown",
            heartRate: parseDouble(payload["heartRate"]),
            state: state,
            stateConfidence: parseDouble(payload["stateConfidence"]),
            signalConfidence: parseDouble(payload["signalConfidence"]),
            motionScore: parseDouble(payload["motionScore"]) ?? 0,
            sampleCount: parseInt(payload["sampleCount"]) ?? 0,
            autonomicScores: parseAutonomicScores(payload["autonomicScores"]),
            emotionEstimate: parseEmotionEstimate(payload["emotionEstimate"]),
            latestEvent: parseAnomalyEvent(payload["latestEvent"])
        )
    }

    private func parseAutonomicScores(_ value: Any?) -> AutonomicScores? {
        guard let dict = value as? [String: Any] else { return nil }
        guard let sympatheticScore = parseDouble(dict["sympatheticScore"]),
              let parasympatheticScore = parseDouble(dict["parasympatheticScore"])
        else {
            return nil
        }

        return AutonomicScores(
            timestamp: parseDate(dict["timestamp"]) ?? Date(),
            sympatheticScore: sympatheticScore,
            parasympatheticScore: parasympatheticScore,
            balanceIndex: parseDouble(dict["balanceIndex"]) ?? (sympatheticScore - parasympatheticScore),
            confidence: parseDouble(dict["confidence"]) ?? 0
        )
    }

    private func parseEmotionEstimate(_ value: Any?) -> EmotionEstimate? {
        guard let dict = value as? [String: Any] else { return nil }
        let label = EmotionLabel(rawValue: dict["label"] as? String ?? EmotionLabel.unknown.rawValue) ?? .unknown
        return EmotionEstimate(
            timestamp: parseDate(dict["timestamp"]) ?? Date(),
            label: label,
            confidence: parseDouble(dict["confidence"]) ?? 0,
            displayText: dict["displayText"] as? String ?? "\(label.japaneseName)（推定）"
        )
    }

    private func parseAnomalyEvent(_ value: Any?) -> AnomalyEvent? {
        guard let dict = value as? [String: Any] else { return nil }
        let type = AnomalyEventType(rawValue: dict["type"] as? String ?? "") ?? .lowSignal
        let severity = AnomalySeverity(rawValue: dict["severity"] as? String ?? "") ?? .info
        return AnomalyEvent(
            id: UUID(uuidString: dict["id"] as? String ?? "") ?? UUID(),
            timestamp: parseDate(dict["timestamp"]) ?? Date(),
            type: type,
            severity: severity,
            summary: dict["summary"] as? String ?? "Detected event",
            heartRate: parseDouble(dict["heartRate"]),
            deltaFromPrevious: parseDouble(dict["deltaFromPrevious"]),
            motionScore: parseDouble(dict["motionScore"]),
            signalConfidence: parseDouble(dict["signalConfidence"])
        )
    }

    private func parseDouble(_ value: Any?) -> Double? {
        switch value {
        case let double as Double:
            return double
        case let int as Int:
            return Double(int)
        case let number as NSNumber:
            return number.doubleValue
        case let string as String:
            return Double(string)
        default:
            return nil
        }
    }

    private func parseInt(_ value: Any?) -> Int? {
        switch value {
        case let int as Int:
            return int
        case let double as Double:
            return Int(double)
        case let number as NSNumber:
            return number.intValue
        case let string as String:
            return Int(string)
        default:
            return nil
        }
    }

    private func parseDate(_ value: Any?) -> Date? {
        switch value {
        case let date as Date:
            return date
        case let timeInterval as TimeInterval:
            return Date(timeIntervalSince1970: timeInterval)
        case let number as NSNumber:
            return Date(timeIntervalSince1970: number.doubleValue)
        case let string as String:
            return ISO8601DateFormatter().date(from: string)
        default:
            return nil
        }
    }

    private func applyUserFilter() {
        sessions = allSessions.filter { $0.userId == selectedUserID }
    }

    private func persistProfiles() {
        do {
            try profileStore.save(UserProfileSnapshot(profiles: profiles, selectedUserID: selectedUserID))
        } catch {
            latestErrorMessage = error.localizedDescription
        }
    }

    private func ensureProfile(id: String, name: String) {
        if profiles.contains(where: { $0.id == id }) {
            return
        }
        let profile = UserProfile(id: id, displayName: name)
        profiles.append(profile)
        persistProfiles()
    }

    private func shouldAcceptLiveStatus(_ status: LiveWatchStatus) -> Bool {
        if receivedLiveMessageIDs.contains(status.messageID) {
            return false
        }
        receivedLiveMessageIDs.append(status.messageID)
        if receivedLiveMessageIDs.count > 250 {
            receivedLiveMessageIDs.removeFirst(receivedLiveMessageIDs.count - 250)
        }

        let lastSequence = latestSequenceByUserID[status.userId] ?? 0
        if status.sequenceNumber > 0, status.sequenceNumber < lastSequence {
            if let liveStatus, status.timestamp.timeIntervalSince(liveStatus.timestamp) < 20 {
                return false
            }
        }
        latestSequenceByUserID[status.userId] = max(lastSequence, status.sequenceNumber)
        return true
    }

    private func syncSelectedUserToWatch() {
#if canImport(WatchConnectivity) && os(iOS)
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard let profile = profiles.first(where: { $0.id == selectedUserID }) else { return }
        let payload: [String: Any] = [
            ConnectivityEnvelope.kindKey: ConnectivityEnvelope.profileSyncKind,
            "messageID": UUID().uuidString,
            "timestamp": Date().timeIntervalSince1970,
            "userId": profile.id,
            "userDisplayName": profile.displayName
        ]

        do {
            try session.updateApplicationContext(payload)
        } catch {
            latestErrorMessage = error.localizedDescription
        }

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { [weak self] error in
                Task { @MainActor in
                    self?.latestErrorMessage = error.localizedDescription
                }
            }
        }
#endif
    }
}

#if canImport(WatchConnectivity)
extension WatchSessionStore: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            self.syncConnectivityState(from: session)
            self.activationStateText = Self.activationText(for: activationState, error: error)
            if let error {
                self.latestErrorMessage = error.localizedDescription
            } else {
                self.syncSelectedUserToWatch()
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            self.ingestLivePayload(applicationContext)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            self.ingestLivePayload(message)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        Task { @MainActor in
            self.ingestLivePayload(userInfo)
        }
    }

    nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
        do {
            let data = try Data(contentsOf: file.fileURL)
            Task { @MainActor in
                self.ingestSessionLogData(data)
            }
        } catch {
            Task { @MainActor in
                self.latestErrorMessage = "Failed to read transferred file: \(error.localizedDescription)"
            }
        }
    }

}

private extension WatchSessionStore {
    static func activationText(
        for state: WCSessionActivationState,
        error: Error?
    ) -> String {
        if error != nil {
            return "Activation failed"
        }

        switch state {
        case .activated:
            return "Connected"
        case .inactive:
            return "Inactive"
        case .notActivated:
            return "Not activated"
        @unknown default:
            return "Unknown"
        }
    }
}
#endif

#if canImport(WatchConnectivity) && os(iOS)
extension WatchSessionStore {
    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.syncConnectivityState(from: session)
            self.syncSelectedUserToWatch()
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}
#endif
