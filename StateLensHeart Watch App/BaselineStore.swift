import Foundation

final class BaselineStore {
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    func load(userId: String = "default-user") -> UserBaseline? {
        do {
            let data = try Data(contentsOf: baselineFileURL(userId: userId))
            return try decoder.decode(UserBaseline.self, from: data)
        } catch {
            return nil
        }
    }

    func save(_ baseline: UserBaseline, userId: String = "default-user") throws {
        let data = try encoder.encode(baseline)
        try data.write(to: baselineFileURL(userId: userId), options: .atomic)
    }

    private func baselineFileURL(userId: String) throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let safeUserID = userId.replacingOccurrences(of: "/", with: "_")
        return base.appendingPathComponent("user-baseline-\(safeUserID).json")
    }
}
