import Foundation
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

    func hasData(for app: ASCApp, days: Int = 14) -> Bool {
        summary(for: app, days: days).rowCount > 0
    }

    func subscriptionSummary(for app: ASCApp, days: Int = 30) -> AppMetricsSummary {
        let rows = store.rows(for: app, from: dateRange(days: days).start, to: dateRange(days: days).end)
            .filter(\.isSubscription)
        return AppMetricsSummary.aggregate(rows)
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
