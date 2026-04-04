import Foundation

struct UserProfileSnapshot: Codable {
    var profiles: [UserProfile]
    var selectedUserID: String
}

final class UserProfileStore {
    private let fileManager = FileManager.default
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

    func load() -> UserProfileSnapshot {
        guard let data = try? Data(contentsOf: fileURL()),
              let snapshot = try? decoder.decode(UserProfileSnapshot.self, from: data),
              !snapshot.profiles.isEmpty
        else {
            let fallback = defaultSnapshot()
            try? save(fallback)
            return fallback
        }

        if snapshot.profiles.contains(where: { $0.id == snapshot.selectedUserID }) {
            return snapshot
        }

        var fixed = snapshot
        fixed.selectedUserID = snapshot.profiles.first?.id ?? defaultProfile().id
        try? save(fixed)
        return fixed
    }

    func save(_ snapshot: UserProfileSnapshot) throws {
        let data = try encoder.encode(snapshot)
        try data.write(to: fileURL(), options: .atomic)
    }

    func upsert(profile: UserProfile) throws -> UserProfileSnapshot {
        var snapshot = load()
        if let index = snapshot.profiles.firstIndex(where: { $0.id == profile.id }) {
            snapshot.profiles[index] = profile
        } else {
            snapshot.profiles.append(profile)
        }
        try save(snapshot)
        return snapshot
    }

    private func defaultSnapshot() -> UserProfileSnapshot {
        let user = defaultProfile()
        return UserProfileSnapshot(
            profiles: [user],
            selectedUserID: user.id
        )
    }

    private func defaultProfile() -> UserProfile {
        UserProfile(id: "default-user", displayName: "デフォルト")
    }

    private func fileURL() throws -> URL {
        let base = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return base.appendingPathComponent("user-profiles.json")
    }
}
