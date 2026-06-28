import SwiftUI

// MARK: - Structured (pretty) output rendering

/// A flattened field for a single record card.
public struct OutputField: Identifiable {
    public let id = UUID()
    public let label: String
    public let value: String
    public let isMoney: Bool

    public init(label: String, value: String, isMoney: Bool) {
        self.label = label
        self.value = value
        self.isMoney = isMoney
    }
}

/// A single record (one object) extracted from JSON output.
public struct OutputRecord: Identifiable {
    public let id = UUID()
    public let title: String?
    public let subtitle: String?
    public let badge: String?
    public let fields: [OutputField]

    public init(title: String?, subtitle: String?, badge: String?, fields: [OutputField]) {
        self.title = title
        self.subtitle = subtitle
        self.badge = badge
        self.fields = fields
    }
}

/// Parses `asc` JSON output into renderable records. Designed to be schema-agnostic:
/// it finds the main array of objects (e.g. `{ "subscriptions": [...] }`) and flattens
/// each object into labeled fields, collapsing `{amount,currency}` money objects.
public struct ParsedOutput {
    public let records: [OutputRecord]
    public let collection: String?
    public let preferPretty: Bool

    public init(records: [OutputRecord], collection: String?, preferPretty: Bool) {
        self.records = records
        self.collection = collection
        self.preferPretty = preferPretty
    }

    public static func parse(_ text: String) -> ParsedOutput? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("{") || trimmed.hasPrefix("[") else { return nil }
        guard let data = trimmed.data(using: .utf8),
              let root = try? JSONDecoder().decode(JSONValue.self, from: data),
              let (arr, collection) = collection(from: root) else { return nil }
        let records = arr.compactMap { record(from: $0) }
        guard !records.isEmpty else { return nil }
        let hasMoney = records.contains { $0.fields.contains { $0.isMoney } }
        let prefer = collection != nil || records.count > 1 || hasMoney
        return ParsedOutput(records: records, collection: collection, preferPretty: prefer)
    }

    private static func isObject(_ v: JSONValue) -> Bool { if case .object = v { return true }; return false }

    /// Keys that, when present as an array of objects, are the primary collection regardless
    /// of size — e.g. JSON:API `data` should win over the often-larger `included`.
    private static let collectionPriorityKeys = ["data", "items", "results", "records"]

    private static func collection(from v: JSONValue) -> ([JSONValue], String?)? {
        switch v {
        case .array(let a):
            return a.contains(where: isObject) ? (a, nil) : nil
        case .object(let o):
            for key in collectionPriorityKeys {
                if case .array(let a)? = o[key], a.contains(where: isObject) { return (a, key) }
            }
            var best: (String, [JSONValue])?
            for (k, val) in o {
                if case .array(let a) = val, a.contains(where: isObject) {
                    if best == nil || a.count > best!.1.count { best = (k, a) }
                }
            }
            if let best { return (best.1, best.0) }
            return ([v], nil)   // single object becomes one record
        default:
            return nil
        }
    }

    /// JSON:API wrapper keys that are structural noise rather than displayable data.
    private static let noiseKeys: Set<String> = ["relationships", "links", "meta", "attributes"]

    private static func record(from v: JSONValue) -> OutputRecord? {
        guard case .object(let raw) = v else { return nil }
        // Flatten a JSON:API `{ id, type, attributes: {…} }` envelope so the real fields
        // (name, state, price, …) render as top-level rows instead of a single "{…}".
        var o = raw
        if case .object(let attrs)? = raw["attributes"] {
            for (k, val) in attrs where o[k] == nil { o[k] = val }
        }
        for key in noiseKeys { o.removeValue(forKey: key) }
        func firstString(_ keys: [String]) -> (String, String)? {
            for k in keys { if let val = o[k], let s = scalar(val), !s.isEmpty { return (k, s) } }
            return nil
        }
        let titlePair = firstString(["name", "title", "displayName", "label"])
        let subPair = firstString(["productId", "sku", "bundleId", "identifier", "email"])
        let badgePair = firstString(["state", "status"])
        var used = Set([titlePair?.0, subPair?.0, badgePair?.0].compactMap { $0 })
        var title = titlePair?.1
        if title == nil, let idv = o["id"], let s = scalar(idv) { title = s; used.insert("id") }

        let priority = ["id", "type", "subscriptionPeriod", "period", "groupName",
                        "currentPrice", "price", "proceeds", "proceedsYear2",
                        "amount", "currency", "territory", "releaseDate", "date"]
        let keys = o.keys.filter { !used.contains($0) }.sorted { a, b in
            let pa = priority.firstIndex(of: a) ?? Int.max
            let pb = priority.firstIndex(of: b) ?? Int.max
            return pa != pb ? pa < pb : a < b
        }
        let fields = keys.map { k in
            OutputField(label: humanize(k), value: display(o[k]!), isMoney: money(o[k]!) != nil)
        }
        return OutputRecord(title: title, subtitle: subPair?.1, badge: badgePair?.1, fields: fields)
    }

    // MARK: value helpers

    static func scalar(_ v: JSONValue) -> String? {
        switch v {
        case .string(let s): return s
        case .number(let d): return number(d)
        case .bool(let b): return b ? "true" : "false"
        default: return nil
        }
    }
    static func number(_ d: Double) -> String {
        if d.truncatingRemainder(dividingBy: 1) == 0 && abs(d) < 1e15 { return String(Int(d)) }
        return String(d)
    }
    static func money(_ v: JSONValue) -> String? {
        guard case .object(let o) = v, let a = o["amount"], let c = o["currency"],
              let amount = scalar(a), let currency = scalar(c) else { return nil }
        return "\(amount) \(currency)"
    }
    static func display(_ v: JSONValue) -> String {
        if let m = money(v) { return m }
        switch v {
        case .string(let s): return prettyToken(s)
        case .number(let d): return number(d)
        case .bool(let b): return b ? "Yes" : "No"
        case .null: return "—"
        case .array(let a):
            let scalars = a.compactMap { scalar($0) }
            return scalars.count == a.count ? scalars.joined(separator: ", ") : "\(a.count) items"
        case .object(let o):
            let parts = o.compactMap { k, val in scalar(val).map { "\(humanize(k)): \($0)" } }
            return parts.isEmpty ? "{…}" : parts.joined(separator: ", ")
        }
    }
    /// Turns ENUM_LIKE_TOKENS into "Enum Like Tokens" but leaves currencies/ids alone.
    static func prettyToken(_ s: String) -> String {
        guard s.contains("_"), s == s.uppercased() else { return s }
        return s.split(separator: "_").map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }.joined(separator: " ")
    }
    static func humanize(_ key: String) -> String {
        var out = ""
        for ch in key {
            if ch == "_" { out += " " }
            else if ch.isUppercase { out += " " + String(ch) }
            else { out += String(ch) }
        }
        return out.split(separator: " ").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    }
}

/// Renders command output as nicely-formatted cards when it's JSON, with a
/// Formatted/Raw toggle. Falls back to a plain monospaced panel otherwise.
public struct OutputView: View {
    @EnvironmentObject var loc: LocalizationManager
    let text: String
    var maxHeight: CGFloat = 420

    // Parsed only when `text` actually changes, so unrelated re-renders (e.g. typing in a
    // sibling text field) don't re-parse potentially large JSON on every keystroke.
    @State private var parsed: ParsedOutput?
    @State private var parsedText: String?
    @State private var mode: Int = 1   // 0 = formatted, 1 = raw

    public init(text: String, maxHeight: CGFloat = 420) {
        self.text = text
        self.maxHeight = maxHeight
    }

    public var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label(loc(.output), systemImage: "doc.plaintext")
                    Spacer()
                    if let parsed {
                        if let count = countText(parsed) {
                            Text(count).font(.caption).foregroundStyle(.secondary)
                        }
                        Picker("", selection: $mode) {
                            Text(loc(.outFormatted)).tag(0)
                            Text(loc(.outRaw)).tag(1)
                        }
                        .pickerStyle(.segmented).labelsHidden().frame(width: 170)
                    }
                }
                if let parsed, mode == 0 {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(parsed.records) { OutputRecordCard(record: $0) }
                        }
                        .padding(.vertical, 2)
                    }
                    .frame(maxHeight: maxHeight)
                } else {
                    ScrollView {
                        Text(text.isEmpty ? "—" : text)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: maxHeight)
                }
            }
            .padding(6)
        }
        .task(id: text) {
            guard parsedText != text else { return }
            let result = ParsedOutput.parse(text)
            parsed = result
            parsedText = text
            mode = (result?.preferPretty ?? false) ? 0 : 1
        }
    }

    private func countText(_ p: ParsedOutput) -> String? {
        guard p.collection != nil || p.records.count > 1 else { return nil }
        return loc(.outCountFmt, p.records.count)
    }
}

private struct OutputRecordCard: View {
    let record: OutputRecord
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if let title = record.title {
                    Text(title).font(.headline).textSelection(.enabled)
                }
                if let badge = record.badge { OutputStateBadge(text: badge) }
                Spacer()
            }
            if let subtitle = record.subtitle {
                Text(subtitle).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
            }
            if !record.fields.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), alignment: .topLeading)],
                          alignment: .leading, spacing: 8) {
                    ForEach(record.fields) { f in
                        VStack(alignment: .leading, spacing: 1) {
                            Text(f.label).font(.caption2).foregroundStyle(.secondary)
                            Text(f.value)
                                .font(f.isMoney ? .callout.weight(.semibold) : .callout)
                                .foregroundStyle(f.isMoney ? Color.green : Color.primary)
                                .textSelection(.enabled)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.secondary.opacity(0.12)))
    }
}

private struct OutputStateBadge: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(color.opacity(0.16), in: Capsule())
            .foregroundStyle(color)
    }
    private var color: Color {
        let t = text.uppercased()
        let green = ["APPROVED", "ACTIVE", "READY", "ENABLED", "COMPLETED", "LIVE", "ACCEPTED"]
        let amber = ["PENDING", "REVIEW", "WAITING", "PROCESSING", "PREPARE", "DRAFT", "PROPOSED"]
        let red = ["REJECTED", "REMOVED", "INVALID", "FAILED", "EXPIRED", "DISABLED", "CANCEL"]
        if green.contains(where: { t.contains($0) }) { return .green }
        if amber.contains(where: { t.contains($0) }) { return .orange }
        if red.contains(where: { t.contains($0) }) { return .red }
        return .gray
    }
}
