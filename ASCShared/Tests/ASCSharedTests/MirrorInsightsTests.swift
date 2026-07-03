import XCTest
import ASCShared

final class MirrorInsightsTests: XCTestCase {

    // MARK: - StoredMetricsPayload

    func testDecodesStoredMetricsPayload() throws {
        let json = """
        {
          "appId": "6776550237",
          "days": 7,
          "downloads": 42,
          "proceeds": 12.5,
          "returns": 1,
          "trend": [
            { "date": "2026-06-20", "downloads": 3, "proceeds": 1.0,
              "iapUnits": 0, "updates": 2, "returns": 0, "subscriptionUnits": 0 },
            { "date": "2026-06-21", "downloads": 7, "proceeds": 2.5,
              "iapUnits": 1, "updates": 0, "returns": 0, "subscriptionUnits": 0 }
          ]
        }
        """
        let payload = try XCTUnwrap(StoredMetricsPayload.decode(json))
        XCTAssertEqual(payload.downloads, 42)
        XCTAssertEqual(payload.proceeds, 12.5, accuracy: 0.001)
        XCTAssertEqual(payload.trend.count, 2)
        XCTAssertEqual(payload.trend[1].downloads, 7)
        XCTAssertTrue(payload.hasProceeds)
    }

    func testStoredMetricsWithoutProceeds() throws {
        let json = """
        { "appId": "1", "days": 7, "downloads": 9, "proceeds": 0, "returns": 0,
          "trend": [ { "date": "2026-06-20", "downloads": 9, "proceeds": 0,
                       "iapUnits": 0, "updates": 0, "returns": 0, "subscriptionUnits": 0 } ] }
        """
        let payload = try XCTUnwrap(StoredMetricsPayload.decode(json))
        XCTAssertFalse(payload.hasProceeds)
    }

    func testStoredMetricsGarbageDecodesToNil() {
        XCTAssertNil(StoredMetricsPayload.decode("not json"))
        XCTAssertNil(StoredMetricsPayload.decode("{}"))
        XCTAssertNil(StoredMetricsPayload.decode(""))
    }

    // MARK: - MarketRankPayload

    func testDecodesMarketRankPayload() throws {
        let json = #"{ "country": "de", "chart": "topFree/all", "rank": 12, "name": "Voicement", "delta": -3 }"#
        let payload = try XCTUnwrap(MarketRankPayload.decode(json))
        XCTAssertEqual(payload.rank, 12)
        XCTAssertEqual(payload.delta, -3)
        XCTAssertEqual(payload.chart, "topFree/all")
    }

    func testMarketRankWithoutDelta() throws {
        let json = #"{ "country": "us", "chart": "topPaid/games", "rank": 4, "name": "X" }"#
        let payload = try XCTUnwrap(MarketRankPayload.decode(json))
        XCTAssertNil(payload.delta)
    }

    func testMarketRankGarbageDecodesToNil() {
        XCTAssertNil(MarketRankPayload.decode("[]"))
        XCTAssertNil(MarketRankPayload.decode(#"{ "rank": "twelve" }"#))
    }

    // MARK: - Trend date parsing

    func testTrendPointDayParsing() {
        let point = MetricsTrendPoint(date: "2026-06-30", downloads: 1, proceeds: 0)
        let day = point.day
        XCTAssertNotNil(day)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        XCTAssertEqual(cal.component(.day, from: day!), 30)
        XCTAssertEqual(cal.component(.month, from: day!), 6)

        XCTAssertNil(MetricsTrendPoint(date: "garbage", downloads: 0, proceeds: 0).day)
        XCTAssertNil(MetricsTrendPoint(date: "", downloads: 0, proceeds: 0).day)
    }
}
