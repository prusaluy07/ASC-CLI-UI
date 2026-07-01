import Foundation

public struct CustomerReview: Sendable, Identifiable, Hashable, Codable {
    public let id: String
    public let title: String?
    public let body: String?
    public let rating: Int?
    public let territory: String?
    public let createdDate: String?
    public let reviewerNickname: String?
    public let hasResponse: Bool
    public let responseBody: String?

    public init(id: String,
                title: String? = nil,
                body: String? = nil,
                rating: Int? = nil,
                territory: String? = nil,
                createdDate: String? = nil,
                reviewerNickname: String? = nil,
                hasResponse: Bool = false,
                responseBody: String? = nil) {
        self.id = id
        self.title = title
        self.body = body
        self.rating = rating
        self.territory = territory
        self.createdDate = createdDate
        self.reviewerNickname = reviewerNickname
        self.hasResponse = hasResponse
        self.responseBody = responseBody
    }
}

public struct ReviewRatingsSummary: Sendable, Equatable {
    public let averageRating: Double?
    public let ratingCount: Int?

    public init(averageRating: Double?, ratingCount: Int?) {
        self.averageRating = averageRating
        self.ratingCount = ratingCount
    }
}

public enum ReviewRatingsParser {
    public static func parse(_ text: String) -> ReviewRatingsSummary? {
        guard let data = text.data(using: .utf8),
              let root = try? JSONDecoder().decode(JSONValue.self, from: data) else { return nil }
        let candidate = items(root).first ?? root
        let attrs = candidate["attributes"] ?? candidate
        let avg = doubleField(attrs, "averageRating") ?? doubleField(attrs, "ratingAverage")
        let count = intField(attrs, "ratingCount") ?? intField(attrs, "totalRatingCount")
        guard avg != nil || count != nil else { return nil }
        return ReviewRatingsSummary(averageRating: avg, ratingCount: count)
    }

    private static func items(_ root: JSONValue) -> [JSONValue] {
        if case .array(let a) = root["data"] { return a }
        if case .array(let a) = root { return a }
        return []
    }

    private static func doubleField(_ value: JSONValue, _ key: String) -> Double? {
        switch value[key] {
        case .number(let d): return d
        case .string(let s): return Double(s)
        default: return nil
        }
    }

    private static func intField(_ value: JSONValue, _ key: String) -> Int? {
        switch value[key] {
        case .number(let d): return Int(d)
        case .string(let s): return Int(s)
        default: return nil
        }
    }
}

public enum CustomerReviewParser {
    public static func parse(_ text: String) -> [CustomerReview] {
        guard let data = text.data(using: .utf8),
              let root = try? JSONDecoder().decode(JSONValue.self, from: data) else { return [] }
        return items(root).compactMap(parseRecord)
    }

    private static func parseRecord(_ record: JSONValue) -> CustomerReview? {
        let id = field(record, "id") ?? field(record["data"] ?? .null, "id")
        guard let id, !id.isEmpty else { return nil }
        let attrs: JSONValue = {
            if case .object = record["attributes"] { return record["attributes"]! }
            if case .object(let data) = record["data"],
               case .object(let a) = data["attributes"] { return .object(a) }
            return record
        }()
        let response = field(attrs, "responseBody") ?? field(attrs["developerResponse"] ?? .null, "body")
        let responseState = field(attrs, "responseState")
        return CustomerReview(
            id: id,
            title: field(attrs, "title"),
            body: field(attrs, "body") ?? field(attrs, "review"),
            rating: intField(attrs, "rating"),
            territory: field(attrs, "territory") ?? field(attrs, "storefront"),
            createdDate: field(attrs, "createdDate") ?? field(attrs, "created"),
            reviewerNickname: field(attrs, "reviewerNickname") ?? field(attrs, "nickname"),
            hasResponse: !(response ?? "").isEmpty || responseState == "PUBLISHED",
            responseBody: response
        )
    }

    private static func items(_ root: JSONValue) -> [JSONValue] {
        if case .array(let a) = root["data"] { return a }
        if case .array(let a) = root { return a }
        if case .array(let a) = root["reviews"] { return a }
        return []
    }

    private static func field(_ value: JSONValue, _ key: String) -> String? {
        switch value[key] {
        case .string(let s): return s
        case .number(let d):
            if d.truncatingRemainder(dividingBy: 1) == 0 { return String(Int(d)) }
            return String(d)
        case .bool(let b): return b ? "true" : "false"
        default: return nil
        }
    }

    private static func intField(_ value: JSONValue, _ key: String) -> Int? {
        switch value[key] {
        case .number(let d): return Int(d)
        case .string(let s): return Int(s)
        default: return nil
        }
    }
}

private extension JSONValue {
    subscript(_ key: String) -> JSONValue? {
        if case .object(let o) = self { return o[key] }
        return nil
    }
}
