import Foundation

// MARK: - JSON:API envelope

/// App Store Connect (and therefore `asc`) returns JSON:API documents:
/// `{ "data": [ { "id": "...", "type": "...", "attributes": { ... } } ], "meta": { ... } }`
public struct ASCListResponse<T: Decodable>: Decodable {
    public let data: [T]
    public let meta: ASCMeta?
}

public struct ASCSingleResponse<T: Decodable>: Decodable {
    public let data: T
}

public struct ASCMeta: Decodable {
    public struct Paging: Decodable {
        public let total: Int?
        public let limit: Int?
    }
    public let paging: Paging?
}

/// JSON:API error document: `{ "errors": [ { "status", "code", "title", "detail" } ] }`.
/// `asc` normally exits non-zero on API errors, but an error document can still arrive
/// with exit 0 — it must surface as an error, not decode-collapse into an empty list.
public struct ASCErrorsResponse: Decodable {
    public struct APIError: Decodable {
        public let status: String?
        public let code: String?
        public let title: String?
        public let detail: String?
    }
    public let errors: [APIError]

    public var message: String {
        errors
            .map { [$0.title, $0.detail].compactMap { $0 }.joined(separator: ": ") }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}

public enum ASCDecodeError: LocalizedError {
    /// The command exited 0 but returned a JSON:API errors document.
    case api(String)
    /// The output could not be decoded at all.
    case malformed(String)

    public var errorDescription: String? {
        switch self {
        case .api(let message), .malformed(let message): return message
        }
    }
}

/// Decodes `asc` JSON:API list output into typed models. Foundation-only so the
/// iOS companion target and the unit tests can use it directly.
public enum ASCJSONList {
    /// - Returns: the decoded items plus paging info when the envelope carries `meta.paging`,
    ///   so callers can detect a page truncated by `--limit`.
    /// - Throws: `ASCDecodeError.api` for a JSON:API errors document,
    ///   `ASCDecodeError.malformed` when the output isn't decodable at all —
    ///   distinguishing both from a genuinely empty `data` array.
    public static func decode<T: Decodable>(_ output: String, as type: T.Type) throws -> (items: [T], paging: ASCMeta.Paging?) {
        guard !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let data = output.data(using: .utf8) else {
            throw ASCDecodeError.malformed("asc returned no output.")
        }
        let decoder = JSONDecoder()
        do {
            let wrapped = try decoder.decode(ASCListResponse<T>.self, from: data)
            return (wrapped.data, wrapped.meta?.paging)
        } catch let envelopeError {
            // Some subcommands return a bare array instead of the envelope.
            if let bare = try? decoder.decode([T].self, from: data) {
                return (bare, nil)
            }
            if let doc = try? decoder.decode(ASCErrorsResponse.self, from: data), !doc.errors.isEmpty {
                throw ASCDecodeError.api(doc.message)
            }
            throw ASCDecodeError.malformed("Unexpected JSON from asc: \(envelopeError.localizedDescription)")
        }
    }
}

/// Shared coding keys for the JSON:API resource envelope.
private enum ResourceKey: String, CodingKey {
    case id, type, attributes
}

public extension KeyedDecodingContainer {
    /// Decodes a Bool that may arrive as a native bool, a string ("true"/"1"/"yes")
    /// or a number — App Store Connect attributes occasionally drift between these,
    /// and a plain `try? decode(Bool.self)` would silently turn "true" into `false`.
    func decodeFlexibleBool(forKey key: Key) -> Bool? {
        if let b = try? decode(Bool.self, forKey: key) { return b }
        if let s = try? decode(String.self, forKey: key) {
            return ["true", "yes", "1"].contains(s.lowercased())
        }
        if let i = try? decode(Int.self, forKey: key) { return i != 0 }
        return nil
    }
}

// MARK: - Models

public struct ASCApp: Identifiable, Decodable, Hashable {
    public let id: String
    public let name: String
    public let bundleId: String
    public let sku: String?
    public let primaryLocale: String?

    private enum Attr: String, CodingKey {
        case name, bundleId, sku, primaryLocale
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: ResourceKey.self)
        id = try c.decode(String.self, forKey: .id)
        let a = try c.nestedContainer(keyedBy: Attr.self, forKey: .attributes)
        name = (try? a.decode(String.self, forKey: .name)) ?? "(unnamed)"
        bundleId = (try? a.decode(String.self, forKey: .bundleId)) ?? ""
        sku = try? a.decode(String.self, forKey: .sku)
        primaryLocale = try? a.decode(String.self, forKey: .primaryLocale)
    }
}

public struct ASCBuild: Identifiable, Decodable {
    public let id: String
    /// The build number (the JSON:API `version` attribute is the build number).
    public let buildNumber: String
    public let processingState: String
    public let uploadedDate: String?
    public let expirationDate: String?
    public let minOsVersion: String?

    private enum Attr: String, CodingKey {
        case version, processingState, uploadedDate, expirationDate, minOsVersion
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: ResourceKey.self)
        id = try c.decode(String.self, forKey: .id)
        let a = try c.nestedContainer(keyedBy: Attr.self, forKey: .attributes)
        buildNumber = (try? a.decode(String.self, forKey: .version)) ?? "—"
        processingState = (try? a.decode(String.self, forKey: .processingState)) ?? "UNKNOWN"
        uploadedDate = try? a.decode(String.self, forKey: .uploadedDate)
        expirationDate = try? a.decode(String.self, forKey: .expirationDate)
        minOsVersion = try? a.decode(String.self, forKey: .minOsVersion)
    }
}

public struct ASCVersion: Identifiable, Decodable {
    public let id: String
    public let versionString: String
    public let platform: String?
    public let appStoreState: String?
    public let appVersionState: String?
    public let releaseType: String?
    public let createdDate: String?

    private enum Attr: String, CodingKey {
        case versionString, platform, appStoreState, appVersionState, releaseType, createdDate
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: ResourceKey.self)
        id = try c.decode(String.self, forKey: .id)
        let a = try c.nestedContainer(keyedBy: Attr.self, forKey: .attributes)
        versionString = (try? a.decode(String.self, forKey: .versionString)) ?? "—"
        platform = try? a.decode(String.self, forKey: .platform)
        appStoreState = try? a.decode(String.self, forKey: .appStoreState)
        appVersionState = try? a.decode(String.self, forKey: .appVersionState)
        releaseType = try? a.decode(String.self, forKey: .releaseType)
        createdDate = try? a.decode(String.self, forKey: .createdDate)
    }

    /// The most user-meaningful state for display.
    public var state: String { appStoreState ?? appVersionState ?? "—" }
}

public struct ASCCertificate: Identifiable, Decodable {
    public let id: String
    public let name: String
    public let type: String
    public let displayName: String?
    public let serialNumber: String?
    public let expirationDate: String?

    private enum Attr: String, CodingKey {
        case name, certificateType, displayName, serialNumber, expirationDate
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: ResourceKey.self)
        id = try c.decode(String.self, forKey: .id)
        let a = try c.nestedContainer(keyedBy: Attr.self, forKey: .attributes)
        name = (try? a.decode(String.self, forKey: .name)) ?? "(certificate)"
        type = (try? a.decode(String.self, forKey: .certificateType)) ?? "—"
        displayName = try? a.decode(String.self, forKey: .displayName)
        serialNumber = try? a.decode(String.self, forKey: .serialNumber)
        expirationDate = try? a.decode(String.self, forKey: .expirationDate)
    }
}

public struct ASCProfile: Identifiable, Decodable {
    public let id: String
    public let name: String
    public let type: String
    public let state: String?
    public let expirationDate: String?

    private enum Attr: String, CodingKey {
        case name, profileType, profileState, expirationDate
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: ResourceKey.self)
        id = try c.decode(String.self, forKey: .id)
        let a = try c.nestedContainer(keyedBy: Attr.self, forKey: .attributes)
        name = (try? a.decode(String.self, forKey: .name)) ?? "(profile)"
        type = (try? a.decode(String.self, forKey: .profileType)) ?? "—"
        state = try? a.decode(String.self, forKey: .profileState)
        expirationDate = try? a.decode(String.self, forKey: .expirationDate)
    }
}

public struct ASCBetaGroup: Identifiable, Decodable {
    public let id: String
    public let name: String
    public let isInternal: Bool
    public let hasAccessToAllBuilds: Bool
    public let feedbackEnabled: Bool
    public let createdDate: String?

    private enum Attr: String, CodingKey {
        case name, isInternalGroup, hasAccessToAllBuilds, feedbackEnabled, createdDate
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: ResourceKey.self)
        id = try c.decode(String.self, forKey: .id)
        let a = try c.nestedContainer(keyedBy: Attr.self, forKey: .attributes)
        name = (try? a.decode(String.self, forKey: .name)) ?? "(group)"
        isInternal = a.decodeFlexibleBool(forKey: .isInternalGroup) ?? false
        hasAccessToAllBuilds = a.decodeFlexibleBool(forKey: .hasAccessToAllBuilds) ?? false
        feedbackEnabled = a.decodeFlexibleBool(forKey: .feedbackEnabled) ?? false
        createdDate = try? a.decode(String.self, forKey: .createdDate)
    }
}

public struct ASCBetaTester: Identifiable, Decodable {
    public let id: String
    public let firstName: String?
    public let lastName: String?
    public let email: String?
    public let inviteType: String?
    public let state: String?

    private enum Attr: String, CodingKey {
        case firstName, lastName, email, inviteType, state
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: ResourceKey.self)
        id = try c.decode(String.self, forKey: .id)
        let a = try c.nestedContainer(keyedBy: Attr.self, forKey: .attributes)
        firstName = try? a.decode(String.self, forKey: .firstName)
        lastName = try? a.decode(String.self, forKey: .lastName)
        email = try? a.decode(String.self, forKey: .email)
        inviteType = try? a.decode(String.self, forKey: .inviteType)
        state = try? a.decode(String.self, forKey: .state)
    }

    public var fullName: String {
        [firstName, lastName].compactMap { $0 }.joined(separator: " ")
    }
}

public struct ASCVersionLocalization: Identifiable, Decodable {
    public let id: String
    public let locale: String
    public var description: String?
    public var keywords: String?
    public var whatsNew: String?
    public var promotionalText: String?
    public var supportUrl: String?
    public var marketingUrl: String?

    private enum Attr: String, CodingKey {
        case locale, description, keywords, whatsNew, promotionalText, supportUrl, marketingUrl
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: ResourceKey.self)
        id = try c.decode(String.self, forKey: .id)
        let a = try c.nestedContainer(keyedBy: Attr.self, forKey: .attributes)
        locale = (try? a.decode(String.self, forKey: .locale)) ?? "—"
        description = try? a.decode(String.self, forKey: .description)
        keywords = try? a.decode(String.self, forKey: .keywords)
        whatsNew = try? a.decode(String.self, forKey: .whatsNew)
        promotionalText = try? a.decode(String.self, forKey: .promotionalText)
        supportUrl = try? a.decode(String.self, forKey: .supportUrl)
        marketingUrl = try? a.decode(String.self, forKey: .marketingUrl)
    }
}

public struct ASCBundleId: Identifiable, Decodable {
    public let id: String
    public let identifier: String
    public let name: String
    public let platform: String

    private enum Attr: String, CodingKey { case identifier, name, platform }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: ResourceKey.self)
        id = try c.decode(String.self, forKey: .id)
        let a = try c.nestedContainer(keyedBy: Attr.self, forKey: .attributes)
        identifier = (try? a.decode(String.self, forKey: .identifier)) ?? "—"
        name = (try? a.decode(String.self, forKey: .name)) ?? "—"
        platform = (try? a.decode(String.self, forKey: .platform)) ?? "—"
    }
}

// MARK: - Release status report (custom asc `status` output)

public struct ASCStatusReport: Decodable {
    public struct App: Decodable { public let id: String?; public let bundleId: String?; public let name: String? }
    public struct Summary: Decodable { public let health: String?; public let nextAction: String?; public let blockers: [String]? }
    public struct LatestBuild: Decodable {
        public let id: String?; public let version: String?; public let buildNumber: String?
        public let processingState: String?; public let uploadedDate: String?; public let platform: String?
    }
    public struct Builds: Decodable { public let latest: LatestBuild? }
    public struct TestFlight: Decodable { public let betaReviewState: String?; public let submittedDate: String? }
    public struct AppStore: Decodable {
        public let versionId: String?; public let version: String?; public let state: String?
        public let platform: String?; public let createdDate: String?
    }
    public struct Review: Decodable { public let state: String?; public let submittedDate: String? }
    public struct Phased: Decodable { public let configured: Bool? }
    public struct Links: Decodable { public let appStoreConnect: String?; public let testFlight: String? }

    public let app: App?
    public let summary: Summary?
    public let builds: Builds?
    public let testflight: TestFlight?
    public let appstore: AppStore?
    public let review: Review?
    public let phasedRelease: Phased?
    public let links: Links?
}

// MARK: - Auth status (custom asc output, not JSON:API)

public struct ASCAuthCredential: Identifiable, Decodable, Hashable {
    public var id: String { name }
    public let name: String
    public let keyId: String
    public let isDefault: Bool
    public let storedIn: String?

    enum CodingKeys: String, CodingKey {
        case name, keyId, isDefault, storedIn
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = (try? c.decode(String.self, forKey: .name)) ?? "(unnamed)"
        keyId = (try? c.decode(String.self, forKey: .keyId)) ?? ""
        isDefault = (try? c.decode(Bool.self, forKey: .isDefault)) ?? false
        storedIn = try? c.decode(String.self, forKey: .storedIn)
    }
}

public struct ASCAuthStatus: Decodable {
    public let storageBackend: String?
    public let storageLocation: String?
    public let credentials: [ASCAuthCredential]
    public let environmentCredentialsProvided: Bool?
    public let environmentCredentialsComplete: Bool?

    enum CodingKeys: String, CodingKey {
        case storageBackend, storageLocation, credentials
        case environmentCredentialsProvided, environmentCredentialsComplete
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        storageBackend = try? c.decode(String.self, forKey: .storageBackend)
        storageLocation = try? c.decode(String.self, forKey: .storageLocation)
        credentials = (try? c.decode([ASCAuthCredential].self, forKey: .credentials)) ?? []
        environmentCredentialsProvided = try? c.decode(Bool.self, forKey: .environmentCredentialsProvided)
        environmentCredentialsComplete = try? c.decode(Bool.self, forKey: .environmentCredentialsComplete)
    }
}

// MARK: - Command result

public struct CommandResult {
    public let arguments: [String]
    public let output: String
    public let errorOutput: String
    public let exitCode: Int32

    public init(arguments: [String], output: String, errorOutput: String, exitCode: Int32) {
        self.arguments = arguments
        self.output = output
        self.errorOutput = errorOutput
        self.exitCode = exitCode
    }

    public var succeeded: Bool { exitCode == 0 }

    /// A human-friendly error message, stripped of the leading `Error:` prefix that `asc` emits.
    public var errorMessage: String {
        let trimmed = errorOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return output.isEmpty ? "Command failed (exit code \(exitCode))." : output
        }
        return trimmed
    }
}
