import Foundation

// MARK: - Aggregated summaries

public struct AppMetricsSummary: Sendable, Equatable {
    public let firstDownloads: Int
    public let redownloads: Int
    public let updates: Int
    public let iapUnits: Int
    public let subscriptionUnits: Int
    public let proceeds: Double
    public let rowCount: Int

    public init(firstDownloads: Int = 0,
                redownloads: Int = 0,
                updates: Int = 0,
                iapUnits: Int = 0,
                subscriptionUnits: Int = 0,
                proceeds: Double = 0,
                rowCount: Int = 0) {
        self.firstDownloads = firstDownloads
        self.redownloads = redownloads
        self.updates = updates
        self.iapUnits = iapUnits
        self.subscriptionUnits = subscriptionUnits
        self.proceeds = proceeds
        self.rowCount = rowCount
    }

    public var totalDownloads: Int { firstDownloads + redownloads }

    public static func aggregate(_ rows: [SalesReportRow]) -> AppMetricsSummary {
        var firstDownloads = 0
        var redownloads = 0
        var updates = 0
        var iapUnits = 0
        var subscriptionUnits = 0
        var proceeds = 0.0
        for row in rows {
            if row.isFirstDownload { firstDownloads += row.units }
            else if row.isRedownload { redownloads += row.units }
            else if row.isUpdate { updates += row.units }
            else if row.isSubscription { subscriptionUnits += row.units }
            else if row.isInAppPurchase { iapUnits += row.units }
            proceeds += row.proceeds
        }
        return AppMetricsSummary(
            firstDownloads: firstDownloads,
            redownloads: redownloads,
            updates: updates,
            iapUnits: iapUnits,
            subscriptionUnits: subscriptionUnits,
            proceeds: proceeds,
            rowCount: rows.count
        )
    }
}

public struct MetricsTrendPoint: Sendable, Identifiable, Equatable {
    public var id: String { date }
    public let date: String
    public let downloads: Int
    public let proceeds: Double

    public init(date: String, downloads: Int, proceeds: Double) {
        self.date = date
        self.downloads = downloads
        self.proceeds = proceeds
    }
}

public struct PortfolioMetricsEntry: Sendable, Identifiable, Equatable {
    public var id: String { appId }
    public let appId: String
    public let appName: String
    public let downloads: Int
    public let proceeds: Double
    public let deltaDownloads: Double?
    public let deltaProceeds: Double?

    public init(appId: String,
                appName: String,
                downloads: Int,
                proceeds: Double,
                deltaDownloads: Double? = nil,
                deltaProceeds: Double? = nil) {
        self.appId = appId
        self.appName = appName
        self.downloads = downloads
        self.proceeds = proceeds
        self.deltaDownloads = deltaDownloads
        self.deltaProceeds = deltaProceeds
    }
}

// MARK: - App matching

public struct MetricsAppMatcher {
    /// Maps an ASC app to sales rows using SKU, then Apple Identifier learned from prior imports.
    public static func matches(app: ASCApp, row: SalesReportRow, appleIdsByAppId: [String: String]) -> Bool {
        if let sku = app.sku, !sku.isEmpty, sku == row.sku { return true }
        if let mapped = appleIdsByAppId[app.id], !mapped.isEmpty, mapped == row.appleIdentifier { return true }
        if !app.name.isEmpty, !row.title.isEmpty,
           app.name.caseInsensitiveCompare(row.title) == .orderedSame { return true }
        return false
    }

    public static func discoverAppleIdentifier(for app: ASCApp, in rows: [SalesReportRow]) -> String? {
        if let sku = app.sku, !sku.isEmpty,
           let match = rows.first(where: { $0.sku == sku && !$0.appleIdentifier.isEmpty }) {
            return match.appleIdentifier
        }
        if let match = rows.first(where: {
            !$0.appleIdentifier.isEmpty &&
            $0.title.caseInsensitiveCompare(app.name) == .orderedSame
        }) {
            return match.appleIdentifier
        }
        return nil
    }
}

// MARK: - Persistent store

private struct MetricsSnapshot: Codable {
    var records: [SalesReportRow]
    var importedFiles: [String: Date]
    var appleIdsByAppId: [String: String]
    var lastScan: Date?
}

/// Local time-series store built from imported Apple Sales Summary reports.
public final class MetricsStore: @unchecked Sendable {
    public static let defaultDirectoryName = "ASCManager"

    private let fileURL: URL
    private let queue = DispatchQueue(label: "ASCShared.MetricsStore", qos: .utility)
    private var snapshot: MetricsSnapshot

    public init(directory: URL? = nil) {
        let base = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent(Self.defaultDirectoryName, isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        fileURL = base.appendingPathComponent("metrics-store.json")
        snapshot = (try? Self.load(from: fileURL)) ?? MetricsSnapshot(records: [], importedFiles: [:], appleIdsByAppId: [:], lastScan: nil)
    }

    public var recordCount: Int { queue.sync { snapshot.records.count } }
    public var importedFileCount: Int { queue.sync { snapshot.importedFiles.count } }
    public var lastScan: Date? { queue.sync { snapshot.lastScan } }

    @discardableResult
    public func importFile(at path: String, apps: [ASCApp] = [], force: Bool = false) -> Int {
        queue.sync {
            let mod = (try? FileManager.default.attributesOfItem(atPath: path)[.modificationDate] as? Date) ?? .distantPast
            if !force, let seen = snapshot.importedFiles[path], seen >= mod { return 0 }
            guard let result = SalesReportParser.parseFile(at: path), !result.rows.isEmpty else { return 0 }

            mergeRows(result.rows)
            learnAppleIdentifiers(apps: apps, rows: result.rows)
            snapshot.importedFiles[path] = mod
            persist()
            return result.rows.count
        }
    }

    @discardableResult
    public func importText(_ text: String, sourcePath: String? = nil, apps: [ASCApp] = []) -> Int {
        queue.sync {
            let result = SalesReportParser.parse(text: text, sourcePath: sourcePath)
            guard !result.rows.isEmpty else { return 0 }
            mergeRows(result.rows)
            learnAppleIdentifiers(apps: apps, rows: result.rows)
            if let path = sourcePath {
                let mod = (try? FileManager.default.attributesOfItem(atPath: path)[.modificationDate] as? Date) ?? .now
                snapshot.importedFiles[path] = mod
            }
            persist()
            return result.rows.count
        }
    }

    public struct ScanResult: Sendable {
        public let filesScanned: Int
        public let rowsImported: Int

        public init(filesScanned: Int, rowsImported: Int) {
            self.filesScanned = filesScanned
            self.rowsImported = rowsImported
        }
    }

    @discardableResult
    public func scanDirectory(_ directory: String, apps: [ASCApp] = []) -> ScanResult {
        queue.sync {
            let fm = FileManager.default
            guard let entries = try? fm.contentsOfDirectory(atPath: directory) else {
                return ScanResult(filesScanned: 0, rowsImported: 0)
            }
            var scanned = 0
            var imported = 0
            for name in entries.sorted() {
                let lower = name.lowercased()
                guard lower.hasSuffix(".tsv") || lower.hasSuffix(".tsv.gz") else { continue }
                let path = (directory as NSString).appendingPathComponent(name)
                scanned += 1
                imported += importFileLocked(at: path, apps: apps, force: false)
            }
            snapshot.lastScan = .now
            persist()
            return ScanResult(filesScanned: scanned, rowsImported: imported)
        }
    }

    public func rows(for app: ASCApp, from start: String? = nil, to end: String? = nil) -> [SalesReportRow] {
        queue.sync {
            snapshot.records.filter { row in
                guard MetricsAppMatcher.matches(app: app, row: row, appleIdsByAppId: snapshot.appleIdsByAppId) else { return false }
                if let start, row.reportDate < start { return false }
                if let end, row.reportDate > end { return false }
                return true
            }
        }
    }

    public func summary(for app: ASCApp, from start: String, to end: String) -> AppMetricsSummary {
        AppMetricsSummary.aggregate(rows(for: app, from: start, to: end))
    }

    public func trend(for app: ASCApp, days: Int, endingOn endDate: Date = .now) -> [MetricsTrendPoint] {
        let cal = Calendar(identifier: .gregorian)
        let end = cal.startOfDay(for: endDate)
        guard let start = cal.date(byAdding: .day, value: -(days - 1), to: end) else { return [] }
        let fmt = Self.dateFormatter
        let startStr = fmt.string(from: start)
        let endStr = fmt.string(from: end)
        let appRows = rows(for: app, from: startStr, to: endStr)

        var byDate: [String: (downloads: Int, proceeds: Double)] = [:]
        for row in appRows {
            var bucket = byDate[row.reportDate] ?? (0, 0)
            if row.isFirstDownload || row.isRedownload { bucket.downloads += row.units }
            bucket.proceeds += row.proceeds
            byDate[row.reportDate] = bucket
        }

        var points: [MetricsTrendPoint] = []
        var cursor = start
        while cursor <= end {
            let key = fmt.string(from: cursor)
            let bucket = byDate[key] ?? (0, 0)
            points.append(MetricsTrendPoint(date: key, downloads: bucket.downloads, proceeds: bucket.proceeds))
            guard let next = cal.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return points
    }

    public func portfolio(apps: [ASCApp], days: Int = 7, limit: Int = 5) -> [PortfolioMetricsEntry] {
        let cal = Calendar(identifier: .gregorian)
        let end = cal.startOfDay(for: .now)
        guard let periodStart = cal.date(byAdding: .day, value: -(days - 1), to: end),
              let prevEnd = cal.date(byAdding: .day, value: -days, to: periodStart) else { return [] }
        let fmt = Self.dateFormatter
        let curStart = fmt.string(from: periodStart)
        let curEnd = fmt.string(from: end)
        let prevStart = fmt.string(from: cal.date(byAdding: .day, value: -(days - 1), to: prevEnd) ?? prevEnd)
        let prevEndStr = fmt.string(from: prevEnd)

        return apps.prefix(limit).map { app in
            let current = summary(for: app, from: curStart, to: curEnd)
            let previous = summary(for: app, from: prevStart, to: prevEndStr)
            return PortfolioMetricsEntry(
                appId: app.id,
                appName: app.name,
                downloads: current.totalDownloads,
                proceeds: current.proceeds,
                deltaDownloads: Self.percentDelta(current: Double(current.totalDownloads), previous: Double(previous.totalDownloads)),
                deltaProceeds: Self.percentDelta(current: current.proceeds, previous: previous.proceeds)
            )
        }
    }

    // MARK: - Private

    private func importFileLocked(at path: String, apps: [ASCApp], force: Bool) -> Int {
        let mod = (try? FileManager.default.attributesOfItem(atPath: path)[.modificationDate] as? Date) ?? .distantPast
        if !force, let seen = snapshot.importedFiles[path], seen >= mod { return 0 }
        guard let result = SalesReportParser.parseFile(at: path), !result.rows.isEmpty else { return 0 }
        mergeRows(result.rows)
        learnAppleIdentifiers(apps: apps, rows: result.rows)
        snapshot.importedFiles[path] = mod
        return result.rows.count
    }

    private func mergeRows(_ incoming: [SalesReportRow]) {
        var index = Dictionary(uniqueKeysWithValues: snapshot.records.map { ($0.id, $0) })
        for row in incoming { index[row.id] = row }
        snapshot.records = Array(index.values).sorted {
            if $0.reportDate != $1.reportDate { return $0.reportDate < $1.reportDate }
            return $0.sku < $1.sku
        }
    }

    private func learnAppleIdentifiers(apps: [ASCApp], rows: [SalesReportRow]) {
        for app in apps {
            guard snapshot.appleIdsByAppId[app.id] == nil,
                  let appleId = MetricsAppMatcher.discoverAppleIdentifier(for: app, in: rows) else { continue }
            snapshot.appleIdsByAppId[app.id] = appleId
        }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private static func load(from url: URL) throws -> MetricsSnapshot {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(MetricsSnapshot.self, from: data)
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    private static func percentDelta(current: Double, previous: Double) -> Double? {
        guard previous > 0 else { return current > 0 ? 100 : nil }
        return (current - previous) / previous * 100
    }
}
