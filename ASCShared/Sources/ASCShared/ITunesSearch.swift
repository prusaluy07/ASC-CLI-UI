import Foundation

// MARK: - Models

public struct ITunesAppResult: Sendable, Hashable, Codable, Identifiable {
    public let trackId: Int64
    public let trackName: String
    public let artistName: String
    public let bundleId: String?
    public let description: String?
    public let averageUserRating: Double?
    public let userRatingCount: Int?
    public let price: Double?
    public let formattedPrice: String?
    public let version: String?
    public let screenshotUrls: [String]
    public let ipadScreenshotUrls: [String]
    public let artworkUrl512: String?
    public let sellerUrl: String?
    public let releaseNotes: String?
    public let primaryGenreName: String?
    public let country: String

    public var id: String { "\(trackId)" }

    public init(trackId: Int64,
                trackName: String,
                artistName: String,
                bundleId: String? = nil,
                description: String? = nil,
                averageUserRating: Double? = nil,
                userRatingCount: Int? = nil,
                price: Double? = nil,
                formattedPrice: String? = nil,
                version: String? = nil,
                screenshotUrls: [String] = [],
                ipadScreenshotUrls: [String] = [],
                artworkUrl512: String? = nil,
                sellerUrl: String? = nil,
                releaseNotes: String? = nil,
                primaryGenreName: String? = nil,
                country: String = "us") {
        self.trackId = trackId
        self.trackName = trackName
        self.artistName = artistName
        self.bundleId = bundleId
        self.description = description
        self.averageUserRating = averageUserRating
        self.userRatingCount = userRatingCount
        self.price = price
        self.formattedPrice = formattedPrice
        self.version = version
        self.screenshotUrls = screenshotUrls
        self.ipadScreenshotUrls = ipadScreenshotUrls
        self.artworkUrl512 = artworkUrl512
        self.sellerUrl = sellerUrl
        self.releaseNotes = releaseNotes
        self.primaryGenreName = primaryGenreName
        self.country = country
    }
}

// MARK: - Client

public enum ITunesSearchClient {
    public static func search(term: String,
                              country: String = "us",
                              limit: Int = 25,
                              session: URLSession = .shared) async throws -> [ITunesAppResult] {
        var components = URLComponents(string: "https://itunes.apple.com/search")!
        components.queryItems = [
            URLQueryItem(name: "term", value: term),
            URLQueryItem(name: "entity", value: "software"),
            URLQueryItem(name: "country", value: country.lowercased()),
            URLQueryItem(name: "limit", value: String(min(max(limit, 1), 200)))
        ]
        guard let url = components.url else { throw URLError(.badURL) }
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try parseSearch(data: data, country: country)
    }

    public static func lookup(id: Int64,
                              country: String = "us",
                              session: URLSession = .shared) async throws -> ITunesAppResult? {
        var components = URLComponents(string: "https://itunes.apple.com/lookup")!
        components.queryItems = [
            URLQueryItem(name: "id", value: String(id)),
            URLQueryItem(name: "country", value: country.lowercased())
        ]
        guard let url = components.url else { throw URLError(.badURL) }
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try parseSearch(data: data, country: country).first
    }

    public static func lookup(bundleId: String,
                              country: String = "us",
                              session: URLSession = .shared) async throws -> ITunesAppResult? {
        var components = URLComponents(string: "https://itunes.apple.com/lookup")!
        components.queryItems = [
            URLQueryItem(name: "bundleId", value: bundleId),
            URLQueryItem(name: "country", value: country.lowercased())
        ]
        guard let url = components.url else { throw URLError(.badURL) }
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try parseSearch(data: data, country: country).first
    }

    public static func parseSearch(data: Data, country: String) throws -> [ITunesAppResult] {
        let root = try JSONDecoder().decode(SearchRoot.self, from: data)
        return (root.results ?? []).map { item in
            ITunesAppResult(
                trackId: item.trackId ?? item.collectionId ?? 0,
                trackName: item.trackName ?? item.collectionName ?? "(unknown)",
                artistName: item.artistName ?? "",
                bundleId: item.bundleId,
                description: item.description,
                averageUserRating: item.averageUserRating,
                userRatingCount: item.userRatingCount,
                price: item.price,
                formattedPrice: item.formattedPrice,
                version: item.version,
                screenshotUrls: item.screenshotUrls ?? [],
                ipadScreenshotUrls: item.ipadScreenshotUrls ?? [],
                artworkUrl512: item.artworkUrl512 ?? item.artworkUrl100,
                sellerUrl: item.sellerUrl,
                releaseNotes: item.releaseNotes,
                primaryGenreName: item.primaryGenreName,
                country: country.lowercased()
            )
        }.filter { $0.trackId > 0 }
    }

    private struct SearchRoot: Decodable {
        let results: [SearchItem]?
    }

    private struct SearchItem: Decodable {
        let trackId: Int64?
        let collectionId: Int64?
        let trackName: String?
        let collectionName: String?
        let artistName: String?
        let bundleId: String?
        let description: String?
        let averageUserRating: Double?
        let userRatingCount: Int?
        let price: Double?
        let formattedPrice: String?
        let version: String?
        let screenshotUrls: [String]?
        let ipadScreenshotUrls: [String]?
        let artworkUrl512: String?
        let artworkUrl100: String?
        let sellerUrl: String?
        let releaseNotes: String?
        let primaryGenreName: String?
    }
}
