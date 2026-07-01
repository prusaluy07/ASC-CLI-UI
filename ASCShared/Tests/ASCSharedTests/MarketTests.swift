import XCTest
@testable import ASCShared

final class MarketTests: XCTestCase {

    private let sampleChartJSON = """
    {
      "feed": {
        "updated": "2026-06-30T12:00:00Z",
        "results": [
          {
            "id": "123456789",
            "name": "Test App",
            "artistName": "Dev Co",
            "artworkUrl100": "https://example.com/icon.png",
            "url": "https://apps.apple.com/app/id123456789",
            "genres": [{ "name": "Productivity" }]
          },
          {
            "id": "987654321",
            "name": "Firebase Helper",
            "artistName": "Other Dev",
            "artworkUrl100": null,
            "url": null,
            "genres": []
          }
        ]
      }
    }
    """

    private let sampleSearchJSON = """
    {
      "resultCount": 1,
      "results": [{
        "trackId": 123456789,
        "trackName": "Test App",
        "artistName": "Dev Co",
        "bundleId": "com.example.test",
        "description": "A productivity app powered by Firebase.",
        "averageUserRating": 4.5,
        "userRatingCount": 120,
        "price": 0,
        "formattedPrice": "Free",
        "version": "2.0",
        "screenshotUrls": ["https://example.com/shot1.png"],
        "ipadScreenshotUrls": [],
        "artworkUrl512": "https://example.com/icon512.png",
        "primaryGenreName": "Productivity"
      }]
    }
    """

    func testParsesChartFeed() throws {
        let data = Data(sampleChartJSON.utf8)
        let feed = try AppStoreChartsClient.parse(
            data: data, country: "us", category: .apps, kind: .topFree
        )
        XCTAssertEqual(feed.entries.count, 2)
        XCTAssertEqual(feed.entries[0].rank, 1)
        XCTAssertEqual(feed.entries[0].name, "Test App")
        XCTAssertEqual(feed.entries[1].id, "987654321")
        XCTAssertEqual(feed.cacheKey, "us:apps:top-free")
    }

    func testParsesITunesSearch() throws {
        let apps = try ITunesSearchClient.parseSearch(
            data: Data(sampleSearchJSON.utf8), country: "us"
        )
        XCTAssertEqual(apps.count, 1)
        XCTAssertEqual(apps[0].trackName, "Test App")
        XCTAssertEqual(apps[0].bundleId, "com.example.test")
        XCTAssertEqual(apps[0].screenshotUrls.count, 1)
    }

    func testChartHistoryRecordsSnapshots() {
        let store = ChartHistoryStore(filename: "test-chart-\(UUID().uuidString).json")
        let feed = AppStoreChartsFeed(
            country: "us", category: .apps, kind: .topFree,
            entries: [
                AppStoreChartEntry(rank: 1, id: "a", name: "A", artistName: "X"),
                AppStoreChartEntry(rank: 2, id: "b", name: "B", artistName: "Y"),
            ]
        )
        let snap = store.record(feed)
        XCTAssertEqual(store.latest(for: snap.key)?.entries.count, 2)

        let feed2 = AppStoreChartsFeed(
            country: "us", category: .apps, kind: .topFree,
            entries: [
                AppStoreChartEntry(rank: 1, id: "b", name: "B", artistName: "Y"),
                AppStoreChartEntry(rank: 2, id: "c", name: "C", artistName: "Z"),
            ]
        )
        let snap2 = store.record(feed2)
        let index = MarketIndexCalculator.compute(current: snap2, previous: snap)
        XCTAssertNotNil(index)
        XCTAssertEqual(index?.newEntrants, 1)
    }

    func testSDKKeywordMatching() {
        let entries = [
            AppStoreChartEntry(rank: 1, id: "1", name: "Firebase Helper", artistName: "X"),
            AppStoreChartEntry(rank: 2, id: "2", name: "Notes", artistName: "Y"),
        ]
        let matches = KnownSDKCatalog.matches(in: entries)
        XCTAssertFalse(matches.isEmpty)
        XCTAssertEqual(matches.first?.sdk.id, "firebase")
    }

    func testMarketIndexRankDelta() {
        let previous = ChartSnapshot(
            key: "us:apps:top-free", country: "us", category: .apps, kind: .topFree,
            entries: [
                AppStoreChartEntry(rank: 5, id: "app1", name: "Mine", artistName: "Me"),
            ]
        )
        let current = ChartSnapshot(
            key: "us:apps:top-free", country: "us", category: .apps, kind: .topFree,
            entries: [
                AppStoreChartEntry(rank: 2, id: "app1", name: "Mine", artistName: "Me"),
            ]
        )
        XCTAssertEqual(MarketIndexCalculator.rankDelta(for: "app1", current: current, previous: previous), 3)
    }
}
