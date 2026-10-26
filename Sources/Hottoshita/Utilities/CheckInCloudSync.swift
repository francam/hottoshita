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
        // database.save(_:) defaults to the .ifServerRecordUnchanged policy,
        // which compares change tags — but a freshly-built CKRecord has none,
        // so updating an entry that was already pushed once (e.g. marking it
        // sent) always lost to a CKError.serverRecordChanged conflict.
        // .allKeys unconditionally overwrites, which is what we want since
        // the device doing the push always has the authoritative full state
        // for that entry.
        Task { [log, database] in
            do {
                let (saveResults, _) = try await database.modifyRecords(
                    saving: [record], deleting: [], savePolicy: .allKeys, atomically: true
                )
                if case .failure(let error) = saveResults[record.recordID] {
                    log.error("push failed for \(entry.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
                }
            } catch {
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

    /// Deletes every check-in record from the user's private database (Erase
    /// All Data). Unlike push/delete this ignores the sync switch: a copy
    /// uploaded while sync was on stays in iCloud after it's turned off.
    /// Returns false only when iCloud was reachable but the deletion failed
    /// (e.g. offline) — with no iCloud account there's nothing to delete.
    func deleteAll() async -> Bool {
        do {
            guard try await container.accountStatus() == .available else { return true }
        } catch {
            log.error("deleteAll: accountStatus check failed: \(error.localizedDescription, privacy: .public)")
            return false
        }

        // Same queryable predicate as fetchAll; ids only.
        let query = CKQuery(recordType: Self.recordType, predicate: NSPredicate(format: "date > %@", Date.distantPast as NSDate))
        var ids: [CKRecord.ID] = []
        do {
            var (results, cursor) = try await database.records(matching: query, desiredKeys: [])
            ids += results.map(\.0)
            while let next = cursor {
                (results, cursor) = try await database.records(continuingMatchFrom: next, desiredKeys: [])
                ids += results.map(\.0)
            }
            // CloudKit caps a modify operation at 400 records.
            for start in stride(from: 0, to: ids.count, by: 400) {
                let batch = Array(ids[start..<min(start + 400, ids.count)])
                _ = try await database.modifyRecords(saving: [], deleting: batch, atomically: false)
            }
        } catch {
            log.error("deleteAll failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
        return true
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

        // NSPredicate(value: true) would query against recordName, which has
        // no queryable index by default and fails with "Field 'recordName'
        // is not marked queryable". Querying on `date` instead works with a
        // queryable index on that field, which we do control in the schema.
        let query = CKQuery(recordType: Self.recordType, predicate: NSPredicate(format: "date > %@", Date.distantPast as NSDate))
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
