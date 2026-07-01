import Foundation

// MARK: - Chart kinds

public enum AppStoreChartKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case topFree = "top-free"
    case topPaid = "top-paid"
    case topGrossing = "top-grossing"

    public var id: String { rawValue }

    public var locKey: LocKey {
        switch self {
        case .topFree:     return .mktChartFree
        case .topPaid:     return .mktChartPaid
        case .topGrossing: return .mktChartGrossing
        }
    }
}

public enum AppStoreChartCategory: String, CaseIterable, Identifiable, Codable, Sendable {
    case apps
    case games

    public var id: String { rawValue }

    public var locKey: LocKey {
        switch self {
        case .apps:  return .mktChartApps
        case .games: return .mktChartGames
        }
    }
}

// MARK: - Models

public struct AppStoreChartEntry: Sendable, Hashable, Codable, Identifiable {
    public let rank: Int
    public let id: String
    public let name: String
    public let artistName: String
    public let artworkURL: String?
    public let genre: String?
    public let storeURL: String?

    public init(rank: Int,
                id: String,
                name: String,
                artistName: String,
                artworkURL: String? = nil,
                genre: String? = nil,
                storeURL: String? = nil) {
        self.rank = rank
        self.id = id
        self.name = name
        self.artistName = artistName
        self.artworkURL = artworkURL
        self.genre = genre
        self.storeURL = storeURL
    }
}

public struct AppStoreChartsFeed: Sendable, Equatable {
    public let country: String
    public let category: AppStoreChartCategory
    public let kind: AppStoreChartKind
    public let updated: Date?
    public let entries: [AppStoreChartEntry]

    public var cacheKey: String {
        ChartHistoryStore.key(country: country, category: category, kind: kind)
    }

    public init(country: String,
                category: AppStoreChartCategory,
                kind: AppStoreChartKind,
                updated: Date? = nil,
                entries: [AppStoreChartEntry]) {
        self.country = country
        self.category = category
        self.kind = kind
        self.updated = updated
        self.entries = entries
    }
}

// MARK: - Client

public enum AppStoreChartsClient {
    public static let baseURL = "https://rss.applemarketingtools.com/api/v2"
    public static let defaultLimit = 25

    public static func feedURL(country: String,
                               category: AppStoreChartCategory,
                               kind: AppStoreChartKind,
                               limit: Int = defaultLimit) -> URL? {
        let path = "\(baseURL)/\(country.lowercased())/\(category.rawValue)/\(kind.rawValue)/\(limit)/apps.json"
        return URL(string: path)
    }

    /// Fetches and parses a top-charts feed from Apple Marketing Tools.
    public static func fetch(country: String,
                             category: AppStoreChartCategory,
                             kind: AppStoreChartKind,
                             limit: Int = defaultLimit,
                             session: URLSession = .shared) async throws -> AppStoreChartsFeed {
        guard let url = feedURL(country: country, category: category, kind: kind, limit: limit) else {
            throw URLError(.badURL)
        }
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try parse(data: data, country: country, category: category, kind: kind)
    }

    public static func parse(data: Data,
                             country: String,
                             category: AppStoreChartCategory,
                             kind: AppStoreChartKind) throws -> AppStoreChartsFeed {
        let root = try JSONDecoder().decode(FeedRoot.self, from: data)
        let results = root.feed.results ?? []
        let updated = root.feed.updated.flatMap(Self.parseUpdated)
        let entries = results.enumerated().map { index, item in
            AppStoreChartEntry(
                rank: index + 1,
                id: item.id,
                name: item.name,
                artistName: item.artistName,
                artworkURL: item.artworkUrl100,
                genre: item.genres?.first?.name,
                storeURL: item.url
            )
        }
        return AppStoreChartsFeed(
            country: country.lowercased(),
            category: category,
            kind: kind,
            updated: updated,
            entries: entries
        )
    }

    private static func parseUpdated(_ raw: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: raw) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: raw)
    }

    // MARK: - Private JSON shapes

    private struct FeedRoot: Decodable {
        let feed: Feed
    }

    private struct Feed: Decodable {
        let updated: String?
        let results: [FeedItem]?
    }

    private struct FeedItem: Decodable {
        let id: String
        let name: String
        let artistName: String
        let artworkUrl100: String?
        let url: String?
        let genres: [FeedGenre]?
    }

    private struct FeedGenre: Decodable {
        let name: String
    }
}
