import XCTest
@testable import ASCShared

final class SalesReportTests: XCTestCase {

    private func sampleTSV(day1: String, day2: String) -> String {
        """
        Provider\tProvider Country\tSKU\tDeveloper\tTitle\tVersion\tProduct Type Identifier\tUnits\tDeveloper Proceeds\tBegin Date\tEnd Date\tCustomer Currency\tCountry Code\tCurrency of Proceeds\tApple Identifier\tCustomer Price\tPromo Code\tParent Identifier\tSubscription\tPeriod\tCategory\tCMB\tDevice\tSupported Platforms\tProceeds Reason\tPreserved Pricing\tClient\tOrder Type
        APPLE\tUS\tcom.example.app\tDev\tMy App\t1.0\t1\t10\t2.99\t\(day1)\t\(day1)\tUSD\tUS\tUSD\t1234567890\t3.99\t\t\t\t\t\tiPhone\tiOS\t\t\t\t
        APPLE\tUS\tcom.example.app\tDev\tMy App\t1.0\t7\t5\t0.00\t\(day1)\t\(day1)\tUSD\tUS\tUSD\t1234567890\t0.00\t\t\t\t\t\tiPhone\tiOS\t\t\t\t
        APPLE\tDE\tcom.example.app\tDev\tMy App\t1.0\t1F\t3\t0.00\t\(day2)\t\(day2)\tEUR\tDE\tEUR\t1234567890\t0.00\t\t\t\t\t\tiPhone\tiOS\t\t\t\t
        APPLE\tUS\tcom.example.iap\tDev\tPremium\t1.0\tIA1\t2\t1.50\t\(day2)\t\(day2)\tUSD\tUS\tUSD\t1234567890\t1.99\t\t\t\t\t\tiPhone\tiOS\t\t\t\t
        APPLE\tUS\tcom.example.sub\tDev\tPro Sub\t1.0\tIAY\t1\t4.99\t\(day2)\t\(day2)\tUSD\tUS\tUSD\t1234567890\t6.99\t\t\tNew\t1 Month\t\tiPhone\tiOS\t\t\t\t
        """
    }

    private func iso(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f.string(from: date)
    }

    private var recentDays: (String, String) {
        let cal = Calendar(identifier: .gregorian)
        let today = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        return (iso(yesterday), iso(today))
    }

    func testParsesSalesSummaryRows() {
        let (d1, d2) = recentDays
        let result = SalesReportParser.parse(text: sampleTSV(day1: d1, day2: d2))
        XCTAssertEqual(result.rows.count, 5)
        XCTAssertEqual(result.rows.first?.sku, "com.example.app")
        XCTAssertEqual(result.rows.first?.units, 10)
        XCTAssertEqual(result.rows.first?.proceeds ?? 0, 29.9, accuracy: 0.01)
    }

    func testClassifiesProductTypes() {
        let (d1, d2) = recentDays
        let result = SalesReportParser.parse(text: sampleTSV(day1: d1, day2: d2))
        let byType = Dictionary(grouping: result.rows, by: \.productTypeIdentifier)
        XCTAssertEqual(byType["1"]?.first?.isFirstDownload, true)
        XCTAssertEqual(byType["7"]?.first?.isUpdate, true)
        XCTAssertEqual(byType["1F"]?.first?.isFirstDownload, true)
        XCTAssertEqual(byType["IA1"]?.first?.isInAppPurchase, true)
        XCTAssertEqual(byType["IAY"]?.first?.isSubscription, true)
    }

    func testAggregatesMetrics() {
        let (d1, d2) = recentDays
        let rows = SalesReportParser.parse(text: sampleTSV(day1: d1, day2: d2)).rows
        let summary = AppMetricsSummary.aggregate(rows)
        XCTAssertEqual(summary.firstDownloads, 13) // 10 + 3 free
        XCTAssertEqual(summary.updates, 5)
        XCTAssertEqual(summary.iapUnits, 2)
        XCTAssertEqual(summary.subscriptionUnits, 1)
        XCTAssertGreaterThan(summary.proceeds, 0)
    }

    func testMetricsStoreImportAndQuery() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = MetricsStore(directory: dir)
        let app = ASCApp.fixture(id: "app1", name: "My App", sku: "com.example.app")

        let (d1, d2) = recentDays
        let tsv = sampleTSV(day1: d1, day2: d2)
        let imported = store.importText(tsv, apps: [app])
        XCTAssertEqual(imported, 5)
        XCTAssertEqual(store.recordCount, 5)

        let rows = store.rows(for: app, from: d1, to: d2)
        XCTAssertEqual(rows.count, 5)

        let summary = store.summary(for: app, from: d1, to: d2)
        XCTAssertEqual(summary.firstDownloads, 13)

        let trend = store.trend(for: app, days: 2)
        XCTAssertEqual(trend.count, 2)
        XCTAssertEqual(trend.last?.downloads, 3)
    }

    func testPortfolioComparison() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let store = MetricsStore(directory: dir)
        let app = ASCApp.fixture(id: "app1", name: "My App", sku: "com.example.app")
        let (d1, d2) = recentDays
        _ = store.importText(sampleTSV(day1: d1, day2: d2), apps: [app])

        let portfolio = store.portfolio(apps: [app], days: 7)
        XCTAssertEqual(portfolio.count, 1)
        XCTAssertEqual(portfolio[0].appName, "My App")
        XCTAssertGreaterThan(portfolio[0].downloads, 0)
    }

    func testFiscalCalendarNextPayment() {
        let cal = Calendar(identifier: .gregorian)
        let june = cal.date(from: DateComponents(year: 2026, month: 6, day: 15))!
        XCTAssertNotNil(AppleFiscalCalendar.period(containing: june))
        XCTAssertNotNil(AppleFiscalCalendar.nextPayment(after: june))
    }
}

// MARK: - Test fixture

private extension ASCApp {
    static func fixture(id: String, name: String, sku: String) -> ASCApp {
        let json = """
        {"data":{"id":"\(id)","type":"apps","attributes":{"name":"\(name)","bundleId":"\(sku)","sku":"\(sku)"}}}
        """
        let data = json.data(using: .utf8)!
        let response = try! JSONDecoder().decode(ASCSingleResponse<ASCApp>.self, from: data)
        return response.data
    }
}
