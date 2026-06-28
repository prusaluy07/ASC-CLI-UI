import Foundation
import Combine

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

// MARK: - ASC Service

@MainActor
final class ASCService: ObservableObject {
    // Configuration
    @Published var ascBinaryPath: String
    @Published var activeProfile: String?

    // Auth state derived from `asc auth status`
    @Published var authStatus: ASCAuthStatus?
    @Published var isConfigured: Bool = false

    // Loaded resources
    @Published var apps: [ASCApp] = []
    @Published var builds: [ASCBuild] = []
    @Published var versions: [ASCVersion] = []
    @Published var certificates: [ASCCertificate] = []
    @Published var profiles: [ASCProfile] = []
    @Published var betaGroups: [ASCBetaGroup] = []
    @Published var betaTesters: [ASCBetaTester] = []
    @Published var versionLocalizations: [ASCVersionLocalization] = []
    @Published var bundleIds: [ASCBundleId] = []
    @Published var statusReport: ASCStatusReport?

    // App ID each app-scoped cache currently represents. Used so views (and the prefetcher)
    // can skip a reload when the cached data already belongs to the selected app.
    @Published private(set) var versionsAppId: String?
    @Published private(set) var buildsAppId: String?
    @Published private(set) var betaGroupsAppId: String?
    @Published private(set) var betaTestersAppId: String?
    @Published private(set) var statusAppId: String?

    // Reports
    @Published var vendorNumber: String
    @Published var reportsDirectory: String

    // Apple Ads (separate Apple Ads OAuth credentials; org used by ads commands)
    @Published var adsOrg: String

    // UI state
    @Published var isLoading: Bool = false
    @Published var lastError: String?

    private let defaults = UserDefaults.standard
    private let binaryPathKey = "asc.binaryPath"
    private let activeProfileKey = "asc.activeProfile"
    private let vendorNumberKey = "asc.vendorNumber"
    private let reportsDirKey = "asc.reportsDir"
    private let adsOrgKey = "asc.adsOrg"

    static var defaultReportsDirectory: String {
        FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path
            ?? (NSHomeDirectory() as NSString).appendingPathComponent("Downloads")
    }

    init() {
        let stored = UserDefaults.standard.string(forKey: binaryPathKey)
        ascBinaryPath = stored ?? Self.findASCBinary()
        activeProfile = UserDefaults.standard.string(forKey: activeProfileKey)
        vendorNumber = UserDefaults.standard.string(forKey: vendorNumberKey) ?? ""
        reportsDirectory = UserDefaults.standard.string(forKey: reportsDirKey) ?? Self.defaultReportsDirectory
        adsOrg = UserDefaults.standard.string(forKey: adsOrgKey) ?? ""
    }

    // MARK: - Settings

    func saveSettings() {
        defaults.set(ascBinaryPath, forKey: binaryPathKey)
        defaults.set(activeProfile, forKey: activeProfileKey)
        defaults.set(vendorNumber, forKey: vendorNumberKey)
        defaults.set(reportsDirectory, forKey: reportsDirKey)
        defaults.set(adsOrg, forKey: adsOrgKey)
    }

    var binaryExists: Bool {
        FileManager.default.fileExists(atPath: ascBinaryPath)
    }

    private static func findASCBinary() -> String {
        let candidates = [
            "/opt/homebrew/bin/asc",
            "/usr/local/bin/asc",
            "/usr/bin/asc"
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0) } ?? "/opt/homebrew/bin/asc"
    }

    // MARK: - Command execution

    /// Runs the `asc` binary with the given arguments.
    /// - Parameters:
    ///   - arguments: subcommand arguments (auth/profile/output flags are added automatically).
    ///   - json: when true, append `--output json` unless the caller already specified `--output`.
    func run(_ arguments: [String], json: Bool = true) async -> CommandResult {
        let binary = ascBinaryPath
        let profile = activeProfile

        // `--profile` is a GLOBAL flag and must appear before the subcommand; subcommands
        // reject it when it comes after them. `auth` commands manage credentials directly
        // and don't accept it at all, so never inject it for them.
        let isAuthCommand = arguments.first == "auth"
        var args: [String] = []
        if let profile, !profile.isEmpty, !isAuthCommand, !arguments.contains("--profile") {
            args += ["--profile", profile]
        }
        args += arguments
        if json, !args.contains("--output") {
            args += ["--output", "json"]
        }

        let finalArgs = args
        return await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: binary)
            process.arguments = finalArgs

            // Ensure Homebrew paths are present so `asc` can find its helpers.
            var env = ProcessInfo.processInfo.environment
            let extraPaths = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
            env["PATH"] = (env["PATH"].map { "\($0):\(extraPaths)" }) ?? extraPaths
            process.environment = env

            let outPipe = Pipe()
            let errPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError = errPipe

            do {
                try process.run()
            } catch {
                return CommandResult(
                    arguments: finalArgs,
                    output: "",
                    errorOutput: "Failed to launch \(binary): \(error.localizedDescription)",
                    exitCode: -1
                )
            }

            // Drain stdout and stderr concurrently; reading one fully before the other can
            // deadlock if the process fills the unread pipe's buffer (~64KB).
            let errHandle = errPipe.fileHandleForReading
            var errData = Data()
            let errQueue = DispatchQueue(label: "asc.stderr.reader")
            let group = DispatchGroup()
            group.enter()
            errQueue.async { errData = errHandle.readDataToEndOfFile(); group.leave() }
            let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            group.wait()
            process.waitUntilExit()

            return CommandResult(
                arguments: finalArgs,
                output: String(data: outData, encoding: .utf8) ?? "",
                errorOutput: String(data: errData, encoding: .utf8) ?? "",
                exitCode: process.terminationStatus
            )
        }.value
    }

    // MARK: - Auth

    /// Refreshes auth status from `asc auth status` and updates `isConfigured`.
    func refreshAuthStatus() async {
        let result = await run(["auth", "status"])
        guard result.succeeded,
              let data = result.output.data(using: .utf8),
              let status = try? JSONDecoder().decode(ASCAuthStatus.self, from: data) else {
            authStatus = nil
            isConfigured = false
            return
        }

        authStatus = status

        // Default the active profile to the credential marked default if none is selected.
        if activeProfile == nil || !(status.credentials.contains { $0.name == activeProfile }) {
            activeProfile = status.credentials.first(where: { $0.isDefault })?.name
                ?? status.credentials.first?.name
            saveSettings()
        }

        isConfigured = !status.credentials.isEmpty
            || (status.environmentCredentialsComplete ?? false)
    }

    func selectProfile(_ name: String) {
        activeProfile = name
        saveSettings()
    }

    /// Registers a new API key with `asc auth login`.
    func login(name: String, keyId: String, issuerId: String, privateKeyPath: String) async -> CommandResult {
        // `asc` rejects .p8 files that are group/world readable. Tighten to owner-only
        // (chmod 600) so login succeeds without manual terminal steps.
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: privateKeyPath)

        let result = await run([
            "auth", "login",
            "--name", name,
            "--key-id", keyId,
            "--issuer-id", issuerId,
            "--private-key", privateKeyPath
        ], json: false)
        if result.succeeded {
            activeProfile = name
            saveSettings()
            await refreshAuthStatus()
        }
        return result
    }

    // MARK: - Data loading

    private func decodeList<T: Decodable>(_ output: String, as type: T.Type) -> [T] {
        guard let data = output.data(using: .utf8) else { return [] }
        let decoder = JSONDecoder()
        if let wrapped = try? decoder.decode(ASCListResponse<T>.self, from: data) {
            return wrapped.data
        }
        // Fall back to a bare array in case a subcommand returns one.
        return (try? decoder.decode([T].self, from: data)) ?? []
    }

    /// Wraps a loading operation with shared `isLoading`/`lastError` handling.
    private func load(_ operation: () async -> CommandResult, onSuccess: (CommandResult) -> Void) async {
        isLoading = true
        lastError = nil
        let result = await operation()
        isLoading = false
        if result.succeeded {
            onSuccess(result)
        } else {
            lastError = result.errorMessage
        }
    }

    func loadApps() async {
        await load({ await run(["apps", "list", "--limit", "200", "--sort", "name"]) }) { result in
            apps = decodeList(result.output, as: ASCApp.self)
        }
    }

    func loadBuilds(for appId: String) async {
        await load({ await run(["builds", "list", "--app", appId, "--limit", "50"]) }) { result in
            builds = decodeList(result.output, as: ASCBuild.self)
            buildsAppId = appId
        }
    }

    func loadVersions(for appId: String) async {
        await load({ await run(["versions", "list", "--app", appId, "--limit", "50"]) }) { result in
            versions = decodeList(result.output, as: ASCVersion.self)
            versionsAppId = appId
        }
    }

    func loadCertificates() async {
        await load({ await run(["certificates", "list", "--limit", "200"]) }) { result in
            certificates = decodeList(result.output, as: ASCCertificate.self)
        }
    }

    func loadProfiles() async {
        await load({ await run(["profiles", "list", "--limit", "200"]) }) { result in
            profiles = decodeList(result.output, as: ASCProfile.self)
        }
    }

    // MARK: - TestFlight

    func loadBetaGroups(for appId: String) async {
        await load({ await run(["testflight", "groups", "list", "--app", appId, "--limit", "200"]) }) { result in
            betaGroups = decodeList(result.output, as: ASCBetaGroup.self)
            betaGroupsAppId = appId
        }
    }

    func loadBetaTesters(for appId: String) async {
        await load({ await run(["testflight", "testers", "list", "--app", appId, "--limit", "200"]) }) { result in
            betaTesters = decodeList(result.output, as: ASCBetaTester.self)
            betaTestersAppId = appId
        }
    }

    /// Notifies testers that a build is available. This is a mutating action.
    func sendBuildNotification(buildId: String) async -> CommandResult {
        await run(["testflight", "notifications", "send", "--build-id", buildId], json: false)
    }

    // MARK: - Metadata / localizations

    func loadVersionLocalizations(versionId: String) async {
        await load({ await run(["localizations", "list", "--version", versionId]) }) { result in
            versionLocalizations = decodeList(result.output, as: ASCVersionLocalization.self)
        }
    }

    /// Updates version localization fields. Only non-nil fields are sent.
    func updateLocalization(
        versionId: String,
        locale: String,
        description: String?,
        keywords: String?,
        whatsNew: String?,
        promotionalText: String?,
        supportUrl: String?,
        marketingUrl: String?
    ) async -> CommandResult {
        var args = ["localizations", "update", "--version", versionId, "--locale", locale]
        func add(_ flag: String, _ value: String?) {
            if let value { args += [flag, value] }
        }
        add("--description", description)
        add("--keywords", keywords)
        add("--whats-new", whatsNew)
        add("--promotional-text", promotionalText)
        add("--support-url", supportUrl)
        add("--marketing-url", marketingUrl)
        return await run(args)
    }

    // MARK: - Release / status

    func loadStatus(for appId: String) async {
        await load({ await run(["status", "--app", appId,
                                "--include", "app,builds,testflight,appstore,submission,review,phased-release,links"]) }) { result in
            if let data = result.output.data(using: .utf8) {
                statusReport = try? JSONDecoder().decode(ASCStatusReport.self, from: data)
            }
            statusAppId = appId
        }
    }

    // MARK: - Prefetch

    /// Sections whose data can be warmed ahead of time so navigating between tabs is instant.
    enum PrefetchSection: String, CaseIterable, Identifiable {
        case versions, builds, testflight, release
        var id: String { rawValue }
    }

    // In-flight loads, so the prefetcher and a tab that opens mid-prefetch share the
    // same request instead of firing a second one (which caused tabs to reload on click).
    private var versionsTask: Task<Void, Never>?
    private var buildsTask: Task<Void, Never>?
    private var betaGroupsTask: Task<Void, Never>?
    private var betaTestersTask: Task<Void, Never>?
    private var statusTask: Task<Void, Never>?

    /// Loads versions only if the cache isn't already for `appId`; coalesces concurrent calls.
    func ensureVersions(for appId: String) async {
        if versionsAppId == appId { return }
        if let t = versionsTask { await t.value; if versionsAppId == appId { return } }
        let task = Task { await loadVersions(for: appId) }
        versionsTask = task
        await task.value
        if versionsTask == task { versionsTask = nil }
    }
    func ensureBuilds(for appId: String) async {
        if buildsAppId == appId { return }
        if let t = buildsTask { await t.value; if buildsAppId == appId { return } }
        let task = Task { await loadBuilds(for: appId) }
        buildsTask = task
        await task.value
        if buildsTask == task { buildsTask = nil }
    }
    func ensureBetaGroups(for appId: String) async {
        if betaGroupsAppId == appId { return }
        if let t = betaGroupsTask { await t.value; if betaGroupsAppId == appId { return } }
        let task = Task { await loadBetaGroups(for: appId) }
        betaGroupsTask = task
        await task.value
        if betaGroupsTask == task { betaGroupsTask = nil }
    }
    func ensureBetaTesters(for appId: String) async {
        if betaTestersAppId == appId { return }
        if let t = betaTestersTask { await t.value; if betaTestersAppId == appId { return } }
        let task = Task { await loadBetaTesters(for: appId) }
        betaTestersTask = task
        await task.value
        if betaTestersTask == task { betaTestersTask = nil }
    }
    func ensureStatus(for appId: String) async {
        if statusAppId == appId { return }
        if let t = statusTask { await t.value; if statusAppId == appId { return } }
        let task = Task { await loadStatus(for: appId) }
        statusTask = task
        await task.value
        if statusTask == task { statusTask = nil }
    }

    /// Pre-loads the selected app-scoped sections. Uses the `ensure*` coalescing loaders,
    /// so a tab opened during prefetch reuses the in-flight request instead of reloading.
    func prefetch(appId: String, sections: Set<PrefetchSection>) async {
        if sections.contains(.versions) { await ensureVersions(for: appId) }
        if sections.contains(.builds) || sections.contains(.testflight) { await ensureBuilds(for: appId) }
        if sections.contains(.testflight) {
            await ensureBetaGroups(for: appId)
            await ensureBetaTesters(for: appId)
        }
        if sections.contains(.release) { await ensureStatus(for: appId) }
    }

    func validate(appId: String, versionId: String) async -> CommandResult {
        await run(["validate", "--app", appId, "--version-id", versionId], json: false)
    }

    /// Releases an approved version that is pending developer release. Mutating + requires --confirm.
    func releaseVersion(versionId: String) async -> CommandResult {
        await run(["versions", "release", "--version-id", versionId, "--confirm"], json: false)
    }

    // MARK: - Reports

    func analyticsRequests(appId: String) async -> CommandResult {
        await run(["analytics", "requests", "--app", appId, "--pretty"])
    }

    func createAnalyticsRequest(appId: String) async -> CommandResult {
        await run(["analytics", "request", "--app", appId, "--access-type", "ONGOING", "--reuse-existing"], json: false)
    }

    func salesReport(date: String, frequency: String, outputPath: String?, decompress: Bool) async -> CommandResult {
        var args = ["analytics", "sales", "--vendor", vendorNumber,
                    "--type", "SALES", "--subtype", "SUMMARY",
                    "--frequency", frequency, "--date", date]
        if let outputPath { args += ["--output", outputPath] }
        if decompress { args.append("--decompress") }
        return await run(args, json: false)
    }

    func financeReport(date: String, region: String, outputPath: String?, decompress: Bool) async -> CommandResult {
        var args = ["finance", "reports", "--vendor", vendorNumber,
                    "--report-type", "FINANCIAL", "--region", region, "--date", date]
        if let outputPath { args += ["--output", outputPath] }
        if decompress { args.append("--decompress") }
        return await run(args, json: false)
    }

    func financeRegions() async -> CommandResult {
        await run(["finance", "regions", "--output", "table"], json: false)
    }

    // MARK: - Build upload & publish

    func uploadBuild(appId: String, ipaPath: String?, pkgPath: String?,
                     version: String, buildNumber: String, dryRun: Bool) async -> CommandResult {
        var args = ["builds", "upload", "--app", appId]
        if let ipaPath, !ipaPath.isEmpty { args += ["--ipa", ipaPath] }
        if let pkgPath, !pkgPath.isEmpty { args += ["--pkg", pkgPath] }
        if !version.isEmpty { args += ["--version", version] }
        if !buildNumber.isEmpty { args += ["--build-number", buildNumber] }
        if dryRun { args.append("--dry-run") }
        return await run(args, json: false)
    }

    func publishAppStore(appId: String, ipaPath: String, version: String,
                         metadataDir: String?, submit: Bool, dryRun: Bool) async -> CommandResult {
        var args = ["publish", "appstore", "--app", appId, "--ipa", ipaPath, "--version", version]
        if let metadataDir, !metadataDir.isEmpty { args += ["--metadata-dir", metadataDir] }
        if submit {
            args.append("--submit")
            args.append(dryRun ? "--dry-run" : "--confirm")
        } else if dryRun {
            args.append("--dry-run")
        }
        return await run(args, json: false)
    }

    func publishTestFlight(appId: String, ipaPath: String, groupId: String?) async -> CommandResult {
        var args = ["publish", "testflight", "--app", appId, "--ipa", ipaPath]
        if let groupId, !groupId.isEmpty { args += ["--group", groupId] }
        return await run(args, json: false)
    }

    // MARK: - Metadata files

    func metadataPull(appId: String, version: String, dir: String) async -> CommandResult {
        await run(["metadata", "pull", "--app", appId, "--version", version, "--dir", dir], json: false)
    }

    func metadataApply(appId: String, version: String, dir: String, dryRun: Bool) async -> CommandResult {
        var args = ["metadata", "apply", "--app", appId, "--version", version, "--dir", dir]
        if dryRun { args.append("--dry-run") }
        return await run(args, json: false)
    }

    func metadataValidate(dir: String) async -> CommandResult {
        await run(["metadata", "validate", "--dir", dir], json: false)
    }

    // MARK: - Media (screenshots & video previews)

    func screenshotsList(versionLocalizationId: String) async -> CommandResult {
        await run(["screenshots", "list", "--version-localization", versionLocalizationId, "--pretty"])
    }

    func screenshotSizes() async -> CommandResult {
        await run(["screenshots", "sizes", "--output", "table"], json: false)
    }

    func screenshotsUpload(versionLocalizationId: String, path: String, deviceType: String) async -> CommandResult {
        await run(["screenshots", "upload", "--version-localization", versionLocalizationId,
                   "--path", path, "--device-type", deviceType], json: false)
    }

    func screenshotsDownload(versionLocalizationId: String, outputDir: String) async -> CommandResult {
        await run(["screenshots", "download", "--version-localization", versionLocalizationId,
                   "--output-dir", outputDir], json: false)
    }

    func videoPreviewsList(versionLocalizationId: String) async -> CommandResult {
        await run(["video-previews", "list", "--version-localization", versionLocalizationId, "--pretty"])
    }

    func videoPreviewsUpload(versionLocalizationId: String, path: String, deviceType: String) async -> CommandResult {
        await run(["video-previews", "upload", "--version-localization", versionLocalizationId,
                   "--path", path, "--device-type", deviceType], json: false)
    }

    func videoPreviewsDownload(versionLocalizationId: String, outputDir: String) async -> CommandResult {
        await run(["video-previews", "download", "--version-localization", versionLocalizationId,
                   "--output-dir", outputDir], json: false)
    }

    // MARK: - Discover (search / schema / capabilities)

    func searchCommands(_ query: String) async -> CommandResult {
        await run(["search", "--output", "table", query], json: false)
    }

    func schemaLookup(_ query: String) async -> CommandResult {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return await run(["schema", "--list"], json: false) }
        return await run(["schema", trimmed, "--pretty"], json: false)
    }

    func capabilities() async -> CommandResult {
        await run(["capabilities", "--output", "table"], json: false)
    }

    // MARK: - Xcode Cloud

    func xcWorkflows(appId: String) async -> CommandResult {
        await run(["xcode-cloud", "workflows", "--app", appId, "--pretty"])
    }

    func xcRun(appId: String, workflow: String, branch: String, wait: Bool) async -> CommandResult {
        var args = ["xcode-cloud", "run", "--app", appId, "--workflow", workflow, "--branch", branch]
        if wait { args.append("--wait") }
        return await run(args, json: false)
    }

    func xcStatus(runId: String, wait: Bool) async -> CommandResult {
        var args = ["xcode-cloud", "status", "--run-id", runId]
        if wait { args.append("--wait") }
        return await run(args, json: false)
    }

    // MARK: - Bundle IDs & notarization

    func loadBundleIds() async {
        await load({ await run(["bundle-ids", "list", "--limit", "200"]) }) { result in
            bundleIds = decodeList(result.output, as: ASCBundleId.self)
        }
    }

    func notarizationList() async -> CommandResult {
        await run(["notarization", "list", "--pretty"])
    }

    func notarizationSubmit(file: String, wait: Bool) async -> CommandResult {
        var args = ["notarization", "submit", "--file", file]
        if wait { args.append("--wait") }
        return await run(args, json: false)
    }

    func notarizationStatus(id: String) async -> CommandResult {
        await run(["notarization", "status", "--id", id], json: false)
    }

    // MARK: - TestFlight feedback & crashes

    func testflightFeedbackList(appId: String, includeScreenshots: Bool) async -> CommandResult {
        var args = ["testflight", "feedback", "list", "--app", appId,
                    "--output", "table", "--limit", "100", "--sort", "-createdDate"]
        if includeScreenshots { args.append("--include-screenshots") }
        return await run(args, json: false)
    }

    func testflightCrashesList(appId: String) async -> CommandResult {
        await run(["testflight", "crashes", "list", "--app", appId,
                   "--output", "table", "--limit", "100"], json: false)
    }

    func testflightCrashLog(submissionId: String) async -> CommandResult {
        await run(["testflight", "crashes", "log", "--submission-id", submissionId], json: false)
    }

    // MARK: - Workflow automation (repo-local .asc/workflow.json)

    func workflowList(file: String?) async -> CommandResult {
        var args = ["workflow", "list", "--all", "--pretty"]
        if let file, !file.isEmpty { args += ["--file", file] }
        return await run(args, json: false)
    }

    func workflowValidate(file: String?) async -> CommandResult {
        var args = ["workflow", "validate", "--pretty"]
        if let file, !file.isEmpty { args += ["--file", file] }
        return await run(args, json: false)
    }

    /// Runs (or resumes) a named workflow. Workflows execute arbitrary shell — callers gate this behind a confirmation.
    func workflowRun(name: String, file: String?, params: [String], dryRun: Bool, resume: String?) async -> CommandResult {
        var args = ["workflow", "run", "--pretty"]
        if let file, !file.isEmpty { args += ["--file", file] }
        if dryRun { args.append("--dry-run") }
        let isResume = (resume?.isEmpty == false)
        if let resume, isResume { args += ["--resume", resume] }
        args.append(name)
        // --resume reuses the saved params; passing extra KEY:VALUE is rejected.
        if !isResume { args += params }
        return await run(args, json: false)
    }

    // MARK: - Apple Ads (separate Apple Ads OAuth credentials)

    func adsAuthStatus() async -> CommandResult {
        await run(["ads", "auth", "status", "--output", "table"], json: false)
    }

    func adsAuthDiscover() async -> CommandResult {
        await run(["ads", "auth", "discover", "--output", "table"], json: false)
    }

    func adsLogin(name: String, clientId: String, teamId: String, keyId: String,
                  privateKeyPath: String, org: String) async -> CommandResult {
        // Apple Ads private keys (EC PEM) must not be group/world readable either.
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: privateKeyPath)
        var args = ["ads", "auth", "login",
                    "--name", name, "--client-id", clientId, "--team-id", teamId,
                    "--key-id", keyId, "--private-key", privateKeyPath]
        if !org.isEmpty { args += ["--org", org] }
        return await run(args, json: false)
    }

    func adsViewMe() async -> CommandResult {
        await run(["ads", "me", "view", "--output", "table"], json: false)
    }

    func adsCampaignsList(org: String) async -> CommandResult {
        await run(["ads", "campaigns", "list", "--org", org, "--output", "table", "--limit", "100"], json: false)
    }

    func adsAdGroupsList(org: String, campaign: String) async -> CommandResult {
        await run(["ads", "ad-groups", "list", "--org", org, "--campaign", campaign,
                   "--output", "table", "--limit", "100"], json: false)
    }

    func adsTargetingKeywords(org: String, campaign: String, adGroup: String) async -> CommandResult {
        await run(["ads", "targeting-keywords", "list", "--org", org,
                   "--campaign", campaign, "--ad-group", adGroup,
                   "--output", "table", "--limit", "100"], json: false)
    }

    func adsReportCampaigns(org: String, payloadFile: String) async -> CommandResult {
        await run(["ads", "reports", "campaigns", "--org", org, "--file", payloadFile, "--output", "table"], json: false)
    }

    // MARK: - Marketplace & alternative distribution

    func altDistDomainsList() async -> CommandResult {
        await run(["alternative-distribution", "domains", "list", "--pretty"])
    }

    func altDistKeysList() async -> CommandResult {
        await run(["alternative-distribution", "keys", "list", "--pretty"])
    }

    func altDistKeyForApp(appId: String) async -> CommandResult {
        await run(["alternative-distribution", "keys", "app", "--app", appId, "--pretty"])
    }

    func altDistPackageView(packageId: String) async -> CommandResult {
        await run(["alternative-distribution", "packages", "view", "--package-id", packageId, "--pretty"])
    }

    func marketplaceWebhooksList() async -> CommandResult {
        await run(["marketplace", "webhooks", "list", "--pretty"])
    }

    func marketplaceSearchDetails(appId: String) async -> CommandResult {
        await run(["marketplace", "search-details", "view", "--app", appId, "--pretty"])
    }

    // MARK: - Skills

    /// Installs the asc agent skill pack (`asc install-skills`).
    func installSkills() async -> CommandResult {
        await run(["install-skills"], json: false)
    }

    // MARK: - Pricing & availability

    func pricingCurrent(appId: String) async -> CommandResult {
        await run(["pricing", "current", "--app", appId, "--pretty"])
    }
    func pricingTerritories() async -> CommandResult {
        await run(["pricing", "territories", "list", "--pretty"])
    }
    func pricingPricePoints(appId: String) async -> CommandResult {
        await run(["pricing", "price-points", "--app", appId, "--pretty"])
    }
    func pricingSchedule(appId: String) async -> CommandResult {
        await run(["pricing", "schedule", "view", "--app", appId, "--pretty"])
    }
    func pricingAvailability(appId: String) async -> CommandResult {
        await run(["pricing", "availability", "view", "--app", appId, "--pretty"])
    }

    // MARK: - Customer reviews

    func reviewsList(appId: String, stars: Int?, territory: String, onlyUnresponded: Bool) async -> CommandResult {
        var args = ["reviews", "--app", appId, "--output", "table", "--limit", "50", "--sort", "-createdDate"]
        if let stars { args += ["--stars", String(stars)] }
        if !territory.isEmpty { args += ["--territory", territory] }
        if onlyUnresponded { args.append("--only-unresponded") }
        return await run(args, json: false)
    }
    func reviewsRatings(appId: String) async -> CommandResult {
        await run(["reviews", "ratings", "--app", appId, "--output", "table"], json: false)
    }
    func reviewRespond(reviewId: String, text: String) async -> CommandResult {
        await run(["reviews", "respond", "--review-id", reviewId, "--response", text], json: false)
    }

    // MARK: - Subscriptions

    func subscriptionGroups(appId: String) async -> CommandResult {
        await run(["subscriptions", "groups", "list", "--app", appId, "--pretty"])
    }
    func subscriptionsList(groupId: String) async -> CommandResult {
        await run(["subscriptions", "list", "--group-id", groupId, "--pretty"])
    }
    func subscriptionsPricing(appId: String) async -> CommandResult {
        await run(["subscriptions", "pricing", "summary", "--app", appId, "--pretty"])
    }

    // MARK: - In-app purchases

    func iapList(appId: String) async -> CommandResult {
        await run(["iap", "list", "--app", appId, "--pretty"])
    }
    func iapPricing(appId: String) async -> CommandResult {
        await run(["iap", "pricing", "summary", "--app", appId, "--pretty"])
    }
    func iapView(id: String) async -> CommandResult {
        await run(["iap", "view", "--id", id, "--pretty"])
    }

    // MARK: - In-app events

    func appEventsList(appId: String) async -> CommandResult {
        await run(["app-events", "list", "--app", appId, "--output", "table"], json: false)
    }
    func appEventView(eventId: String) async -> CommandResult {
        await run(["app-events", "view", "--event-id", eventId, "--pretty"])
    }

    // MARK: - Submission / App Review lifecycle

    func reviewStatus(appId: String) async -> CommandResult {
        await run(["review", "status", "--app", appId], json: false)
    }
    func reviewDoctor(appId: String) async -> CommandResult {
        await run(["review", "doctor", "--app", appId], json: false)
    }
    func reviewDetailsForVersion(versionId: String) async -> CommandResult {
        await run(["review", "details-for-version", "--version-id", versionId, "--pretty"])
    }
    func reviewAttachments(detailId: String) async -> CommandResult {
        await run(["review", "attachments-list", "--review-detail", detailId, "--pretty"])
    }
    func reviewSubmissionsList(appId: String) async -> CommandResult {
        await run(["review", "submissions-list", "--app", appId, "--pretty"])
    }
    func reviewSubmissionsCreate(appId: String, platform: String) async -> CommandResult {
        await run(["review", "submissions-create", "--app", appId, "--platform", platform], json: false)
    }
    func reviewSubmissionsSubmit(submissionId: String) async -> CommandResult {
        await run(["review", "submissions-submit", "--id", submissionId, "--confirm"], json: false)
    }
    func reviewSubmissionsCancel(submissionId: String) async -> CommandResult {
        await run(["review", "submissions-update", "--id", submissionId, "--canceled=true"], json: false)
    }
    func buildLocalizationsList(buildId: String) async -> CommandResult {
        await run(["build-localizations", "list", "--build", buildId, "--pretty"])
    }
    func releaseNotesGenerate(sinceTag: String) async -> CommandResult {
        await run(["release-notes", "generate", "--since-tag", sinceTag, "--output", "markdown"], json: false)
    }

    // MARK: - Compliance (age rating, encryption, categories, EULA, tags)

    func ageRatingView(appId: String) async -> CommandResult {
        await run(["age-rating", "view", "--app", appId, "--pretty"])
    }
    func encryptionDeclarations(appId: String) async -> CommandResult {
        await run(["encryption", "declarations", "list", "--app", appId, "--pretty"])
    }
    func categoriesList() async -> CommandResult {
        await run(["categories", "list", "--output", "table"], json: false)
    }
    func categoriesSet(appId: String, primary: String, secondary: String) async -> CommandResult {
        var args = ["categories", "set", "--app", appId, "--primary", primary]
        if !secondary.isEmpty { args += ["--secondary", secondary] }
        return await run(args, json: false)
    }
    func eulaView(appId: String) async -> CommandResult {
        await run(["eula", "view", "--app", appId, "--pretty"])
    }
    func appTagsList(appId: String) async -> CommandResult {
        await run(["app-tags", "list", "--app", appId, "--pretty"])
    }

    // MARK: - Marketing (custom product pages, experiments, pre-orders, nominations)

    func customPagesList(appId: String) async -> CommandResult {
        await run(["product-pages", "custom-pages", "list", "--app", appId, "--pretty"])
    }
    func customPageView(pageId: String) async -> CommandResult {
        await run(["product-pages", "custom-pages", "view", "--custom-page-id", pageId, "--pretty"])
    }
    /// Mutating: creates a new custom product page.
    func customPageCreate(appId: String, name: String) async -> CommandResult {
        await run(["product-pages", "custom-pages", "create", "--app", appId, "--name", name], json: false)
    }
    /// Lists product page optimization experiments (v2, scoped by app).
    func experimentsList(appId: String) async -> CommandResult {
        await run(["product-pages", "experiments", "list", "--v2", "--app", appId, "--pretty"])
    }
    /// Lists v1 experiments scoped by an App Store version.
    func experimentsListByVersion(versionId: String) async -> CommandResult {
        await run(["product-pages", "experiments", "list", "--version-id", versionId, "--pretty"])
    }

    func preOrderView(appId: String) async -> CommandResult {
        await run(["pre-orders", "view", "--app", appId, "--pretty"])
    }
    /// Mutating: enables pre-orders for one or more territories.
    func preOrderEnable(appId: String, territories: String, releaseDate: String) async -> CommandResult {
        var args = ["pre-orders", "enable", "--app", appId, "--territory", territories]
        if !releaseDate.isEmpty { args += ["--release-date", releaseDate] }
        return await run(args, json: false)
    }
    /// Mutating: disables pre-orders for a territory availability.
    func preOrderDisable(territoryAvailabilityId: String) async -> CommandResult {
        await run(["pre-orders", "disable", "--territory-availability", territoryAvailabilityId], json: false)
    }

    func nominationsList(status: String) async -> CommandResult {
        var args = ["nominations", "list", "--pretty"]
        if !status.isEmpty { args += ["--status", status] }
        return await run(args)
    }
    func nominationView(id: String) async -> CommandResult {
        await run(["nominations", "view", "--id", id, "--pretty"])
    }
    /// Mutating: creates a featuring nomination (saved as draft unless submitted).
    func nominationCreate(appId: String, name: String, type: String, description: String, submitted: Bool) async -> CommandResult {
        var args = ["nominations", "create", "--app", appId, "--name", name, "--type", type]
        if !description.isEmpty { args += ["--description", description] }
        args.append(submitted ? "--submitted=true" : "--submitted=false")
        return await run(args, json: false)
    }
    /// Mutating: deletes a featuring nomination.
    func nominationDelete(id: String) async -> CommandResult {
        await run(["nominations", "delete", "--id", id, "--confirm"], json: false)
    }

    // MARK: - Team & devices

    func usersList() async -> CommandResult {
        await run(["users", "list", "--output", "table"], json: false)
    }
    func usersInvite(email: String, roles: String, allApps: Bool) async -> CommandResult {
        var args = ["users", "invite", "--email", email, "--roles", roles]
        if allApps { args.append("--all-apps") }
        return await run(args, json: false)
    }
    func devicesList() async -> CommandResult {
        await run(["devices", "list", "--output", "table"], json: false)
    }
    func deviceLocalUdid() async -> CommandResult {
        await run(["devices", "local-udid"], json: false)
    }
    func deviceRegister(name: String, udid: String, platform: String) async -> CommandResult {
        await run(["devices", "register", "--name", name, "--udid", udid, "--platform", platform], json: false)
    }
    func sandboxList() async -> CommandResult {
        await run(["sandbox", "list", "--output", "table"], json: false)
    }

    // MARK: - Tools (account, diagnostics, webhooks, fastlane)

    func accountStatus(appId: String?) async -> CommandResult {
        var args = ["account", "status", "--output", "table"]
        if let appId, !appId.isEmpty { args += ["--app", appId] }
        return await run(args, json: false)
    }
    func authDoctor() async -> CommandResult {
        await run(["auth", "doctor"], json: false)
    }
    func webhooksList(appId: String) async -> CommandResult {
        await run(["webhooks", "list", "--app", appId, "--pretty"])
    }
    func webhookPing(webhookId: String) async -> CommandResult {
        await run(["webhooks", "ping", "--webhook-id", webhookId], json: false)
    }
    func webhookDeliveries(webhookId: String) async -> CommandResult {
        await run(["webhooks", "deliveries", "--webhook-id", webhookId, "--pretty"])
    }
    func migrateImport(appId: String, versionId: String, fastlaneDir: String) async -> CommandResult {
        await run(["migrate", "import", "--app", appId, "--version", versionId, "--fastlane-dir", fastlaneDir], json: false)
    }
    func migrateExport(appId: String, versionId: String, outputDir: String) async -> CommandResult {
        await run(["migrate", "export", "--app", appId, "--version", versionId, "--output-dir", outputDir], json: false)
    }

    // MARK: - Analytics dashboard (insights + compare)

    /// Weekly insights (this week vs last week). `source` is "analytics" or "sales".
    /// Sales source needs the vendor number, which is injected automatically when set.
    func insightsWeekly(appId: String, source: String, week: String) async -> CommandResult {
        var args = ["insights", "weekly", "--app", appId, "--source", source, "--week", week]
        if source == "sales", !vendorNumber.isEmpty { args += ["--vendor", vendorNumber] }
        return await run(args)
    }

    /// Aggregated sales comparison between two date ranges (e.g. last 30 days vs the previous 30).
    func analyticsCompareSales(appId: String, from: String, fromEnd: String,
                               to: String, toEnd: String, frequency: String = "DAILY") async -> CommandResult {
        var args = ["analytics", "compare", "--source", "sales", "--app", appId,
                    "--from", from, "--from-end", fromEnd, "--to", to, "--to-end", toEnd,
                    "--frequency", frequency]
        if !vendorNumber.isEmpty { args += ["--vendor", vendorNumber] }
        return await run(args)
    }
}
