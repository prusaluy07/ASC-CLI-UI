import XCTest
@testable import ASCShared

final class AnalyticsReportTests: XCTestCase {

    // MARK: Table parsing

    func testParsesTabSeparatedReport() {
        let tsv = "Date\tEvent\tCounts\n2026-06-21\tImpression\t45\n2026-06-21\tPage View\t19\n"
        let table = AnalyticsReportTable(text: tsv)
        XCTAssertEqual(table.columns, ["Date", "Event", "Counts"])
        XCTAssertEqual(table.rows.count, 2)
        XCTAssertEqual(table.rows[0], ["2026-06-21", "Impression", "45"])
    }

    func testParsesCommaSeparatedFallback() {
        let csv = "Event,Counts\nImpression,10\n"
        let table = AnalyticsReportTable(text: csv)
        XCTAssertEqual(table.columns, ["Event", "Counts"])
        XCTAssertEqual(table.rows[0], ["Impression", "10"])
    }

    func testEmptyOrGarbageIsEmptyTable() {
        XCTAssertTrue(AnalyticsReportTable(text: "").isEmpty)
        XCTAssertTrue(AnalyticsReportTable(text: "OnlyHeader\tNoRows").isEmpty)
    }

    // MARK: Event-shape aggregation

    func testAggregatesCountsByEvent() {
        let tsv = """
        Date\tEvent\tCounts
        2026-06-21\tImpression\t45
        2026-06-21\tPage View\t19
        2026-06-22\tImpression\t5
        """
        let metrics = AnalyticsReportSummarizer.metrics(from: AnalyticsReportTable(text: tsv))
        let byLabel = Dictionary(uniqueKeysWithValues: metrics.map { ($0.label, $0.value) })
        XCTAssertEqual(byLabel["Impression"], 50)
        XCTAssertEqual(byLabel["Page View"], 19)
    }

    func testDownloadTypeReportMapsToCatalogCards() {
        let tsv = """
        Date\tDownload Type\tCounts
        2026-06-21\tFirst Time Download\t6
        2026-06-21\tRedownload\t1
        """
        let metrics = AnalyticsReportSummarizer.metrics(from: AnalyticsReportTable(text: tsv))
        let resolved = AnalyticsCatalog.resolve(metrics)
        XCTAssertEqual(resolved[.anFirstDownloads]?.value, 6)
        XCTAssertEqual(resolved[.anRedownloads]?.value, 1)
    }

    func testEngagementReportResolvesImpressionsAndPageViews() {
        let tsv = """
        Date\tEvent\tCounts
        2026-06-21\tImpression\t45
        2026-06-21\tProduct Page View\t19
        """
        let metrics = AnalyticsReportSummarizer.metrics(from: AnalyticsReportTable(text: tsv))
        let resolved = AnalyticsCatalog.resolve(metrics)
        XCTAssertEqual(resolved[.anImpressions]?.value, 45)
        XCTAssertEqual(resolved[.anPageViews]?.value, 19)
    }

    // MARK: Wide-shape aggregation

    func testWideShapeSumsNumericColumns() {
        let tsv = """
        Date\tImpressions\tProduct Page Views
        2026-06-21\t40\t10
        2026-06-22\t5\t9
        """
        let metrics = AnalyticsReportSummarizer.metrics(from: AnalyticsReportTable(text: tsv))
        let byLabel = Dictionary(uniqueKeysWithValues: metrics.map { ($0.label, $0.value) })
        XCTAssertEqual(byLabel["Impressions"], 45)
        XCTAssertEqual(byLabel["Product Page Views"], 19)
    }

    // MARK: Instance locator

    func testLocatesInstancesFromJSONAPI() {
        let json = """
        {
          "data": [
            { "type": "analyticsReports", "id": "rep1",
              "attributes": { "name": "App Store Discovery and Engagement", "category": "APP_STORE_ENGAGEMENT" } }
          ],
          "included": [
            { "type": "analyticsReportInstances", "id": "inst-old",
              "attributes": { "granularity": "DAILY", "processingDate": "2026-06-20" } },
            { "type": "analyticsReportInstances", "id": "inst-new",
              "attributes": { "granularity": "DAILY", "processingDate": "2026-06-21" } },
            { "type": "analyticsReportSegments", "id": "seg1", "attributes": { "checksum": "abc" } }
          ]
        }
        """
        let instances = AnalyticsReportLocator.instances(fromViewJSON: json)
        XCTAssertEqual(instances.count, 2)
        // Newest processingDate first.
        XCTAssertEqual(instances.first?.instanceId, "inst-new")
        XCTAssertEqual(instances.first?.processingDate, "2026-06-21")
        XCTAssertEqual(instances.first?.granularity, "DAILY")
    }

    func testLocatorHandlesInlineSegments() {
        let json = """
        { "data": [
            { "type": "analyticsReportInstances", "id": "inst1",
              "attributes": { "processingDate": "2026-06-21" },
              "segments": [ { "id": "segA" }, { "id": "segB" } ] }
        ] }
        """
        let instances = AnalyticsReportLocator.instances(fromViewJSON: json)
        XCTAssertEqual(instances.first?.segmentIds, ["segA", "segB"])
    }

    func testLocatorReturnsEmptyOnGarbage() {
        XCTAssertTrue(AnalyticsReportLocator.instances(fromViewJSON: "not json").isEmpty)
        XCTAssertTrue(AnalyticsReportLocator.instances(fromViewJSON: "{}").isEmpty)
    }
}
