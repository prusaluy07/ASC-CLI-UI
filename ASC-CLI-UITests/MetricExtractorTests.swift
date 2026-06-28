import XCTest
@testable import ASC_CLI_UI

@MainActor
final class MetricExtractorTests: XCTestCase {

    func testUnavailableMetricsKeepStatusAndReason() throws {
        let json = """
        {
          "appId": "6776550237",
          "source": { "name": "analytics" },
          "metrics": [
            { "name": "completed_requests", "unit": "count", "status": "unavailable",
              "reason": "analytics source is not permitted for the current API key" },
            { "name": "reports_available", "unit": "count", "status": "unavailable",
              "reason": "analytics source is not permitted for the current API key" },
            { "name": "instances_available", "unit": "count", "status": "unavailable",
              "reason": "analytics source is not permitted for the current API key" },
            { "name": "business_conversion_rate", "unit": "percent", "status": "unavailable",
              "reason": "not derivable from analytics metadata alone" }
          ]
        }
        """
        let metrics = MetricExtractor.extract(json)
        XCTAssertEqual(metrics.count, 4)

        let conversion = try XCTUnwrap(metrics.first { $0.label == "business_conversion_rate" })
        XCTAssertNil(conversion.value)
        XCTAssertFalse(conversion.isAvailable)
        XCTAssertEqual(conversion.status, "unavailable")
        XCTAssertEqual(conversion.reason, "not derivable from analytics metadata alone")
        XCTAssertTrue(conversion.isPercentUnit)
    }

    func testNumericValueAndDeltaFromPreviousWeek() throws {
        let json = """
        { "metrics": [ { "name": "downloads", "value": 120, "previous": 100 } ] }
        """
        let metrics = MetricExtractor.extract(json)
        let downloads = try XCTUnwrap(metrics.first { $0.label == "downloads" })
        XCTAssertEqual(downloads.value, 120)
        XCTAssertTrue(downloads.isAvailable)
        let delta = try XCTUnwrap(downloads.delta)
        XCTAssertEqual(delta, 20, accuracy: 0.0001)
    }

    func testStringNumberWithThousandsSeparatorParses() {
        XCTAssertEqual(MetricExtractor.numeric(.string("1,234")), 1234)
        XCTAssertEqual(MetricExtractor.numeric(.number(42)), 42)
        XCTAssertNil(MetricExtractor.numeric(.string("n/a")))
    }

    func testDeduplicatesByNormalizedLabel() {
        let json = """
        { "metrics": [ { "name": "Downloads", "value": 1 },
                       { "name": "downloads", "value": 2 } ] }
        """
        let metrics = MetricExtractor.extract(json)
        XCTAssertEqual(metrics.filter { MetricExtractor.normalize($0.label) == "downloads" }.count, 1)
    }
}
