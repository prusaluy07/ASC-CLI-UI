import Foundation

// MARK: - Remote mirror (Phase 3b: CloudKit consumer)

/// The raw field values read from one `ASCSnapshot` CloudKit record, decoupled from
/// CloudKit itself. The iOS consumer (`CloudKitMirrorReader`) extracts these from a
/// `CKRecord`, then calls ``RemoteMirror/makeSnapshot(from:assetPayloadJSON:)`` to turn
/// them into a ``Snapshot``. Keeping this a plain value type means the record→snapshot
/// transformation is pure and unit-testable without importing CloudKit.
///
/// Field names mirror exactly what the macOS producer writes (`CloudKitSync.makeRecord`):
/// `appId`, `section`, `schemaVersion`, `capturedAt`, `summary` (JSON string),
/// `payloadIsAsset` (0/1), and the payload as either a `payloadJSON` String field or a
/// `payloadAsset` `CKAsset`.
public struct SnapshotFields: Sendable, Equatable {
    public var appId: String
    public var section: String
    public var schemaVersion: Int
    public var capturedAt: Date
    /// JSON string of the headline summary values, as stored in the `summary` field.
    public var summaryJSON: String?
    /// Whether the payload is stored as a `CKAsset` (`payloadIsAsset == 1`).
    public var payloadIsAsset: Bool
    /// The inline `payloadJSON` String field value (present when `payloadIsAsset` is false).
    public var inlinePayloadJSON: String?

    public init(appId: String,
                section: String,
                schemaVersion: Int,
                capturedAt: Date,
                summaryJSON: String? = nil,
                payloadIsAsset: Bool = false,
                inlinePayloadJSON: String? = nil) {
        self.appId = appId
        self.section = section
        self.schemaVersion = schemaVersion
        self.capturedAt = capturedAt
        self.summaryJSON = summaryJSON
        self.payloadIsAsset = payloadIsAsset
        self.inlinePayloadJSON = inlinePayloadJSON
    }
}

// MARK: - Grouping

/// All mirrored sections for a single app, keyed by ``MirrorSection``. Produced by
/// ``RemoteMirror/group(_:)`` and used to drive the consumer's per-app UI.
public struct MirrorAppGroup: Identifiable, Hashable, Sendable {
    public let appId: String
    /// Latest snapshot per section for this app (one entry per mirrored section).
    public let snapshots: [MirrorSection: Snapshot]

    public var id: String { appId }

    public init(appId: String, snapshots: [MirrorSection: Snapshot]) {
        self.appId = appId
        self.snapshots = snapshots
    }

    /// Sections present for this app, in stable ``MirrorSection/allCases`` order.
    public var orderedSections: [MirrorSection] {
        MirrorSection.allCases.filter { snapshots[$0] != nil }
    }

    /// Snapshots in stable section order (handy for `ForEach`).
    public var orderedSnapshots: [Snapshot] {
        orderedSections.compactMap { snapshots[$0] }
    }

    /// The most recent `capturedAt` across all of this app's sections, if any.
    public var lastUpdated: Date? {
        snapshots.values.map(\.capturedAt).max()
    }

    /// The app's display name, if the producer mirrored it into any section summary.
    /// Falls back to `nil` for older snapshots captured before names were mirrored.
    public var appName: String? {
        orderedSnapshots.lazy
            .compactMap { $0.summary?["appName"] }
            .first { !$0.isEmpty }
    }
}

// MARK: - Pure consumer helpers

public extension RemoteMirror {

    /// Builds a ``Snapshot`` from raw record fields plus an already-resolved asset payload
    /// (the consumer reads the `CKAsset` file before calling this so the function stays
    /// pure). Returns `nil` only when the payload is an asset but no asset content was
    /// provided — i.e. the record is unusable — so callers can skip it safely.
    static func makeSnapshot(from fields: SnapshotFields,
                             assetPayloadJSON: String?) -> Snapshot? {
        let payload: String
        if fields.payloadIsAsset {
            guard let assetPayloadJSON else { return nil }
            payload = assetPayloadJSON
        } else {
            payload = fields.inlinePayloadJSON ?? ""
        }
        let summary = fields.summaryJSON.flatMap(decodeSummary)
        return Snapshot(appId: fields.appId,
                        section: fields.section,
                        schemaVersion: fields.schemaVersion,
                        capturedAt: fields.capturedAt,
                        payloadJSON: payload,
                        summary: summary)
    }

    /// Decodes the `summary` JSON string the producer stored (a flat `[String: String]`
    /// object). Defensive: returns `nil` on any parse miss so the UI just omits headlines.
    static func decodeSummary(_ json: String) -> [String: String]? {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        var result: [String: String] = [:]
        for (key, value) in object {
            if let s = value as? String { result[key] = s }
            else if let n = value as? NSNumber { result[key] = n.stringValue }
        }
        return result.isEmpty ? nil : result
    }

    /// Groups snapshots by `appId`, keeping only the **latest** snapshot per section
    /// (by `capturedAt`). Snapshots whose `section` isn't a known ``MirrorSection`` are
    /// ignored. The result is sorted by `appId` for a stable UI ordering.
    static func group(_ snapshots: [Snapshot]) -> [MirrorAppGroup] {
        var byApp: [String: [MirrorSection: Snapshot]] = [:]
        for snap in snapshots {
            guard let section = MirrorSection(rawValue: snap.section) else { continue }
            var sections = byApp[snap.appId] ?? [:]
            if let existing = sections[section] {
                if snap.capturedAt > existing.capturedAt { sections[section] = snap }
            } else {
                sections[section] = snap
            }
            byApp[snap.appId] = sections
        }
        return byApp
            .map { MirrorAppGroup(appId: $0.key, snapshots: $0.value) }
            .sorted { $0.appId.localizedStandardCompare($1.appId) == .orderedAscending }
    }

    /// Picks the most recently captured snapshot from a list, or `nil` if empty.
    static func latest(_ snapshots: [Snapshot]) -> Snapshot? {
        snapshots.max { $0.capturedAt < $1.capturedAt }
    }
}
