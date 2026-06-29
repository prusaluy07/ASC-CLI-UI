import Foundation

// MARK: - Remote mirror (Phase 2: CloudKit producer)

/// App Store Connect sections that the macOS app can mirror to iCloud so a future
/// companion iPhone app (Phase 3) can read them. Each case maps to a single `asc`
/// read-only command whose JSON output is wrapped in a ``Snapshot``.
///
/// The raw value is used both as the snapshot `section` string and as the suffix in
/// the CloudKit record name, so it must stay stable.
public enum MirrorSection: String, CaseIterable, Identifiable, Codable, Sendable {
    /// Release readiness report (`asc status`).
    case status
    /// App Store versions (`asc versions list`).
    case versions
    /// Uploaded builds (`asc builds list`).
    case builds
    /// TestFlight beta groups (`asc testflight groups list`).
    case betaGroups
    /// Customer review rating summary (`asc reviews ratings`).
    case reviews
    /// Current pricing (`asc pricing current`).
    case pricing
    /// Subscription groups (`asc subscriptions groups list`).
    case subscriptions
    /// In-app purchases (`asc iap list`).
    case inAppPurchases
    /// Weekly analytics insights (`asc insights weekly --source analytics`).
    case analytics

    public var id: String { rawValue }

    /// Localization key for the human-facing section name (reuses existing keys).
    public var locKey: LocKey {
        switch self {
        case .status:          return .secRelease
        case .versions:        return .secVersions
        case .builds:          return .secBuilds
        case .betaGroups:      return .secTestFlight
        case .reviews:         return .secReviews
        case .pricing:         return .secPricing
        case .subscriptions:   return .secSubscriptions
        case .inAppPurchases:  return .secIAP
        case .analytics:       return .secAnalytics
        }
    }
}

public extension MirrorSection {
    /// Sections enabled by default when the user first turns on remote sync.
    /// Kept tight (the cheap, high-signal sections) to avoid hammering the CLI.
    static let defaultSelection: Set<MirrorSection> = [.status, .versions, .builds]

    /// Default selection encoded as a comma-joined raw string for `AppStorage`.
    static var defaultRaw: String { encode(defaultSelection) }

    /// Decodes a comma-joined raw string (unknown tokens are ignored).
    static func decode(_ raw: String) -> Set<MirrorSection> {
        Set(raw.split(separator: ",").compactMap { MirrorSection(rawValue: String($0)) })
    }

    /// Encodes a selection deterministically (ordered by `allCases`).
    static func encode(_ set: Set<MirrorSection>) -> String {
        allCases.filter { set.contains($0) }.map(\.rawValue).joined(separator: ",")
    }
}

// MARK: - Sync interval

/// How often the producer captures + uploads snapshots while remote sync is enabled.
public enum SyncInterval: String, CaseIterable, Identifiable, Sendable {
    case every15Minutes
    case hourly
    case every6Hours
    case daily

    public var id: String { rawValue }

    public var seconds: TimeInterval {
        switch self {
        case .every15Minutes: return 15 * 60
        case .hourly:         return 60 * 60
        case .every6Hours:    return 6 * 60 * 60
        case .daily:          return 24 * 60 * 60
        }
    }

    public var locKey: LocKey {
        switch self {
        case .every15Minutes: return .syncEvery15m
        case .hourly:         return .syncHourly
        case .every6Hours:    return .syncEvery6h
        case .daily:          return .syncDaily
        }
    }
}

// MARK: - CloudKit design constants + pure helpers

/// Pure, side-effect-free helpers describing the CloudKit mirror layout and the
/// transformation from `asc` JSON into a ``Snapshot``'s summary. Kept free of any
/// CloudKit import so it compiles + unit-tests on every platform.
public enum RemoteMirror {
    /// iCloud container hosting the private mirror database.
    public static let containerID = "iCloud.PySaasNow.ASC-CLI-UI"
    /// Custom private-database zone that holds every mirror record.
    public static let zoneName = "ASCMirror"
    /// CKRecord type for a mirrored section snapshot.
    public static let recordType = "ASCSnapshot"

    /// Above this many bytes the `payloadJSON` is stored as a `CKAsset` instead of a
    /// String field (CloudKit string fields are limited; ~1 MB record soft limit).
    public static let assetThresholdBytes = 900_000

    /// Stable record name for a given app + section: `"<appId>:<section>"`.
    public static func recordName(appId: String, section: String) -> String {
        "\(appId):\(section)"
    }

    public static func recordName(appId: String, section: MirrorSection) -> String {
        recordName(appId: appId, section: section.rawValue)
    }

    /// Whether a payload of the given size should be stored as a `CKAsset`.
    public static func shouldUseAsset(payloadByteCount: Int,
                                      threshold: Int = assetThresholdBytes) -> Bool {
        payloadByteCount > threshold
    }

    /// Byte size of a payload string as stored (UTF-8).
    public static func payloadByteCount(_ payloadJSON: String) -> Int {
        payloadJSON.utf8.count
    }

    // MARK: Summary extraction

    /// Extracts a small set of headline display values from a section's raw JSON.
    /// Defensive: returns an empty dictionary on any parse miss so callers never crash.
    public static func summarize(section: MirrorSection, payloadJSON: String) -> [String: String] {
        guard let data = payloadJSON.data(using: .utf8),
              let root = try? JSONDecoder().decode(JSONValue.self, from: data) else { return [:] }

        switch section {
        case .status:          return statusSummary(root)
        case .versions:        return versionsSummary(root)
        case .builds:          return buildsSummary(root)
        case .betaGroups:      return collectionSummary(root)
        case .subscriptions:   return collectionSummary(root)
        case .pricing:         return collectionSummary(root)
        case .inAppPurchases:  return collectionSummary(root)
        case .reviews:         return reviewsSummary(root)
        case .analytics:       return analyticsSummary(root)
        }
    }

    private static func statusSummary(_ root: JSONValue) -> [String: String] {
        var s: [String: String] = [:]
        if let summary = root["summary"] {
            if let h = summary["health"]?.stringValue { s["health"] = h }
            if let n = summary["nextAction"]?.stringValue { s["nextAction"] = n }
        }
        if let b = root["builds"]?["latest"]?["buildNumber"]?.stringValue { s["latestBuild"] = b }
        if let st = root["appstore"]?["state"]?.stringValue { s["appStoreState"] = st }
        if let rv = root["review"]?["state"]?.stringValue { s["reviewState"] = rv }
        return s
    }

    private static func versionsSummary(_ root: JSONValue) -> [String: String] {
        let arr = items(root)
        var s = ["count": String(arr.count)]
        if let attrs = arr.first?["attributes"] {
            if let v = attrs["versionString"]?.stringValue { s["latestVersion"] = v }
            if let st = (attrs["appStoreState"] ?? attrs["appVersionState"])?.stringValue { s["latestState"] = st }
        }
        return s
    }

    private static func buildsSummary(_ root: JSONValue) -> [String: String] {
        let arr = items(root)
        var s = ["count": String(arr.count)]
        if let attrs = arr.first?["attributes"] {
            if let v = attrs["version"]?.stringValue { s["latestBuild"] = v }
            if let st = attrs["processingState"]?.stringValue { s["latestState"] = st }
        }
        return s
    }

    private static func reviewsSummary(_ root: JSONValue) -> [String: String] {
        var s: [String: String] = [:]
        // `reviews ratings` may be a single object or a JSON:API record.
        let candidate = items(root).first ?? root
        let attrs = candidate["attributes"] ?? candidate
        if let avg = attrs["averageRating"]?.stringValue { s["averageRating"] = avg }
        if let count = attrs["ratingCount"]?.stringValue { s["ratingCount"] = count }
        return s
    }

    private static func collectionSummary(_ root: JSONValue) -> [String: String] {
        ["count": String(items(root).count)]
    }

    /// Headline values for a weekly analytics insights payload: the reported week range,
    /// the source name, and how many metrics actually carry a value vs. are unavailable
    /// (so the consumer can hint at API-key analytics restrictions at a glance).
    private static func analyticsSummary(_ root: JSONValue) -> [String: String] {
        var s: [String: String] = [:]
        if let start = root["week"]?["start"]?.stringValue { s["weekStart"] = start }
        if let end = root["week"]?["end"]?.stringValue { s["weekEnd"] = end }
        if let source = root["source"]?["name"]?.stringValue { s["source"] = source }
        if let metrics = root["metrics"]?.arrayValue {
            let available = metrics.filter { $0["value"] != nil }.count
            s["metrics"] = String(metrics.count)
            s["available"] = String(available)
        }
        return s
    }

    /// Returns the primary array of records from either a bare array or a `{ data: [...] }`
    /// JSON:API envelope.
    private static func items(_ root: JSONValue) -> [JSONValue] {
        if let data = root["data"]?.arrayValue { return data }
        if let arr = root.arrayValue { return arr }
        return []
    }
}

// MARK: - JSONValue navigation helpers

private extension JSONValue {
    var objectValue: [String: JSONValue]? {
        if case .object(let o) = self { return o }
        return nil
    }
    var arrayValue: [JSONValue]? {
        if case .array(let a) = self { return a }
        return nil
    }
    /// Scalar string representation for strings, numbers and bools; nil otherwise.
    var stringValue: String? {
        switch self {
        case .string(let s): return s
        case .number(let d):
            if d.truncatingRemainder(dividingBy: 1) == 0 && abs(d) < 1e15 { return String(Int(d)) }
            return String(d)
        case .bool(let b): return b ? "true" : "false"
        default: return nil
        }
    }
    subscript(_ key: String) -> JSONValue? { objectValue?[key] }
}
