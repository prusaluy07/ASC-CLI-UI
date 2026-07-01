import XCTest
@testable import ASCShared

final class StoredAnalyticsTests: XCTestCase {
    func testBuildsMetricsWithDeltas() {
        let current = AppMetricsSummary(firstDownloads: 20, returns: 2, proceeds: 100)
        let previous = AppMetricsSummary(firstDownloads: 10, returns: 0, proceeds: 50)
        let metrics = StoredAnalyticsMapper.buildMetrics(current: current, previous: previous)
        XCTAssertEqual(metrics[LocKey.anFirstDownloads]?.value, 20)
        XCTAssertEqual(metrics[LocKey.anFirstDownloads]?.delta, 100)
        XCTAssertEqual(metrics[LocKey.anReturns]?.value, 2)
    }

    func testNegativeUnitsAggregateAsReturns() {
        let row = SalesReportRow(
            reportDate: "2026-06-01", appleIdentifier: "1", sku: "x", title: "T",
            productTypeIdentifier: "1", units: -3, proceeds: -5.0, countryCode: "US"
        )
        let summary = AppMetricsSummary.aggregate([row])
        XCTAssertEqual(summary.returns, 3)
        XCTAssertEqual(summary.firstDownloads, 0)
    }
}
