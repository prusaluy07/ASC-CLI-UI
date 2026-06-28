import Foundation
import Combine
import CloudKit
import ASCShared

// MARK: - CloudKit consumer (Phase 3b reader)

/// Read-only consumer of the macOS app's CloudKit mirror.
///
/// It reads ``Snapshot`` records (record type `ASCSnapshot`) from the **private** database
/// custom zone `ASCMirror`, using the exact same constants the producer wrote them with —
/// `RemoteMirror.containerID`, `RemoteMirror.zoneName`, `RemoteMirror.recordType` and the
/// `appId/section/schemaVersion/capturedAt/summary/payloadIsAsset/payloadJSON|payloadAsset`
/// field layout (see `RemoteMirror.swift` + `CloudKitSync.swift`). It never writes ASC data
/// and never invokes the `asc` CLI — it only reads the mirror.
///
/// Records are fetched with `CKFetchRecordZoneChangesOperation` (full fetch, no stored
/// token) so it works without any queryable indexes and naturally pairs with the database
/// subscription used for push. Both String and `CKAsset` payloads are handled; the asset
/// file is read off the record before the pure ``RemoteMirror/makeSnapshot(from:assetPayloadJSON:)``
/// builds the `Snapshot`.
///
/// Every CloudKit call is wrapped so failures surface via ``errorMessage`` / empty state and
/// never crash. A manual ``refresh()`` is exposed for pull-to-refresh and push-driven reloads.
@MainActor
final class CloudKitMirrorReader: ObservableObject {
    @Published private(set) var groups: [MirrorAppGroup] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastRefreshed: Date?
    /// True once the cache has been loaded, so the UI can distinguish "loading" from "empty".
    @Published private(set) var didLoadCache = false

    private let container: CKContainer
    private let database: CKDatabase
    private let cache: SnapshotCache

    init(containerID: String = RemoteMirror.containerID, cache: SnapshotCache = .shared) {
        container = CKContainer(identifier: containerID)
        database = container.privateCloudDatabase
        self.cache = cache
    }

    private var zoneID: CKRecordZone.ID {
        CKRecordZone.ID(zoneName: RemoteMirror.zoneName, ownerName: CKCurrentUserDefaultName)
    }

    var hasData: Bool { !groups.isEmpty }

    // MARK: Lookups (for navigation destinations)

    func group(for appId: String) -> MirrorAppGroup? {
        groups.first { $0.appId == appId }
    }

    func snapshot(appId: String, section: MirrorSection) -> Snapshot? {
        group(for: appId)?.snapshots[section]
    }

    // MARK: Cache

    /// Loads last-known data from disk so the UI has something to show instantly / offline.
    func loadCache() {
        let cached = cache.load()
        if !cached.isEmpty {
            groups = RemoteMirror.group(cached)
        }
        didLoadCache = true
    }

    // MARK: Refresh

    /// Fetches the latest snapshots from CloudKit, updates the cache and published state.
    /// Never throws — failures are captured in ``errorMessage``.
    func refresh() async {
        if isRefreshing { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let records = try await fetchZoneRecords()
            let snapshots = records.compactMap(snapshot(from:))
            cache.save(snapshots)
            groups = RemoteMirror.group(snapshots)
            lastRefreshed = Date()
            errorMessage = nil
        } catch let error as CKError where Self.isEmptyZoneError(error) {
            // Zone not created yet (producer never synced) → treat as "no data", not error.
            groups = []
            errorMessage = nil
        } catch {
            // Keep any cached groups visible; just surface the problem.
            errorMessage = Self.message(for: error)
        }
    }

    // MARK: CloudKit I/O

    /// Full fetch of every record in the mirror zone. Returns `[]` cleanly; throws only on
    /// real failures (auth/network), which the caller maps to a user-visible message.
    private func fetchZoneRecords() async throws -> [CKRecord] {
        let collector = RecordCollector()
        let zoneID = self.zoneID

        return try await withCheckedThrowingContinuation { continuation in
            let config = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
            config.previousServerChangeToken = nil   // nil = fetch everything

            let operation = CKFetchRecordZoneChangesOperation(
                recordZoneIDs: [zoneID],
                configurationsByRecordZoneID: [zoneID: config]
            )

            operation.recordWasChangedBlock = { _, result in
                if case .success(let record) = result { collector.add(record) }
            }

            operation.fetchRecordZoneChangesResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: collector.records)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            database.add(operation)
        }
    }

    /// Extracts a ``Snapshot`` from a record, reading the `CKAsset` payload file when the
    /// payload was stored as an asset. Returns `nil` for malformed records (skipped safely).
    private func snapshot(from record: CKRecord) -> Snapshot? {
        guard let appId = record["appId"] as? String,
              let section = record["section"] as? String else { return nil }

        let schemaVersion = (record["schemaVersion"] as? Int) ?? Snapshot.currentSchemaVersion
        let capturedAt = (record["capturedAt"] as? Date) ?? Date()
        let summaryJSON = record["summary"] as? String
        let payloadIsAsset = ((record["payloadIsAsset"] as? Int) ?? 0) == 1
        let inlinePayload = record["payloadJSON"] as? String

        var assetPayload: String?
        if payloadIsAsset,
           let asset = record["payloadAsset"] as? CKAsset,
           let url = asset.fileURL {
            assetPayload = (try? Data(contentsOf: url)).map { String(decoding: $0, as: UTF8.self) }
        }

        let fields = SnapshotFields(appId: appId,
                                    section: section,
                                    schemaVersion: schemaVersion,
                                    capturedAt: capturedAt,
                                    summaryJSON: summaryJSON,
                                    payloadIsAsset: payloadIsAsset,
                                    inlinePayloadJSON: inlinePayload)
        return RemoteMirror.makeSnapshot(from: fields, assetPayloadJSON: assetPayload)
    }

    // MARK: Error mapping

    /// A zone/record-not-found state means the producer simply hasn't synced yet — we treat
    /// it as empty rather than an error so the empty state (not an error banner) is shown.
    private static func isEmptyZoneError(_ error: CKError) -> Bool {
        switch error.code {
        case .zoneNotFound, .userDeletedZone, .unknownItem:
            return true
        case .partialFailure:
            guard let partials = error.partialErrorsByItemID?.values, !partials.isEmpty else {
                return false
            }
            return partials.allSatisfy { partial in
                guard let ck = partial as? CKError else { return false }
                return ck.code == .zoneNotFound || ck.code == .userDeletedZone || ck.code == .unknownItem
            }
        default:
            return false
        }
    }

    /// A concise, user-friendly description for a CloudKit error.
    static func message(for error: Error) -> String {
        if let ckError = error as? CKError {
            switch ckError.code {
            case .notAuthenticated:
                return "Not signed in to iCloud. Sign in to iCloud in Settings."
            case .networkUnavailable, .networkFailure:
                return "Network unavailable."
            case .quotaExceeded:
                return "iCloud storage quota exceeded."
            case .permissionFailure:
                return "iCloud permission denied. Check the app’s iCloud capability."
            case .zoneNotFound, .userDeletedZone:
                return "No mirror data found yet."
            default:
                return ckError.localizedDescription
            }
        }
        return error.localizedDescription
    }
}

/// Reference-type sink for records gathered on CloudKit's background callback queue. The
/// operation serializes its `recordWasChangedBlock` calls, so plain appends are safe; the
/// `@unchecked Sendable` lets it cross into the operation's `@Sendable` closures cleanly.
private final class RecordCollector: @unchecked Sendable {
    private(set) var records: [CKRecord] = []
    func add(_ record: CKRecord) { records.append(record) }
}
