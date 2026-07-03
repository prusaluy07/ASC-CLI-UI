import Foundation

// MARK: - Models

/// A product registered in the user's Appfigures account.
public struct AppfiguresProduct: Sendable, Hashable, Identifiable {
    /// Appfigures-assigned product id (used by all other endpoints).
    public let id: Int64
    public let name: String
    public let developer: String?
    /// The store's own id — for Apple products this is the numeric App Store id.
    public let refNo: String?
    public let store: String?
    public let bundleId: String?

    public init(id: Int64, name: String, developer: String? = nil,
                refNo: String? = nil, store: String? = nil, bundleId: String? = nil) {
        self.id = id
        self.name = name
        self.developer = developer
        self.refNo = refNo
        self.store = store
        self.bundleId = bundleId
    }
}

/// One tracked ASO keyword with its latest rank and Appfigures' research scores.
public struct AppfiguresKeyword: Sendable, Hashable {
    public let term: String
    /// Current search-result position (nil when the app doesn't rank for the term).
    public let position: Int?
    /// Position change vs the previous period (negative = climbed).
    public let delta: Int?
    /// How often the term is searched, 0–100.
    public let popularity: Double?
    /// How strong the current top results are, 1–100 (higher = harder).
    public let competitiveness: Double?
    public let numApps: Int?

    public init(term: String, position: Int? = nil, delta: Int? = nil,
                popularity: Double? = nil, competitiveness: Double? = nil, numApps: Int? = nil) {
        self.term = term
        self.position = position
        self.delta = delta
        self.popularity = popularity
        self.competitiveness = competitiveness
        self.numApps = numApps
    }
}

// MARK: - Errors

public enum AppfiguresError: LocalizedError {
    /// 401/403 — bad or expired personal access token.
    case unauthorized
    case http(Int, String)
    case badPayload

    public var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Appfigures rejected the API key (HTTP 401/403). Check the personal access token."
        case .http(let status, let body):
            let detail = body.prefix(200)
            return "Appfigures returned HTTP \(status)\(detail.isEmpty ? "." : ": \(detail)")"
        case .badPayload:
            return "Appfigures returned an unexpected payload."
        }
    }
}

// MARK: - Client

/// Minimal Appfigures API v2 client (personal-access-token auth).
/// Network calls live here; all payload parsing is in static funcs so tests can
/// exercise it with fixtures and no network.
public struct AppfiguresClient: Sendable {
    public static let baseURL = URL(string: "https://api.appfigures.com/v2")!

    public let token: String
    public let session: URLSession

    public init(token: String, session: URLSession = .shared) {
        self.token = token
        self.session = session
    }

    /// All Apple products in the account (`/products/mine`). The caller matches
    /// `refNo` against the App Store id to find the Appfigures product id.
    public func products() async throws -> [AppfiguresProduct] {
        let data = try await get("products/mine", query: [URLQueryItem(name: "store", value: "apple")])
        return Self.parseProducts(data)
    }

    /// Tracked keyword ranks for one product/country (`/aso?group_by=keyword`).
    /// Follows pagination up to `maxPages`.
    public func keywords(productId: Int64, country: String, maxPages: Int = 5) async throws -> [AppfiguresKeyword] {
        var all: [AppfiguresKeyword] = []
        var page = 1
        while page <= maxPages {
            let data = try await get("aso", query: [
                URLQueryItem(name: "group_by", value: "keyword"),
                URLQueryItem(name: "products", value: String(productId)),
                URLQueryItem(name: "countries", value: country.uppercased()),
                URLQueryItem(name: "page", value: String(page))
            ])
            let parsed = Self.parseKeywordsPage(data)
            all += parsed.keywords
            guard parsed.hasMore, !parsed.keywords.isEmpty else { break }
            page += 1
        }
        return all
    }

    private func get(_ path: String, query: [URLQueryItem]) async throws -> Data {
        var components = URLComponents(url: Self.baseURL.appendingPathComponent(path),
                                       resolvingAgainstBaseURL: false)!
        components.queryItems = query
        guard let url = components.url else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        switch http.statusCode {
        case 200..<300: return data
        case 401, 403: throw AppfiguresError.unauthorized
        default: throw AppfiguresError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
    }

    // MARK: Parsing (fixture-testable)

    /// Accepts both response shapes Appfigures uses for product lists:
    /// an object keyed by product id and a plain array.
    public static func parseProducts(_ data: Data) -> [AppfiguresProduct] {
        guard let root = try? JSONDecoder().decode(JSONValue.self, from: data) else { return [] }
        let entries: [JSONValue]
        switch root {
        case .array(let a): entries = a
        case .object(let o):
            if case .array(let a)? = o["products"] { entries = a } else { entries = Array(o.values) }
        default: return []
        }
        return entries.compactMap(parseProduct).sorted { $0.id < $1.id }
    }

    private static func parseProduct(_ value: JSONValue) -> AppfiguresProduct? {
        guard case .object(let o) = value,
              let id = int64(o["id"]) else { return nil }
        return AppfiguresProduct(
            id: id,
            name: string(o["name"]) ?? "(unknown)",
            developer: string(o["developer"]),
            refNo: string(o["ref_no"]) ?? string(o["refno"]),
            store: string(o["store"]),
            bundleId: string(o["bundle_identifier"]) ?? string(o["bundle_id"])
        )
    }

    /// Parses one `/aso?group_by=keyword` page: `{ "metadata": {...}, "results": [...] }`.
    /// Tolerates a bare array as well. `hasMore` is derived from metadata paging fields.
    public static func parseKeywordsPage(_ data: Data) -> (keywords: [AppfiguresKeyword], hasMore: Bool) {
        guard let root = try? JSONDecoder().decode(JSONValue.self, from: data) else { return ([], false) }
        var results: [JSONValue] = []
        var hasMore = false
        switch root {
        case .array(let a):
            results = a
        case .object(let o):
            if case .array(let a)? = o["results"] { results = a }
            if case .object(let meta)? = o["metadata"] {
                if let page = int(meta["page"]), let pages = int(meta["pages"]) {
                    hasMore = page < pages
                } else if case .string(let next)? = meta["next"] {
                    hasMore = !next.isEmpty
                }
            }
        default:
            return ([], false)
        }
        let keywords = results.compactMap(parseKeyword)
        return (keywords, hasMore)
    }

    private static func parseKeyword(_ value: JSONValue) -> AppfiguresKeyword? {
        guard case .object(let o) = value else { return nil }
        // Term appears either flat (`keyword_term`) or nested under `keyword`.
        var term = string(o["keyword_term"]) ?? string(o["term"])
        if term == nil, case .object(let k)? = o["keyword"] {
            term = string(k["term"]) ?? string(k["keyword_term"])
        }
        guard let term, !term.isEmpty else { return nil }
        return AppfiguresKeyword(
            term: term,
            position: positive(int(o["position"])),
            delta: int(o["delta"]),
            popularity: double(o["popularity"]),
            competitiveness: double(o["competitiveness"]),
            numApps: int(o["num_apps"])
        )
    }

    // MARK: Loose field readers

    private static func string(_ v: JSONValue?) -> String? {
        switch v {
        case .string(let s): return s.isEmpty ? nil : s
        case .number(let d):
            return d.truncatingRemainder(dividingBy: 1) == 0 ? String(Int64(d)) : String(d)
        default: return nil
        }
    }

    private static func double(_ v: JSONValue?) -> Double? {
        switch v {
        case .number(let d): return d
        case .string(let s): return Double(s)
        default: return nil
        }
    }

    private static func int(_ v: JSONValue?) -> Int? { double(v).map(Int.init) }
    private static func int64(_ v: JSONValue?) -> Int64? { double(v).map(Int64.init) }

    /// Appfigures reports "not ranked" as 0 or -1; normalize those to nil.
    private static func positive(_ value: Int?) -> Int? {
        guard let value, value > 0 else { return nil }
        return value
    }
}
