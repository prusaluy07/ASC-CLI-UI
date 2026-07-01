import Foundation
import Combine
import ASCShared

// MARK: - Snapshot engine (Phase 2 producer)

/// Captures App Store Connect data for an app and hands it to the ``CloudKitSync`` uploader.
///
/// Responsibilities:
/// - Runs the read-only `asc` command behind each ``MirrorSection`` (via ``ASCService/run(_:json:)``,
///   which does **not** touch the app's UI caches), wraps each JSON output in a ``Snapshot``
///   with a cheap headline `summary`, and uploads the batch.
/// - Supports on-demand capture ("Sync now") and periodic capture (a timer task).
/// - Coalesces: skips overlapping runs, and throttles automatic (timer/foreground) runs so
///   the CLI is never hammered.
@MainActor
final class SnapshotEngine: ObservableObject {
    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var lastError: String?
    @Published private(set) var lastSyncedSections: [String] = []

    /// App whose data the timer/foreground triggers mirror. Set by the UI as the selection
    /// changes so the background timer always targets the current app.
    var currentAppId: String?

    private let service: ASCService
    private let uploader: CloudKitSync
    private let metricsEngine: MetricsEngine?
    private let marketEngine: MarketEngine?
    private var sections: Set<MirrorSection> = MirrorSection.defaultSelection
    private var timerTask: Task<Void, Never>?

    /// Automatic (non-manual) runs closer together than this are skipped to avoid hammering
    /// the CLI (e.g. repeated app foregrounding).
    private let minimumAutomaticInterval: TimeInterval = 60

    init(service: ASCService,
         uploader: CloudKitSync,
         metricsEngine: MetricsEngine? = nil,
         marketEngine: MarketEngine? = nil) {
        self.service = service
        self.uploader = uploader
        self.metricsEngine = metricsEngine
        self.marketEngine = marketEngine
    }

    // MARK: - Configuration

    /// Applies the current settings: updates the mirrored sections and (re)starts or stops
    /// the periodic timer.
    func configure(enabled: Bool, interval: SyncInterval, sections: Set<MirrorSection>) {
        self.sections = sections
        if enabled {
            startTimer(interval: interval.seconds)
        } else {
            stopTimer()
        }
    }

    private func startTimer(interval: TimeInterval) {
        stopTimer()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                if Task.isCancelled { break }
                guard let self else { break }
                await self.captureCurrent(manual: false)
            }
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }

    // MARK: - Capture

    /// Captures + uploads the current app using the configured sections.
    /// - Parameter manual: when false, throttles against ``minimumAutomaticInterval``.
    func captureCurrent(manual: Bool) async {
        guard let appId = currentAppId, !appId.isEmpty else { return }
        await capture(appId: appId, sections: sections, manual: manual)
    }

    /// Captures + uploads a specific app/section set.
    func capture(appId: String, sections: Set<MirrorSection>, manual: Bool) async {
        guard !sections.isEmpty else { return }
        guard !isSyncing else { return }
        if !manual, let last = lastSyncDate,
           Date().timeIntervalSince(last) < minimumAutomaticInterval {
            return
        }

        isSyncing = true
        defer { isSyncing = false }

        // Resolve the app's display name so the companion can show it instead of the raw id.
        let appName = service.apps.first(where: { $0.id == appId })?.name

        var snapshots: [Snapshot] = []
        // Run sequentially (in a stable order) so we never spawn many CLI processes at once.
        for section in MirrorSection.allCases where sections.contains(section) {
            if let custom = customSnapshot(section: section, appId: appId, appName: appName) {
                snapshots.append(custom)
                continue
            }
            let result = await service.run(arguments(for: section, appId: appId))
            guard result.succeeded else { continue }
            let payload = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !payload.isEmpty else { continue }
            var summary = RemoteMirror.summarize(section: section, payloadJSON: payload)
            if let appName, !appName.isEmpty { summary["appName"] = appName }
            snapshots.append(Snapshot(
                appId: appId,
                section: section.rawValue,
                payloadJSON: payload,
                summary: summary.isEmpty ? nil : summary
            ))
        }

        guard !snapshots.isEmpty else {
            lastError = service.lastError ?? "No data captured."
            return
        }

        switch await uploader.upload(snapshots) {
        case .success:
            lastSyncDate = Date()
            lastError = nil
            lastSyncedSections = snapshots.map(\.section)
        case .failure(let error):
            lastError = CloudKitSync.message(for: error)
        }
    }

    /// Locally sourced sections that don't call the `asc` CLI.
    private func customSnapshot(section: MirrorSection, appId: String, appName: String?) -> Snapshot? {
        switch section {
        case .storedMetrics:
            guard let metricsEngine,
                  let app = service.apps.first(where: { $0.id == appId }),
                  metricsEngine.hasData(for: app) else { return nil }
            let payload = metricsEngine.mirrorPayloadJSON(for: app)
            guard !payload.isEmpty, payload != "{}" else { return nil }
            var summary = RemoteMirror.summarize(section: section, payloadJSON: payload)
            if let appName, !appName.isEmpty { summary["appName"] = appName }
            return Snapshot(appId: appId, section: section.rawValue, payloadJSON: payload,
                            summary: summary.isEmpty ? nil : summary)
        case .marketRank:
            guard let marketEngine,
                  let payload = marketEngine.mirrorRankJSON(forAppleId: appId) else { return nil }
            var summary = RemoteMirror.summarize(section: section, payloadJSON: payload)
            if let appName, !appName.isEmpty { summary["appName"] = appName }
            return Snapshot(appId: appId, section: section.rawValue, payloadJSON: payload,
                            summary: summary.isEmpty ? nil : summary)
        default:
            return nil
        }
    }

    /// Read-only `asc` arguments backing each mirror section. Mirrors the argument lists
    /// used by ``ASCService``'s loaders but goes through `run` directly so the app's
    /// `@Published` caches are never disturbed by a background sync.
    private func arguments(for section: MirrorSection, appId: String) -> [String] {
        switch section {
        case .status:
            return ["status", "--app", appId,
                    "--include", "app,builds,testflight,appstore,submission,review,phased-release,links"]
        case .versions:
            return ["versions", "list", "--app", appId, "--limit", "50"]
        case .builds:
            return ["builds", "list", "--app", appId, "--limit", "50"]
        case .betaGroups:
            return ["testflight", "groups", "list", "--app", appId, "--limit", "200"]
        case .reviews:
            return ["reviews", "ratings", "--app", appId]
        case .pricing:
            return ["pricing", "current", "--app", appId]
        case .subscriptions:
            return ["subscriptions", "groups", "list", "--app", appId]
        case .inAppPurchases:
            return ["iap", "list", "--app", appId, "--pretty"]
        case .analytics:
            return ["insights", "weekly", "--app", appId,
                    "--source", "analytics", "--week", Self.lastCompleteWeekStart()]
        case .storedMetrics, .marketRank:
            return []
        }
    }

    /// `yyyy-MM-dd` for the Monday of the last fully completed ISO week — the same window the
    /// macOS Analytics page defaults to, so the mirrored payload matches what the app shows.
    private static func lastCompleteWeekStart(now: Date = Date()) -> String {
        var cal = Calendar(identifier: .iso8601)
        cal.firstWeekday = 2 // Monday
        let thisWeek = cal.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let lastWeek = cal.date(byAdding: .day, value: -7, to: thisWeek) ?? thisWeek
        let fmt = DateFormatter()
        fmt.calendar = cal
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone(identifier: "UTC")
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: lastWeek)
    }
}
