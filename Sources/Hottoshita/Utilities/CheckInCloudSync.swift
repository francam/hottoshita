import CloudKit
import Foundation
import os.log

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
    private let log = Logger(subsystem: "com.hottoshita.app", category: "CheckInCloudSync")

    private init() {}

    /// Pushes one entry — called right after every local save/update.
    /// Best-effort on failure, matching how local persistence errors are
    /// already handled (the entry stays safe in the local JSON file either
    /// way and gets picked up again by the next full sync), but logged —
    /// CloudKit failures here were previously silent and undiagnosable,
    /// which is how a broken-since-day-one sync path went unnoticed.
    func push(_ entry: CheckInAnswers) {
        guard iCloudSettingsSync.shared.isEnabled else { return }
        guard let json = try? JSONEncoder().encode(entry),
              let payload = String(data: json, encoding: .utf8) else {
            log.error("push: failed to encode entry \(entry.id, privacy: .public)")
            return
        }
        let record = CKRecord(recordType: Self.recordType, recordID: CKRecord.ID(recordName: entry.id.uuidString))
        record["payload"] = payload as CKRecordValue
        record["date"] = entry.date as CKRecordValue
        database.save(record) { [log] _, error in
            if let error {
                log.error("push failed for \(entry.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func pushAll(_ entries: [CheckInAnswers]) {
        for entry in entries { push(entry) }
    }

    func delete(id: UUID) {
        guard iCloudSettingsSync.shared.isEnabled else { return }
        database.delete(withRecordID: CKRecord.ID(recordName: id.uuidString)) { [log] _, error in
            if let error {
                log.error("delete failed for \(id, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Fetches every remote entry. Called on launch to merge in anything
    /// created on another device, and once when sync is first turned on.
    func fetchAll() async -> [CheckInAnswers] {
        guard iCloudSettingsSync.shared.isEnabled else { return [] }
        do {
            let status = try await container.accountStatus()
            guard status == .available else {
                log.error("fetchAll: iCloud account not available, status=\(status.rawValue, privacy: .public)")
                return []
            }
        } catch {
            log.error("fetchAll: accountStatus check failed: \(error.localizedDescription, privacy: .public)")
            return []
        }

        let query = CKQuery(recordType: Self.recordType, predicate: NSPredicate(value: true))
        let results: [(CKRecord.ID, Result<CKRecord, Error>)]
        do {
            (results, _) = try await database.records(matching: query)
        } catch {
            log.error("fetchAll: query failed: \(error.localizedDescription, privacy: .public)")
            return []
        }

        return results.compactMap { _, result -> CheckInAnswers? in
            switch result {
            case .failure(let error):
                log.error("fetchAll: record fetch failed: \(error.localizedDescription, privacy: .public)")
                return nil
            case .success(let record):
                guard let payload = record["payload"] as? String,
                      let data = payload.data(using: .utf8) else {
                    log.error("fetchAll: record \(record.recordID.recordName, privacy: .public) missing/malformed payload")
                    return nil
                }
                guard let decoded = try? JSONDecoder().decode(CheckInAnswers.self, from: data) else {
                    log.error("fetchAll: failed to decode payload for \(record.recordID.recordName, privacy: .public)")
                    return nil
                }
                return decoded
            }
        }
    }
}
