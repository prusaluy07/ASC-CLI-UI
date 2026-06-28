import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Scrollable monospaced output panel used by the action-oriented feature screens.
struct OutputPanel: View {
    let title: String
    let text: String
    var maxHeight: CGFloat = 320

    var body: some View {
        GroupBox {
            ScrollView {
                Text(text.isEmpty ? "—" : text)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: maxHeight)
            .padding(6)
        } label: {
            Label(title, systemImage: "doc.plaintext")
        }
    }
}

// MARK: - Structured (pretty) output rendering

/// A flattened field for a single record card.
struct OutputField: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    let isMoney: Bool
}

/// A single record (one object) extracted from JSON output.
struct OutputRecord: Identifiable {
    let id = UUID()
    let title: String?
    let subtitle: String?
    let badge: String?
    let fields: [OutputField]
}

/// Parses `asc` JSON output into renderable records. Designed to be schema-agnostic:
/// it finds the main array of objects (e.g. `{ "subscriptions": [...] }`) and flattens
/// each object into labeled fields, collapsing `{amount,currency}` money objects.
struct ParsedOutput {
    let records: [OutputRecord]
    let collection: String?
    let preferPretty: Bool

    static func parse(_ text: String) -> ParsedOutput? {
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
struct OutputView: View {
    @EnvironmentObject var loc: LocalizationManager
    let text: String
    var maxHeight: CGFloat = 420

    // Parsed only when `text` actually changes, so unrelated re-renders (e.g. typing in a
    // sibling text field) don't re-parse potentially large JSON on every keystroke.
    @State private var parsed: ParsedOutput?
    @State private var parsedText: String?
    @State private var mode: Int = 1   // 0 = formatted, 1 = raw

    var body: some View {
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

/// Standard scaffold for action-oriented, optionally app-scoped feature screens.
/// Renders a header, an optional "no app selected" placeholder, an intro line, the caller's
/// controls, and a shared output panel. Owns the `run`/`isRunning`/`output` state and passes a
/// `run` closure plus the current `isRunning` flag down to the content builder.
struct CommandScreen<Content: View>: View {
    @EnvironmentObject var loc: LocalizationManager

    let title: String
    var subtitle: String? = nil
    var intro: String? = nil
    var requireApp: Bool = false
    var hasApp: Bool = true
    var maxContentWidth: CGFloat = 860
    @ViewBuilder var content: (_ run: @escaping (@escaping () async -> CommandResult) -> Void, _ isRunning: Bool) -> Content

    @State private var output: String?
    @State private var isRunning = false

    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(title: title, subtitle: subtitle) { EmptyView() }
            Divider()

            if requireApp && !hasApp {
                ContentUnavailableView(loc(.noAppSelectedTitle), systemImage: "questionmark.circle",
                                       description: Text(loc(.selectAppFromApps)))
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let intro { Text(intro).font(.callout).foregroundStyle(.secondary) }
                        content(runOperation, isRunning)
                        if let output { OutputView(text: output) }
                    }
                    .padding(20)
                    .frame(maxWidth: maxContentWidth, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func runOperation(_ operation: @escaping () async -> CommandResult) {
        isRunning = true
        output = nil
        Task {
            let result = await operation()
            output = result.succeeded ? (result.output.isEmpty ? "✓" : result.output) : result.errorMessage
            isRunning = false
        }
    }
}

/// A self-contained, expanded-by-default section that owns and renders its own command
/// output. Stack several of these on a page so related actions (e.g. Groups / Subscriptions /
/// Prices) are all visible at once instead of hidden behind a segmented tab control.
/// Pass `autoRun` to load the section's data automatically when it first appears.
struct CommandSection<Content: View>: View {
    @EnvironmentObject var loc: LocalizationManager
    let title: String
    var systemImage: String = "list.bullet"
    var autoRun: (() async -> CommandResult)? = nil
    /// When this changes (e.g. the selected app id), `autoRun` runs again so the section
    /// never shows another app's data. Sections without auto-load can leave it empty.
    var autoRunToken: String = ""
    @ViewBuilder var content: (_ run: @escaping (@escaping () async -> CommandResult) -> Void, _ isRunning: Bool) -> Content

    @State private var expanded = true
    @State private var output: String?
    @State private var isRunning = false
    @State private var loadedToken: String?

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 10) {
                content(runOperation, isRunning)
                if isRunning && output == nil {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("…").foregroundStyle(.secondary)
                    }
                }
                if let output { OutputView(text: output) }
            }
            .padding(.top, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label(title, systemImage: systemImage).font(.headline)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.secondary.opacity(0.10)))
        .task(id: autoRunToken) {
            if let autoRun, loadedToken != autoRunToken {
                loadedToken = autoRunToken
                output = nil
                runOperation(autoRun)
            }
        }
    }

    private func runOperation(_ operation: @escaping () async -> CommandResult) {
        isRunning = true
        Task {
            let result = await operation()
            output = result.succeeded ? (result.output.isEmpty ? "✓" : result.output) : result.errorMessage
            isRunning = false
        }
    }
}

/// A simple wrapping (left-to-right, top-to-bottom) layout so rows of buttons
/// reflow onto multiple lines instead of clipping on narrow detail widths.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            sub.place(at: CGPoint(x: bounds.minX + x, y: bounds.minY + y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// Convenience wrapper that lays out a set of buttons/controls in a wrapping row.
struct FlowButtons<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        FlowLayout(spacing: 8) { content() }
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A labeled read-only path row with a "Choose…" button.
struct PathPickerRow: View {
    let label: String
    @Binding var path: String
    var chooseTitle: String
    var pick: () -> String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            HStack {
                Text(path.isEmpty ? "—" : path)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(chooseTitle) {
                    if let picked = pick() { path = picked }
                }
            }
        }
    }
}

enum FilePanel {
    @MainActor
    static func pickFile(extensions: [String]) -> String? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        let types = extensions.compactMap { UTType(filenameExtension: $0) }
        if !types.isEmpty {
            panel.allowedContentTypes = types
            panel.allowsOtherFileTypes = true
        }
        return panel.runModal() == .OK ? panel.url?.path : nil
    }

    @MainActor
    static func pickDirectory(start: String? = nil) -> String? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        if let start { panel.directoryURL = URL(fileURLWithPath: start) }
        return panel.runModal() == .OK ? panel.url?.path : nil
    }
}

extension ASCService.PrefetchSection {
    var locKey: LocKey {
        switch self {
        case .versions:   return .secVersions
        case .builds:     return .secBuilds
        case .testflight: return .secTestFlight
        case .release:    return .secRelease
        }
    }
}

/// Persists the prefetch preference (stored as a comma-joined raw string in AppStorage).
enum PrefetchSettings {
    static let enabledKey = "asc.prefetchEnabled"
    static let sectionsKey = "asc.prefetchSections"
    static let defaultRaw = "versions,builds,testflight,release"

    static func decode(_ raw: String) -> Set<ASCService.PrefetchSection> {
        Set(raw.split(separator: ",").compactMap { ASCService.PrefetchSection(rawValue: String($0)) })
    }

    static func encode(_ set: Set<ASCService.PrefetchSection>) -> String {
        ASCService.PrefetchSection.allCases.filter { set.contains($0) }.map(\.rawValue).joined(separator: ",")
    }
}

/// App metadata shown in Settings → About. `creator` is a plain constant you can edit.
enum AppInfo {
    static var version: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0" }
    static var build: String { Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1" }
    static let creator = "Andre Ludwig"
    static let license = "MIT License"
    static let appStoreConnectApps = URL(string: "https://appstoreconnect.apple.com/apps")!
    static let developerIdentifiers = URL(string: "https://developer.apple.com/account/resources/identifiers/list")!
}

/// Common App Store screenshot/preview device types for the media uploader pickers.
enum DeviceType {
    static let all = [
        "IPHONE_67", "IPHONE_69", "IPHONE_65", "IPHONE_61", "IPHONE_58",
        "IPAD_PRO_3GEN_129", "IPAD_PRO_129", "IPAD_109",
        "MAC", "APPLE_TV", "APPLE_VISION_PRO"
    ]
}
