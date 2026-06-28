import Foundation

// MARK: - Flexible JSON parsing

/// `asc insights` / `analytics compare` emit deterministic but differently-shaped JSON.
/// We decode into a generic value tree and extract numeric metrics defensively, so the
/// dashboard never crashes on schema variance and simply shows "not enough data" when a
/// metric is absent — mirroring App Store Connect's own behavior.
public indirect enum JSONValue: Decodable {
    case string(String), number(Double), bool(Bool)
    case object([String: JSONValue]), array([JSONValue]), null

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let b = try? c.decode(Bool.self) { self = .bool(b); return }
        if let d = try? c.decode(Double.self) { self = .number(d); return }
        if let s = try? c.decode(String.self) { self = .string(s); return }
        if let o = try? c.decode([String: JSONValue].self) { self = .object(o); return }
        if let a = try? c.decode([JSONValue].self) { self = .array(a); return }
        self = .null
    }
}

public struct AnalyticsMetric {
    public let label: String
    public let value: Double?       // nil when the metric is unavailable
    public let delta: Double?       // percent change, if discoverable
    public var unit: String? = nil
    public var status: String? = nil
    public var reason: String? = nil

    public init(label: String, value: Double?, delta: Double?,
                unit: String? = nil, status: String? = nil, reason: String? = nil) {
        self.label = label
        self.value = value
        self.delta = delta
        self.unit = unit
        self.status = status
        self.reason = reason
    }

    public var isAvailable: Bool { value != nil }
    public var isPercentUnit: Bool { (unit ?? "").lowercased().contains("percent") }
}

public enum MetricExtractor {
    public static func numeric(_ v: JSONValue?) -> Double? {
        switch v {
        case .number(let d): return d
        case .string(let s): return Double(s.replacingOccurrences(of: ",", with: ""))
        default: return nil
        }
    }
    public static func string(_ v: JSONValue?) -> String? {
        if case .string(let s)? = v { return s }
        return nil
    }

    public static func extract(_ output: String) -> [AnalyticsMetric] {
        guard let data = output.data(using: .utf8),
              let root = try? JSONDecoder().decode(JSONValue.self, from: data) else { return [] }
        var out: [AnalyticsMetric] = []
        walk(root, inherited: nil, into: &out)
        // De-duplicate by normalized label, keeping the first occurrence.
        var seen = Set<String>()
        return out.filter { seen.insert(normalize($0.label)).inserted }
    }

    private static let valueKeys = ["value", "current", "total", "thisweek", "this_week", "count", "amount", "sum", "latest"]
    private static let prevKeys  = ["previous", "lastweek", "last_week", "prior", "baseline"]
    private static let pctKeys   = ["percentchange", "changepercent", "change_percent", "deltapercent", "pctchange", "percent_change"]

    private static func walk(_ v: JSONValue, inherited: String?, into out: inout [AnalyticsMetric]) {
        switch v {
        case .object(let o):
            let lower = Dictionary(uniqueKeysWithValues: o.map { ($0.key.lowercased(), $0.value) })
            let name = string(lower["name"]) ?? string(lower["label"]) ?? string(lower["metric"])
                ?? string(lower["title"]) ?? string(lower["key"])
            let label = name ?? inherited
            var val: Double?
            for k in valueKeys where val == nil { val = numeric(lower[k]) }
            var delta: Double?
            for k in pctKeys where delta == nil { delta = numeric(lower[k]) }
            if delta == nil {
                var prev: Double?
                for k in prevKeys where prev == nil { prev = numeric(lower[k]) }
                if let cur = val, let prev, prev != 0 { delta = (cur - prev) / abs(prev) * 100 }
            }
            let status = string(lower["status"])
            let reason = string(lower["reason"])
            // Treat an explicit named metric as one entry, even when its value is unavailable,
            // so we can surface the status/reason (e.g. "not permitted for the current API key").
            let isNamedMetric = name != nil && (val != nil || status != nil || reason != nil || lower["unit"] != nil)
            if isNamedMetric, let label {
                out.append(AnalyticsMetric(label: label, value: val, delta: delta,
                                           unit: string(lower["unit"]), status: status, reason: reason))
            } else {
                if let label, let val {
                    out.append(AnalyticsMetric(label: label, value: val, delta: delta))
                }
                // Flat numeric children become metrics keyed by their field name; recurse into the rest.
                for (k, child) in o {
                    if case .number(let d) = child {
                        out.append(AnalyticsMetric(label: k, value: d, delta: nil))
                    } else {
                        walk(child, inherited: k, into: &out)
                    }
                }
            }
        case .array(let a):
            for el in a { walk(el, inherited: inherited, into: &out) }
        default:
            break
        }
    }

    public static func normalize(_ s: String) -> String {
        s.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }.map(String.init).joined()
    }
}

// MARK: - Metric catalog

public struct MetricSpec {
    public let key: LocKey
    public let synonyms: [String]
    public var isPercent: Bool = false
    public let group: Int   // 0 acquisition, 1 revenue, 2 subscriptions, 3 usage

    public init(key: LocKey, synonyms: [String], isPercent: Bool = false, group: Int) {
        self.key = key
        self.synonyms = synonyms
        self.isPercent = isPercent
        self.group = group
    }
}

public enum AnalyticsCatalog {
    public static let specs: [MetricSpec] = [
        // Acquisition
        .init(key: .anFirstDownloads, synonyms: ["firsttimedownload", "firstdownload", "newdownload", "installs"], group: 0),
        .init(key: .anRedownloads, synonyms: ["redownload", "repeatdownload"], group: 0),
        .init(key: .anConversion, synonyms: ["conversionrate", "conversion"], isPercent: true, group: 0),
        .init(key: .anImpressions, synonyms: ["impression"], group: 0),
        .init(key: .anPageViews, synonyms: ["productpageview", "pageview", "productpage"], group: 0),
        .init(key: .anUpdates, synonyms: ["update"], group: 0),
        // Revenue
        .init(key: .anProceeds, synonyms: ["proceeds", "developerproceeds", "erlose", "revenue"], group: 1),
        .init(key: .anPayingUsers, synonyms: ["payinguser", "payingaccount", "payer"], group: 1),
        .init(key: .anIap, synonyms: ["inapppurchase", "iap"], group: 1),
        // Subscriptions
        .init(key: .anActiveSubs, synonyms: ["activesubscription", "activesub"], group: 2),
        .init(key: .anPaidSubs, synonyms: ["paidsubscription", "paidsub"], group: 2),
        .init(key: .anMrr, synonyms: ["mrr", "monthlyrecurringrevenue", "recurringrevenue"], group: 2),
        // Usage
        .init(key: .anRetention, synonyms: ["retention"], isPercent: true, group: 3),
        .init(key: .anCrashes, synonyms: ["crash"], group: 3),
    ]

    /// Resolve catalog specs against extracted metrics.
    public static func resolve(_ metrics: [AnalyticsMetric]) -> [LocKey: AnalyticsMetric] {
        var result: [LocKey: AnalyticsMetric] = [:]
        for spec in specs {
            let matches = metrics.filter { m in
                let n = MetricExtractor.normalize(m.label)
                return spec.synonyms.contains { n.contains($0) }
            }
            // Prefer a metric that actually has a value over an "unavailable" one.
            if let match = matches.first(where: { $0.value != nil }) ?? matches.first {
                result[spec.key] = match
            }
        }
        return result
    }
}
