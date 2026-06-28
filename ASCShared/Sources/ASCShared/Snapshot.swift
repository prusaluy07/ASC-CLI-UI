import Foundation

/// A point-in-time capture of an app section's data, intended for future remote sync
/// (e.g. mirroring App Store Connect state to a companion iOS app). The raw `asc` JSON
/// payload is preserved verbatim in `payloadJSON` so it can be re-parsed later, while
/// `summary` holds a small set of pre-computed display values.
public struct Snapshot: Codable, Sendable {
    public var appId: String
    public var section: String
    public var schemaVersion: Int
    public var capturedAt: Date
    public var payloadJSON: String
    public var summary: [String: String]?

    public init(appId: String,
                section: String,
                schemaVersion: Int = Snapshot.currentSchemaVersion,
                capturedAt: Date = Date(),
                payloadJSON: String,
                summary: [String: String]? = nil) {
        self.appId = appId
        self.section = section
        self.schemaVersion = schemaVersion
        self.capturedAt = capturedAt
        self.payloadJSON = payloadJSON
        self.summary = summary
    }

    /// Current snapshot schema version. Bump when the stored shape changes so future
    /// readers can migrate older snapshots.
    public static let currentSchemaVersion = 1
}

// MARK: - Serialization helpers

public extension Snapshot {
    private static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    private static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// Encodes the snapshot to JSON data.
    func encoded() throws -> Data {
        try Snapshot.encoder().encode(self)
    }

    /// Encodes the snapshot to a JSON string (UTF-8).
    func encodedString() throws -> String {
        String(decoding: try encoded(), as: UTF8.self)
    }

    /// Decodes a snapshot from JSON data.
    static func decoded(from data: Data) throws -> Snapshot {
        try decoder().decode(Snapshot.self, from: data)
    }

    /// Decodes a snapshot from a JSON string.
    static func decoded(from string: String) throws -> Snapshot {
        try decoded(from: Data(string.utf8))
    }
}
