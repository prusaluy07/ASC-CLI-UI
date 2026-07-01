import Foundation
import Combine
import ASCShared

/// Bridges ``MetricsStore`` with the macOS app: scans the reports folder, imports new files,
/// and exposes portfolio / trend queries to SwiftUI.
@MainActor
final class MetricsEngine: ObservableObject {
    @Published private(set) var recordCount = 0
    @Published private(set) var importedFileCount = 0
    @Published private(set) var lastScan: Date?
    @Published private(set) var lastImportMessage: String?

    let store: MetricsStore

    init(store: MetricsStore = MetricsStore()) {
        self.store = store
        refreshCounts()
    }

    func refreshCounts() {
        recordCount = store.recordCount
        importedFileCount = store.importedFileCount
        lastScan = store.lastScan
    }

    @discardableResult
    func importFile(at path: String, apps: [ASCApp]) -> Int {
        let count = store.importFile(at: path, apps: apps)
        refreshCounts()
        if count > 0 {
            lastImportMessage = "\(count) rows"
        }
        return count
    }

    @discardableResult
    func scanDirectory(_ directory: String, apps: [ASCApp]) -> MetricsStore.ScanResult {
        let result = store.scanDirectory(directory, apps: apps)
        refreshCounts()
        lastImportMessage = "\(result.rowsImported) rows from \(result.filesScanned) files"
        return result
    }

    func summary(for app: ASCApp, days: Int = 7) -> AppMetricsSummary {
        let range = dateRange(days: days)
        return store.summary(for: app, from: range.start, to: range.end)
    }

    func trend(for app: ASCApp, days: Int = 14) -> [MetricsTrendPoint] {
        store.trend(for: app, days: days)
    }

    func portfolio(apps: [ASCApp], days: Int = 7) -> [PortfolioMetricsEntry] {
        store.portfolio(apps: apps, days: days, limit: 5)
    }

    /// True when any sales rows exist for this app (not limited to a recent window).
    func hasData(for app: ASCApp) -> Bool {
        !store.rows(for: app).isEmpty
    }

    func weekMetrics(for app: ASCApp) -> [LocKey: AnalyticsMetric] {
        StoredAnalyticsMapper.weekMetrics(comparison: store.comparePeriods(for: app, days: 7))
    }

    func monthMetrics(for app: ASCApp) -> [LocKey: AnalyticsMetric] {
        StoredAnalyticsMapper.weekMetrics(comparison: store.comparePeriods(for: app, days: 30))
    }

    func subscriptionSummary(for app: ASCApp, days: Int = 30) -> AppMetricsSummary {
        let rows = store.rows(for: app, from: dateRange(days: days).start, to: dateRange(days: days).end)
            .filter(\.isSubscription)
        return AppMetricsSummary.aggregate(rows)
    }

    func exportCSV(for app: ASCApp) -> String {
        store.exportCSV(for: app)
    }

    func exportJSON(for app: ASCApp) -> String {
        store.exportJSON(for: app)
    }

    func exportPortfolioJSON(apps: [ASCApp]) -> String {
        store.exportPortfolioJSON(apps: apps)
    }

    func fiscalProceeds(for app: ASCApp, period: AppleFiscalPeriod) -> (proceeds: Double, isComplete: Bool) {
        store.fiscalProceeds(for: app, period: period)
    }

    /// JSON payload mirrored to ASC Remote for offline analytics.
    func mirrorPayloadJSON(for app: ASCApp) -> String {
        let comparison = store.comparePeriods(for: app, days: 7)
        let trend = store.trend(for: app, days: 14)
        struct Payload: Codable {
            let appId: String
            let days: Int
            let downloads: Int
            let proceeds: Double
            let returns: Int
            let trend: [MetricsTrendPoint]
        }
        let payload = Payload(
            appId: app.id,
            days: 7,
            downloads: comparison.current.totalDownloads,
            proceeds: comparison.current.proceeds,
            returns: comparison.current.returns,
            trend: trend
        )
        guard let data = try? JSONEncoder().encode(payload),
              let text = String(data: data, encoding: .utf8) else { return "{}" }
        return text
    }

    private func dateRange(days: Int) -> (start: String, end: String) {
        let cal = Calendar(identifier: .gregorian)
        let end = cal.startOfDay(for: .now)
        let start = cal.date(byAdding: .day, value: -(days - 1), to: end) ?? end
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone(secondsFromGMT: 0)
        return (fmt.string(from: start), fmt.string(from: end))
    }
}
