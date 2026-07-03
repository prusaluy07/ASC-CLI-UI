import Foundation

// MARK: - Analytics report file parsing (App Analytics via the API)

/// A parsed App Store Connect **Analytics report** file — the tabular data produced by
/// `asc analytics download` (after decompressing the gzip to CSV/TSV).
///
/// Apple delivers these reports as tab-separated values with a single header row; we also
/// tolerate comma-separated files. Parsing is purely structural and never throws: an empty
/// or malformed file yields an empty table, mirroring the "not enough data" behavior used
/// elsewhere in the dashboard.
public struct AnalyticsReportTable: Sendable, Equatable {
    public let columns: [String]
    public let rows: [[String]]

    public init(columns: [String], rows: [[String]]) {
        self.columns = columns
        self.rows = rows
    }

    /// Parses a raw report. Auto-detects tab vs. comma delimiter, tolerates CRLF and blank
    /// lines, and trims surrounding whitespace from every cell.
    public init(text: String) {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        guard let header = lines.first else {
            self.columns = []
            self.rows = []
            return
        }
        let delimiter: Character = header.contains("\t") ? "\t" : ","
        func cells(_ line: String) -> [String] {
            line.split(separator: delimiter, omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
        }
        self.columns = cells(header)
        self.rows = lines.dropFirst().map(cells)
    }

    public var isEmpty: Bool { columns.isEmpty || rows.isEmpty }

    /// First column index whose normalized header exactly equals, then contains, a candidate
    /// (candidates are checked in priority order).
    public func columnIndex(matching candidates: [String]) -> Int? {
        let normalized = columns.map { Self.normalize($0) }
        for candidate in candidates {
            if let i = normalized.firstIndex(of: candidate) { return i }
        }
        for candidate in candidates {
            if let i = normalized.firstIndex(where: { $0.contains(candidate) }) { return i }
        }
        return nil
    }

    static func normalize(_ s: String) -> String {
        s.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }.map(String.init).joined()
    }

    static func number(_ s: String) -> Double? {
        let cleaned = s.replacingOccurrences(of: ",", with: "")
        return cleaned.isEmpty ? nil : Double(cleaned)
    }
}

/// Turns a parsed ``AnalyticsReportTable`` into a list of ``AnalyticsMetric`` values that can
/// be fed straight into ``AnalyticsCatalog/resolve(_:)`` — so the same metric cards used for
/// `insights weekly` light up from a downloaded report.
///
/// Two report shapes are handled:
/// 1. **Event/measure shape** (the common one): a dimension column such as `Event` or
///    `Download Type` plus a numeric `Counts` column. We sum the counts grouped by the
///    dimension value, yielding one metric per event (e.g. `Impression`, `Page View`,
///    `First Time Download`).
/// 2. **Wide shape**: no dimension column, but one or more numeric columns (e.g.
///    `Impressions`, `Product Page Views`). We sum each numeric column into its own metric.
public enum AnalyticsReportSummarizer {
    static let valueCandidates = [
        "counts", "count", "quantity", "units", "value", "totaldownloads",
        "sales", "proceeds", "sessions", "activedevices", "crashes",
    ]
    static let dimensionCandidates = [
        "event", "downloadtype", "eventtype", "type", "metric", "measure", "name",
    ]

    public static func metrics(from table: AnalyticsReportTable) -> [AnalyticsMetric] {
        guard !table.isEmpty else { return [] }

        if let valueIdx = table.columnIndex(matching: valueCandidates),
           let dimIdx = table.columnIndex(matching: dimensionCandidates),
           dimIdx != valueIdx {
            var sums: [String: Double] = [:]
            var order: [String] = []
            for row in table.rows {
                guard dimIdx < row.count, valueIdx < row.count else { continue }
                let key = row[dimIdx]
                guard !key.isEmpty, let v = AnalyticsReportTable.number(row[valueIdx]) else { continue }
                if sums[key] == nil { order.append(key) }
                sums[key, default: 0] += v
            }
            return order.compactMap { key in
                sums[key].map { AnalyticsMetric(label: key, value: $0, delta: nil) }
            }
        }

        // Wide shape: sum every column that is numeric in the majority of rows.
        var metrics: [AnalyticsMetric] = []
        for (i, column) in table.columns.enumerated() {
            var total = 0.0
            var numericRows = 0
            for row in table.rows where i < row.count {
                if let v = AnalyticsReportTable.number(row[i]) {
                    total += v
                    numericRows += 1
                }
            }
            if numericRows > 0, numericRows * 2 >= table.rows.count {
                metrics.append(AnalyticsMetric(label: column, value: total, delta: nil))
            }
        }
        return metrics
    }
}

// MARK: - Locating report instances from `asc analytics view` JSON

/// A report instance discovered in an `asc analytics view --include-segments` payload, with
/// just enough to drive `asc analytics download` (instance id, optional segment id) and to
/// label it in the UI.
public struct AnalyticsInstanceRef: Sendable, Equatable, Identifiable {
    public let instanceId: String
    public let reportName: String?
    public let category: String?
    public let granularity: String?
    public let processingDate: String?
    public let segmentIds: [String]

    public var id: String { instanceId }

    public init(instanceId: String,
                reportName: String? = nil,
                category: String? = nil,
                granularity: String? = nil,
                processingDate: String? = nil,
                segmentIds: [String] = []) {
        self.instanceId = instanceId
        self.reportName = reportName
        self.category = category
        self.granularity = granularity
        self.processingDate = processingDate
        self.segmentIds = segmentIds
    }
}

/// Best-effort, defensive extraction of report instances + segments from the JSON returned by
/// `asc analytics view`. The exact envelope can vary (JSON:API `data`/`included`, or a
/// flattened CLI shape), so we walk the whole tree and classify any object by its `type`
/// and/or telltale attributes rather than assuming a fixed layout.
public enum AnalyticsReportLocator {
    /// Parses `asc analytics view` output and returns the discovered instances, newest first
    /// (by `processingDate` when present).
    public static func instances(fromViewJSON json: String) -> [AnalyticsInstanceRef] {
        guard let data = json.data(using: .utf8),
              let root = try? JSONDecoder().decode(JSONValue.self, from: data) else { return [] }

        var resources: [JSONNode] = []
        collect(root, into: &resources)

        // Index report names/categories by id so instances can borrow a human label.
        var reportInfo: [String: (name: String?, category: String?)] = [:]
        for node in resources where node.kind == .report {
            reportInfo[node.id] = (node.name, node.category)
        }

        let instances = resources.filter { $0.kind == .instance }
        let refs: [AnalyticsInstanceRef] = instances.map { node in
            let parent = node.parentReportId.flatMap { reportInfo[$0] }
            return AnalyticsInstanceRef(
                instanceId: node.id,
                reportName: node.name ?? parent?.name,
                category: node.category ?? parent?.category,
                granularity: node.granularity,
                processingDate: node.processingDate,
                segmentIds: node.segmentIds
            )
        }
        return refs.sorted { ($0.processingDate ?? "") > ($1.processingDate ?? "") }
    }

    // MARK: Internal classification

    enum Kind { case report, instance, segment, other }

    struct JSONNode {
        var id: String
        var kind: Kind
        var name: String?
        var category: String?
        var granularity: String?
        var processingDate: String?
        var parentReportId: String?
        var segmentIds: [String]
    }

    /// Recursively gathers every object that carries an `id`, classifying it by `type` and a
    /// few well-known attribute names. Segments referenced inline are attached to their
    /// instance when discoverable.
    private static func collect(_ value: JSONValue, into out: inout [JSONNode]) {
        switch value {
        case .object(let object):
            if let id = object["id"]?.string {
                let type = (object["type"]?.string ?? "").lowercased()
                let attrs = object["attributes"]?.object ?? object
                let kind: Kind
                if type.contains("segment") {
                    kind = .segment
                } else if type.contains("instance") || attrs["processingDate"] != nil || attrs["granularity"] != nil {
                    kind = .instance
                } else if type.contains("report") && !type.contains("request") {
                    kind = .report
                } else {
                    kind = .other
                }
                if kind != .other {
                    out.append(JSONNode(
                        id: id,
                        kind: kind,
                        name: attrs["name"]?.string,
                        category: attrs["category"]?.string,
                        granularity: attrs["granularity"]?.string,
                        processingDate: attrs["processingDate"]?.string,
                        parentReportId: nil,
                        segmentIds: inlineSegmentIds(object)
                    ))
                }
            }
            for (_, child) in object { collect(child, into: &out) }
        case .array(let array):
            for child in array { collect(child, into: &out) }
        default:
            break
        }
    }

    /// Collects segment ids nested directly under an instance object (when the CLI inlines
    /// `segments` rather than using a separate `included` array).
    private static func inlineSegmentIds(_ object: [String: JSONValue]) -> [String] {
        guard let segments = object["segments"]?.array else { return [] }
        return segments.compactMap { seg in
            if case .object(let o) = seg { return o["id"]?.string }
            return nil
        }
    }
}

// MARK: - Narrowing instances to a requested week

public extension AnalyticsReportLocator {
    /// Instances narrowed to a requested week, or the newest available ones as a fallback.
    struct WeekSelection: Sendable, Equatable {
        public let instances: [AnalyticsInstanceRef]
        /// True when the requested week has no instances yet and `instances` carries the
        /// newest available ones instead (Apple publishes daily instances ~2–3 days behind).
        public let isFallback: Bool

        public init(instances: [AnalyticsInstanceRef], isFallback: Bool) {
            self.instances = instances
            self.isFallback = isFallback
        }
    }

    /// Filters `all` (as returned by `instances(fromViewJSON:)`, newest first) to instances
    /// whose `processingDate` lies within the 7-day week starting at `weekStart`
    /// (`yyyy-MM-dd`). When the week has no instances yet, the full list is returned as a
    /// fallback so callers can show the newest available data instead of nothing.
    static func select(_ all: [AnalyticsInstanceRef], weekStarting weekStart: String) -> WeekSelection {
        guard !all.isEmpty else { return WeekSelection(instances: [], isFallback: false) }
        guard let weekEnd = dayString(weekStart, addingDays: 6) else {
            // Unparseable week start: don't filter at all.
            return WeekSelection(instances: all, isFallback: false)
        }
        // `processingDate` is ISO "yyyy-MM-dd", so string comparison is chronological.
        let inWeek = all.filter { ref in
            guard let day = ref.processingDate else { return false }
            return day >= weekStart && day <= weekEnd
        }
        if inWeek.isEmpty { return WeekSelection(instances: all, isFallback: true) }
        return WeekSelection(instances: inWeek, isFallback: false)
    }

    private static func dayString(_ day: String, addingDays offset: Int) -> String? {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone(identifier: "UTC")
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = fmt.timeZone
        guard let date = fmt.date(from: day),
              let shifted = cal.date(byAdding: .day, value: offset, to: date) else { return nil }
        return fmt.string(from: shifted)
    }
}

// MARK: - Local JSONValue accessors

private extension JSONValue {
    var object: [String: JSONValue]? {
        if case .object(let o) = self { return o }
        return nil
    }
    var array: [JSONValue]? {
        if case .array(let a) = self { return a }
        return nil
    }
    var string: String? {
        switch self {
        case .string(let s): return s
        case .number(let d):
            if d.truncatingRemainder(dividingBy: 1) == 0 && abs(d) < 1e15 { return String(Int(d)) }
            return String(d)
        case .bool(let b): return b ? "true" : "false"
        default: return nil
        }
    }
    subscript(_ key: String) -> JSONValue? { object?[key] }
}
