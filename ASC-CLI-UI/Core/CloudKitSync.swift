import Foundation
import Combine
import CloudKit
import ASCShared

// MARK: - CloudKit uploader (Phase 2 producer)

/// Uploads ``Snapshot`` records to the user's **private** CloudKit database so a future
/// companion iPhone app (Phase 3) can read App Store Connect state offline.
///
/// Design (see `MOBILE_REMOTE.md`):
/// - Container `iCloud.PySaasNow.ASC-CLI-UI`, private database.
/// - A single custom zone named `ASCMirror` holds every record.
/// - One `CKRecord` (type `ASCSnapshot`) per `(appId, section)`, keyed by the stable
///   record name `"<appId>:<section>"`, upserted last-writer-wins.
/// - `payloadJSON` is stored as a String field, or — above ~900 KB — as a `CKAsset`.
///
/// Every CloudKit call is wrapped so failures surface via ``lastError`` but never crash
/// the app. CloudKit only works at runtime once the iCloud container is provisioned and
/// the entitlement is enabled (see `MOBILE_REMOTE.md`); until then uploads simply fail
/// gracefully and the rest of the app is unaffected.
@MainActor
final class CloudKitSync: ObservableObject {
    @Published private(set) var lastError: String?

    private let container: CKContainer
    private let database: CKDatabase
    private var zoneEnsured = false

    init(containerID: String = RemoteMirror.containerID) {
        container = CKContainer(identifier: containerID)
        database = container.privateCloudDatabase
    }

    private var zoneID: CKRecordZone.ID {
        CKRecordZone.ID(zoneName: RemoteMirror.zoneName, ownerName: CKCurrentUserDefaultName)
    }

    /// Creates the custom zone if it doesn't exist yet. Idempotent.
    func ensureZone() async throws {
        if zoneEnsured { return }
        let zone = CKRecordZone(zoneID: zoneID)
        _ = try await database.modifyRecordZones(saving: [zone], deleting: [])
        zoneEnsured = true
    }

    /// Upserts the given snapshots. Returns the number of records successfully saved, or
    /// an error. Never throws to the caller — the result captures success/failure.
    @discardableResult
    func upload(_ snapshots: [Snapshot]) async -> Result<Int, Error> {
        guard !snapshots.isEmpty else { return .success(0) }
        var tempURLs: [URL] = []
        do {
            try await ensureZone()

            var records: [CKRecord] = []
            for snap in snapshots {
                let (record, tempURL) = try makeRecord(snap)
                records.append(record)
                if let tempURL { tempURLs.append(tempURL) }
            }

            // `.allKeys` ignores the server change tag, giving a blind last-writer-wins
            // upsert. Non-atomic so one bad record doesn't sink the whole batch.
            let (saveResults, _) = try await database.modifyRecords(
                saving: records,
                deleting: [],
                savePolicy: .allKeys,
                atomically: false
            )

            cleanup(tempURLs)

            var saved = 0
            var firstFailure: Error?
            for (_, result) in saveResults {
                switch result {
                case .success: saved += 1
                case .failure(let error): if firstFailure == nil { firstFailure = error }
                }
            }
            if saved == 0, let firstFailure { throw firstFailure }

            lastError = nil
            return .success(saved)
        } catch {
            cleanup(tempURLs)
            let message = Self.message(for: error)
            lastError = message
            return .failure(error)
        }
    }

    // MARK: - Record building

    /// Builds a `CKRecord` for a snapshot. Returns the record plus the temp file URL for
    /// the `CKAsset` (if the payload was large enough to be stored as an asset) so the
    /// caller can delete it after the upload completes.
    private func makeRecord(_ snap: Snapshot) throws -> (CKRecord, URL?) {
        let recordID = CKRecord.ID(
            recordName: RemoteMirror.recordName(appId: snap.appId, section: snap.section),
            zoneID: zoneID
        )
        let record = CKRecord(recordType: RemoteMirror.recordType, recordID: recordID)
        record["appId"] = snap.appId as CKRecordValue
        record["section"] = snap.section as CKRecordValue
        record["schemaVersion"] = snap.schemaVersion as CKRecordValue
        record["capturedAt"] = snap.capturedAt as CKRecordValue

        if let summary = snap.summary,
           let data = try? JSONSerialization.data(withJSONObject: summary, options: [.sortedKeys]),
           let json = String(data: data, encoding: .utf8) {
            record["summary"] = json as CKRecordValue
        }

        let byteCount = RemoteMirror.payloadByteCount(snap.payloadJSON)
        if RemoteMirror.shouldUseAsset(payloadByteCount: byteCount) {
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("ascmirror-\(UUID().uuidString).json")
            try Data(snap.payloadJSON.utf8).write(to: tempURL, options: .atomic)
            record["payloadAsset"] = CKAsset(fileURL: tempURL)
            record["payloadIsAsset"] = 1 as CKRecordValue
            return (record, tempURL)
        } else {
            record["payloadJSON"] = snap.payloadJSON as CKRecordValue
            record["payloadIsAsset"] = 0 as CKRecordValue
            return (record, nil)
        }
    }

    private func cleanup(_ urls: [URL]) {
        for url in urls { try? FileManager.default.removeItem(at: url) }
    }

    /// A concise, user-friendly description for a CloudKit error.
    static func message(for error: Error) -> String {
        if let ckError = error as? CKError {
            switch ckError.code {
            case .notAuthenticated:
                return "Not signed in to iCloud. Sign in to iCloud in System Settings."
            case .networkUnavailable, .networkFailure:
                return "Network unavailable."
            case .quotaExceeded:
                return "iCloud storage quota exceeded."
            case .permissionFailure:
                return "iCloud permission denied. Check the app's iCloud capability."
            case .zoneNotFound, .userDeletedZone:
                return "The mirror zone is missing and will be recreated on the next sync."
            default:
                return ckError.localizedDescription
            }
        }
        return error.localizedDescription
    }
}
