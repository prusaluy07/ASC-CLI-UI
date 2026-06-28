import Foundation

// MARK: - JSON:API envelope

/// App Store Connect (and therefore `asc`) returns JSON:API documents:
/// `{ "data": [ { "id": "...", "type": "...", "attributes": { ... } } ], "meta": { ... } }`
struct ASCListResponse<T: Decodable>: Decodable {
    let data: [T]
    let meta: ASCMeta?
}

struct ASCSingleResponse<T: Decodable>: Decodable {
    let data: T
}

struct ASCMeta: Decodable {
    struct Paging: Decodable {
        let total: Int?
        let limit: Int?
    }
    let paging: Paging?
}

/// Shared coding keys for the JSON:API resource envelope.
private enum ResourceKey: String, CodingKey {
    case id, type, attributes
}

// MARK: - Models

struct ASCApp: Identifiable, Decodable, Hashable {
    let id: String
    let name: String
    let bundleId: String
    let sku: String?
    let primaryLocale: String?

    private enum Attr: String, CodingKey {
        case name, bundleId, sku, primaryLocale
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: ResourceKey.self)
        id = try c.decode(String.self, forKey: .id)
        let a = try c.nestedContainer(keyedBy: Attr.self, forKey: .attributes)
        name = (try? a.decode(String.self, forKey: .name)) ?? "(unnamed)"
        bundleId = (try? a.decode(String.self, forKey: .bundleId)) ?? ""
        sku = try? a.decode(String.self, forKey: .sku)
        primaryLocale = try? a.decode(String.self, forKey: .primaryLocale)
    }
}

struct ASCBuild: Identifiable, Decodable {
    let id: String
    /// The build number (the JSON:API `version` attribute is the build number).
    let buildNumber: String
    let processingState: String
    let uploadedDate: String?
    let expirationDate: String?
    let minOsVersion: String?

    private enum Attr: String, CodingKey {
        case version, processingState, uploadedDate, expirationDate, minOsVersion
    }

    init(from decoder: Decoder) throws {
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

struct ASCVersion: Identifiable, Decodable {
    let id: String
    let versionString: String
    let platform: String?
    let appStoreState: String?
    let appVersionState: String?
    let releaseType: String?
    let createdDate: String?

    private enum Attr: String, CodingKey {
        case versionString, platform, appStoreState, appVersionState, releaseType, createdDate
    }

    init(from decoder: Decoder) throws {
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
    var state: String { appStoreState ?? appVersionState ?? "—" }
}

struct ASCCertificate: Identifiable, Decodable {
    let id: String
    let name: String
    let type: String
    let displayName: String?
    let serialNumber: String?
    let expirationDate: String?

    private enum Attr: String, CodingKey {
        case name, certificateType, displayName, serialNumber, expirationDate
    }

    init(from decoder: Decoder) throws {
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

struct ASCProfile: Identifiable, Decodable {
    let id: String
    let name: String
    let type: String
    let state: String?
    let expirationDate: String?

    private enum Attr: String, CodingKey {
        case name, profileType, profileState, expirationDate
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: ResourceKey.self)
        id = try c.decode(String.self, forKey: .id)
        let a = try c.nestedContainer(keyedBy: Attr.self, forKey: .attributes)
        name = (try? a.decode(String.self, forKey: .name)) ?? "(profile)"
        type = (try? a.decode(String.self, forKey: .profileType)) ?? "—"
        state = try? a.decode(String.self, forKey: .profileState)
        expirationDate = try? a.decode(String.self, forKey: .expirationDate)
    }
}

struct ASCBetaGroup: Identifiable, Decodable {
    let id: String
    let name: String
    let isInternal: Bool
    let hasAccessToAllBuilds: Bool
    let feedbackEnabled: Bool
    let createdDate: String?

    private enum Attr: String, CodingKey {
        case name, isInternalGroup, hasAccessToAllBuilds, feedbackEnabled, createdDate
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: ResourceKey.self)
        id = try c.decode(String.self, forKey: .id)
        let a = try c.nestedContainer(keyedBy: Attr.self, forKey: .attributes)
        name = (try? a.decode(String.self, forKey: .name)) ?? "(group)"
        isInternal = (try? a.decode(Bool.self, forKey: .isInternalGroup)) ?? false
        hasAccessToAllBuilds = (try? a.decode(Bool.self, forKey: .hasAccessToAllBuilds)) ?? false
        feedbackEnabled = (try? a.decode(Bool.self, forKey: .feedbackEnabled)) ?? false
        createdDate = try? a.decode(String.self, forKey: .createdDate)
    }
}

struct ASCBetaTester: Identifiable, Decodable {
    let id: String
    let firstName: String?
    let lastName: String?
    let email: String?
    let inviteType: String?
    let state: String?

    private enum Attr: String, CodingKey {
        case firstName, lastName, email, inviteType, state
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: ResourceKey.self)
        id = try c.decode(String.self, forKey: .id)
        let a = try c.nestedContainer(keyedBy: Attr.self, forKey: .attributes)
        firstName = try? a.decode(String.self, forKey: .firstName)
        lastName = try? a.decode(String.self, forKey: .lastName)
        email = try? a.decode(String.self, forKey: .email)
        inviteType = try? a.decode(String.self, forKey: .inviteType)
        state = try? a.decode(String.self, forKey: .state)
    }

    var fullName: String {
        [firstName, lastName].compactMap { $0 }.joined(separator: " ")
    }
}

struct ASCVersionLocalization: Identifiable, Decodable {
    let id: String
    let locale: String
    var description: String?
    var keywords: String?
    var whatsNew: String?
    var promotionalText: String?
    var supportUrl: String?
    var marketingUrl: String?

    private enum Attr: String, CodingKey {
        case locale, description, keywords, whatsNew, promotionalText, supportUrl, marketingUrl
    }

    init(from decoder: Decoder) throws {
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

struct ASCBundleId: Identifiable, Decodable {
    let id: String
    let identifier: String
    let name: String
    let platform: String

    private enum Attr: String, CodingKey { case identifier, name, platform }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: ResourceKey.self)
        id = try c.decode(String.self, forKey: .id)
        let a = try c.nestedContainer(keyedBy: Attr.self, forKey: .attributes)
        identifier = (try? a.decode(String.self, forKey: .identifier)) ?? "—"
        name = (try? a.decode(String.self, forKey: .name)) ?? "—"
        platform = (try? a.decode(String.self, forKey: .platform)) ?? "—"
    }
}

// MARK: - Release status report (custom asc `status` output)

struct ASCStatusReport: Decodable {
    struct App: Decodable { let id: String?; let bundleId: String?; let name: String? }
    struct Summary: Decodable { let health: String?; let nextAction: String?; let blockers: [String]? }
    struct LatestBuild: Decodable {
        let id: String?; let version: String?; let buildNumber: String?
        let processingState: String?; let uploadedDate: String?; let platform: String?
    }
    struct Builds: Decodable { let latest: LatestBuild? }
    struct TestFlight: Decodable { let betaReviewState: String?; let submittedDate: String? }
    struct AppStore: Decodable {
        let versionId: String?; let version: String?; let state: String?
        let platform: String?; let createdDate: String?
    }
    struct Review: Decodable { let state: String?; let submittedDate: String? }
    struct Phased: Decodable { let configured: Bool? }
    struct Links: Decodable { let appStoreConnect: String?; let testFlight: String? }

    let app: App?
    let summary: Summary?
    let builds: Builds?
    let testflight: TestFlight?
    let appstore: AppStore?
    let review: Review?
    let phasedRelease: Phased?
    let links: Links?
}

// MARK: - Auth status (custom asc output, not JSON:API)

struct ASCAuthCredential: Identifiable, Decodable, Hashable {
    var id: String { name }
    let name: String
    let keyId: String
    let isDefault: Bool
    let storedIn: String?

    enum CodingKeys: String, CodingKey {
        case name, keyId, isDefault, storedIn
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = (try? c.decode(String.self, forKey: .name)) ?? "(unnamed)"
        keyId = (try? c.decode(String.self, forKey: .keyId)) ?? ""
        isDefault = (try? c.decode(Bool.self, forKey: .isDefault)) ?? false
        storedIn = try? c.decode(String.self, forKey: .storedIn)
    }
}

struct ASCAuthStatus: Decodable {
    let storageBackend: String?
    let storageLocation: String?
    let credentials: [ASCAuthCredential]
    let environmentCredentialsProvided: Bool?
    let environmentCredentialsComplete: Bool?

    enum CodingKeys: String, CodingKey {
        case storageBackend, storageLocation, credentials
        case environmentCredentialsProvided, environmentCredentialsComplete
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        storageBackend = try? c.decode(String.self, forKey: .storageBackend)
        storageLocation = try? c.decode(String.self, forKey: .storageLocation)
        credentials = (try? c.decode([ASCAuthCredential].self, forKey: .credentials)) ?? []
        environmentCredentialsProvided = try? c.decode(Bool.self, forKey: .environmentCredentialsProvided)
        environmentCredentialsComplete = try? c.decode(Bool.self, forKey: .environmentCredentialsComplete)
    }
}

// MARK: - Command result

struct CommandResult {
    let arguments: [String]
    let output: String
    let errorOutput: String
    let exitCode: Int32

    var succeeded: Bool { exitCode == 0 }

    /// A human-friendly error message, stripped of the leading `Error:` prefix that `asc` emits.
    var errorMessage: String {
        let trimmed = errorOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return output.isEmpty ? "Command failed (exit code \(exitCode))." : output
        }
        return trimmed
    }
}
