import Foundation
import Combine
import ASCShared

/// Fetches public App Store charts, iTunes metadata, and market-index trends.
@MainActor
final class MarketEngine: ObservableObject {
    @Published var country = "us"
    @Published var category: AppStoreChartCategory = .apps
    @Published var chartKind: AppStoreChartKind = .topFree

    @Published private(set) var feed: AppStoreChartsFeed?
    @Published private(set) var marketIndex: MarketIndexResult?
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: String?
    @Published private(set) var lastFetched: Date?

    let history: ChartHistoryStore

    private static let countryKey = "asc.market.country"

    init(history: ChartHistoryStore = ChartHistoryStore()) {
        self.history = history
        if let saved = UserDefaults.standard.string(forKey: Self.countryKey) {
            country = saved
        }
    }

    var cacheKey: String {
        ChartHistoryStore.key(country: country, category: category, kind: chartKind)
    }

    func setCountry(_ code: String) {
        country = code.lowercased()
        UserDefaults.standard.set(country, forKey: Self.countryKey)
    }

    func refreshCharts() async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }
        do {
            let result = try await AppStoreChartsClient.fetch(
                country: country, category: category, kind: chartKind
            )
            feed = result
            lastFetched = Date()
            let snap = history.record(result)
            marketIndex = MarketIndexCalculator.compute(
                current: snap,
                previous: history.previous(for: snap.key)
            )
        } catch {
            lastError = error.localizedDescription
            // Fall back to last cached snapshot when offline.
            if let cached = history.latest(for: cacheKey) {
                feed = AppStoreChartsFeed(
                    country: cached.country,
                    category: cached.category,
                    kind: cached.kind,
                    entries: cached.entries
                )
                marketIndex = MarketIndexCalculator.compute(
                    current: cached,
                    previous: history.previous(for: cached.key)
                )
            }
        }
    }

    func toggleBookmark(_ appId: String) {
        history.toggleBookmark(appId)
        objectWillChange.send()
    }

    func isBookmarked(_ appId: String) -> Bool {
        history.isBookmarked(appId)
    }

    func sdkMatches() -> [SDKChartMatch] {
        guard let feed else { return [] }
        return KnownSDKCatalog.matches(in: feed.entries)
    }

    /// Finds chart rank for an owned app's Apple ID (if present in current feed).
    func chartRank(forAppleId appleId: String) -> AppStoreChartEntry? {
        feed?.entries.first { $0.id == appleId }
    }

    func chartRankNumber(forAppleId appleId: String) -> Int? {
        guard let feed else { return nil }
        guard let idx = feed.entries.firstIndex(where: { $0.id == appleId }) else { return nil }
        return idx + 1
    }

    /// JSON payload for remote mirror: chart position of an owned app.
    func mirrorRankJSON(forAppleId appleId: String) -> String? {
        guard let entry = chartRank(forAppleId: appleId),
              let rank = chartRankNumber(forAppleId: appleId) else { return nil }
        struct Payload: Codable {
            let country: String
            let chart: String
            let rank: Int
            let name: String
            let delta: Int?
        }
        let payload = Payload(
            country: country,
            chart: "\(chartKind.rawValue)/\(category.rawValue)",
            rank: rank,
            name: entry.name,
            delta: rankDelta(forAppleId: appleId)
        )
        guard let data = try? JSONEncoder().encode(payload),
              let text = String(data: data, encoding: .utf8) else { return nil }
        return text
    }

    func rankDelta(forAppleId appleId: String) -> Int? {
        guard let current = history.latest(for: cacheKey),
              let previous = history.previous(for: cacheKey) else { return nil }
        return MarketIndexCalculator.rankDelta(for: appleId, current: current, previous: previous)
    }

    static let supportedCountries: [(code: String, label: String)] = [
        ("us", "United States"), ("de", "Germany"), ("gb", "United Kingdom"),
        ("fr", "France"), ("es", "Spain"), ("it", "Italy"), ("nl", "Netherlands"),
        ("at", "Austria"), ("ch", "Switzerland"), ("jp", "Japan"), ("kr", "South Korea"),
        ("au", "Australia"), ("ca", "Canada"), ("br", "Brazil"), ("in", "India"),
    ]
}
