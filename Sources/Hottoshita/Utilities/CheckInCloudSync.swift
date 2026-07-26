import CloudKit
import Foundation

/// Syncs check-in history to the user's private CloudKit database so it can
/// appear on their other devices. Each check-in is stored as a single JSON
/// blob keyed by its UUID — CloudKit is a second copy, not a replacement;
/// `CheckInStore`'s local JSON file stays the offline source of truth, and
/// everything degrades silently to local-only if sync is off or iCloud
/// isn't available.
@MainActor
final class CheckInCloudSync {
    static let shared = CheckInCloudSync()

    private static let containerID = "iCloud.com.hottoshita.app"
    private static let recordType = "CheckIn"

    private var container: CKContainer { CKContainer(identifier: Self.containerID) }
    private var database: CKDatabase { container.privateCloudDatabase }

    private init() {}

    /// Pushes one entry — called right after every local save/update.
    /// Best-effort and silent on failure, matching how local persistence
    /// errors are already handled: the entry stays safe in the local JSON
    /// file either way and gets picked up again by the next full sync.
    func push(_ entry: CheckInAnswers) {
        guard iCloudSettingsSync.shared.isEnabled,
              let json = try? JSONEncoder().encode(entry),
              let payload = String(data: json, encoding: .utf8) else { return }
        let record = CKRecord(recordType: Self.recordType, recordID: CKRecord.ID(recordName: entry.id.uuidString))
        record["payload"] = payload as CKRecordValue
        record["date"] = entry.date as CKRecordValue
        database.save(record) { _, _ in }
    }

    func pushAll(_ entries: [CheckInAnswers]) {
        for entry in entries { push(entry) }
    }

    func delete(id: UUID) {
        guard iCloudSettingsSync.shared.isEnabled else { return }
        database.delete(withRecordID: CKRecord.ID(recordName: id.uuidString)) { _, _ in }
    }

    /// Fetches every remote entry. Called on launch to merge in anything
    /// created on another device, and once when sync is first turned on.
    func fetchAll() async -> [CheckInAnswers] {
        guard iCloudSettingsSync.shared.isEnabled,
              (try? await container.accountStatus()) == .available else { return [] }

        let query = CKQuery(recordType: Self.recordType, predicate: NSPredicate(value: true))
        guard let (results, _) = try? await database.records(matching: query) else { return [] }

        return results.compactMap { _, result -> CheckInAnswers? in
            guard let record = try? result.get(),
                  let payload = record["payload"] as? String,
                  let data = payload.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode(CheckInAnswers.self, from: data)
        }
    }
}
