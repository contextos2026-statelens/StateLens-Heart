import Foundation

final class SessionLogStore {
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private var activeLog: SessionLog?

    func startSession() {
        activeLog = SessionLog(startedAt: Date())
        persistActiveLog()
    }

    func append(sample: HeartSample, estimation: StateEstimation?) {
        guard var log = activeLog else { return }
        log.samples.append(sample)
        log.latestEstimation = estimation
        activeLog = log
        persistActiveLog()
    }

    func finishSession() throws -> URL? {
        guard var log = activeLog else { return nil }
        log.endedAt = Date()
        activeLog = log

        let sessionsURL = try sessionDirectoryURL()
        let fileURL = sessionsURL.appendingPathComponent("\(log.id.uuidString).json")
        let data = try encoder.encode(log)
        try data.write(to: fileURL, options: .atomic)

        try? FileManager.default.removeItem(at: activeSessionURL())
        activeLog = nil
        return fileURL
    }

    private func persistActiveLog() {
        guard let log = activeLog else { return }
        do {
            let data = try encoder.encode(log)
            try data.write(to: activeSessionURL(), options: .atomic)
        } catch {
            assertionFailure("Failed to persist active log: \(error)")
        }
    }

    private func activeSessionURL() -> URL {
        let base = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return (base ?? FileManager.default.temporaryDirectory).appendingPathComponent("active-session.json")
    }

    private func sessionDirectoryURL() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let sessions = base.appendingPathComponent("Sessions", isDirectory: true)
        try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
        return sessions
    }
}
