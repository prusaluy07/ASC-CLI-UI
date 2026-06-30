import SwiftUI
import AppKit
import UniformTypeIdentifiers
import ASCShared

/// Scrollable monospaced output panel used by the action-oriented feature screens.
struct OutputPanel: View {
    let title: String
    let text: String
    var maxHeight: CGFloat = 320

    var body: some View {
        GroupBox {
            ScrollView {
                Text(text.isEmpty ? "—" : text)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: maxHeight)
            .padding(6)
        } label: {
            Label(title, systemImage: "doc.plaintext")
        }
    }
}

/// Standard scaffold for action-oriented, optionally app-scoped feature screens.
/// Renders a header, an optional "no app selected" placeholder, an intro line, the caller's
/// controls, and a shared output panel. Owns the `run`/`isRunning`/`output` state and passes a
/// `run` closure plus the current `isRunning` flag down to the content builder.
struct CommandScreen<Content: View>: View {
    @EnvironmentObject var loc: LocalizationManager

    let title: String
    var subtitle: String? = nil
    var intro: String? = nil
    var requireApp: Bool = false
    var hasApp: Bool = true
    var maxContentWidth: CGFloat = .infinity
    @ViewBuilder var content: (_ run: @escaping (@escaping () async -> CommandResult) -> Void, _ isRunning: Bool) -> Content

    @State private var output: String?
    @State private var isRunning = false

    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(title: title, subtitle: subtitle) { EmptyView() }
            Divider()

            if requireApp && !hasApp {
                ContentUnavailableView(loc(.noAppSelectedTitle), systemImage: "questionmark.circle",
                                       description: Text(loc(.selectAppFromApps)))
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let intro { Text(intro).font(.callout).foregroundStyle(.secondary) }
                        content(runOperation, isRunning)
                        if let output { OutputView(text: output) }
                    }
                    .padding(20)
                    .frame(maxWidth: maxContentWidth, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func runOperation(_ operation: @escaping () async -> CommandResult) {
        isRunning = true
        output = nil
        Task {
            let result = await operation()
            output = result.succeeded ? (result.output.isEmpty ? "✓" : result.output) : result.errorMessage
            isRunning = false
        }
    }
}

/// A self-contained, expanded-by-default section that owns and renders its own command
/// output. Stack several of these on a page so related actions (e.g. Groups / Subscriptions /
/// Prices) are all visible at once instead of hidden behind a segmented tab control.
/// Pass `autoRun` to load the section's data automatically when it first appears.
struct CommandSection<Content: View>: View {
    @EnvironmentObject var loc: LocalizationManager
    @AppStorage(AppModeSettings.key) private var appMode = AppMode.online
    let title: String
    var systemImage: String = "list.bullet"
    var autoRun: (() async -> CommandResult)? = nil
    /// When this changes (e.g. the selected app id), `autoRun` runs again so the section
    /// never shows another app's data. Sections without auto-load can leave it empty.
    var autoRunToken: String = ""
    @ViewBuilder var content: (_ run: @escaping (@escaping () async -> CommandResult) -> Void, _ isRunning: Bool) -> Content

    @State private var expanded = true
    @State private var output: String?
    @State private var isRunning = false
    @State private var loadedToken: String?

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 10) {
                content(runOperation, isRunning)
                if isRunning && output == nil {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("…").foregroundStyle(.secondary)
                    }
                }
                if let output { OutputView(text: output) }
            }
            .padding(.top, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label(title, systemImage: systemImage).font(.headline)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.secondary.opacity(0.10)))
        .task(id: autoRunToken) {
            // Offline mode pauses automatic loads; the manual buttons still work.
            if let autoRun, appMode == .online, loadedToken != autoRunToken {
                loadedToken = autoRunToken
                output = nil
                runOperation(autoRun)
            }
        }
    }

    private func runOperation(_ operation: @escaping () async -> CommandResult) {
        isRunning = true
        Task {
            let result = await operation()
            output = result.succeeded ? (result.output.isEmpty ? "✓" : result.output) : result.errorMessage
            isRunning = false
        }
    }
}

/// A simple wrapping (left-to-right, top-to-bottom) layout so rows of buttons
/// reflow onto multiple lines instead of clipping on narrow detail widths.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            sub.place(at: CGPoint(x: bounds.minX + x, y: bounds.minY + y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// Convenience wrapper that lays out a set of buttons/controls in a wrapping row.
struct FlowButtons<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        FlowLayout(spacing: 8) { content() }
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A labeled read-only path row with a "Choose…" button.
struct PathPickerRow: View {
    let label: String
    @Binding var path: String
    var chooseTitle: String
    var pick: () -> String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            HStack {
                Text(path.isEmpty ? "—" : path)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(chooseTitle) {
                    if let picked = pick() { path = picked }
                }
            }
        }
    }
}

enum FilePanel {
    @MainActor
    static func pickFile(extensions: [String]) -> String? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        let types = extensions.compactMap { UTType(filenameExtension: $0) }
        if !types.isEmpty {
            panel.allowedContentTypes = types
            panel.allowsOtherFileTypes = true
        }
        return panel.runModal() == .OK ? panel.url?.path : nil
    }

    @MainActor
    static func pickDirectory(start: String? = nil) -> String? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        if let start { panel.directoryURL = URL(fileURLWithPath: start) }
        return panel.runModal() == .OK ? panel.url?.path : nil
    }
}

extension ASCService.PrefetchSection {
    var locKey: LocKey {
        switch self {
        case .versions:   return .secVersions
        case .builds:     return .secBuilds
        case .testflight: return .secTestFlight
        case .release:    return .secRelease
        }
    }
}

// MARK: - Global online/offline mode

/// AppStorage location for the global ``AppMode`` (online vs. offline). Read with
/// `@AppStorage(AppModeSettings.key) var mode = AppMode.online` anywhere — it propagates to
/// every header badge automatically.
enum AppModeSettings {
    static let key = "asc.globalMode"
}

extension Notification.Name {
    /// Posted (e.g. from the analytics permission banner) to open Settings on the Profiles pane
    /// so the user can assign an Admin/Account Holder key to a role.
    static let ascOpenProfileSettings = Notification.Name("asc.openProfileSettings")
}

extension AppMode {
    /// Header/badge tint per the design: turquoise for online, magenta/pink for offline.
    var tint: Color {
        switch self {
        case .online:  return Color(red: 0.00, green: 0.78, blue: 0.74) // turquoise
        case .offline: return Color(red: 0.90, green: 0.16, blue: 0.55) // magenta / pink
        }
    }
}

/// Small colored capsule embedded in every page header, indicating the active global data
/// mode and toggling it on tap.
struct ModeBadge: View {
    @EnvironmentObject var loc: LocalizationManager
    @AppStorage(AppModeSettings.key) private var mode = AppMode.online

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { mode = mode.toggled }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: mode.iconName).font(.caption2.weight(.bold))
                Text(loc(mode.locKey)).font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundStyle(mode.tint)
            .background(mode.tint.opacity(0.16), in: Capsule())
            .overlay(Capsule().strokeBorder(mode.tint, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help(loc(.modeHeaderHint))
    }
}

/// The primary online/offline selector shown at the top of the Overview, where the global
/// data mode is declared. Updates the same AppStorage value the header badges observe.
struct ModeSelector: View {
    @EnvironmentObject var loc: LocalizationManager
    @AppStorage(AppModeSettings.key) private var mode = AppMode.online

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    ForEach(AppMode.allCases) { option in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) { mode = option }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: option.iconName)
                                Text(loc(option.locKey)).fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .foregroundStyle(mode == option ? option.tint : Color.secondary)
                            .background((mode == option ? option.tint.opacity(0.20) : Color.secondary.opacity(0.08)), in: Capsule())
                            .overlay(Capsule().strokeBorder(mode == option ? option.tint : Color.secondary.opacity(0.20),
                                                            lineWidth: mode == option ? 1.5 : 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text(loc(mode.descriptionKey))
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(6)
        } label: {
            Label(loc(.modeTitle), systemImage: "dot.radiowaves.left.and.right")
        }
    }
}

/// Persists the prefetch preference (stored as a comma-joined raw string in AppStorage).
enum PrefetchSettings {
    static let enabledKey = "asc.prefetchEnabled"
    static let sectionsKey = "asc.prefetchSections"
    static let defaultRaw = "versions,builds,testflight,release"

    static func decode(_ raw: String) -> Set<ASCService.PrefetchSection> {
        Set(raw.split(separator: ",").compactMap { ASCService.PrefetchSection(rawValue: String($0)) })
    }

    static func encode(_ set: Set<ASCService.PrefetchSection>) -> String {
        ASCService.PrefetchSection.allCases.filter { set.contains($0) }.map(\.rawValue).joined(separator: ",")
    }
}

/// Persists the remote-sync (CloudKit mirror) preferences in AppStorage, mirroring the
/// `PrefetchSettings` style. Section encode/decode lives in `MirrorSection` (ASCShared) so
/// it's shared with the future iOS consumer and unit-tested in the package.
enum RemoteSyncSettings {
    static let enabledKey = "asc.remoteSyncEnabled"
    static let intervalKey = "asc.remoteSyncInterval"
    static let sectionsKey = "asc.remoteSyncSections"

    /// Default OFF — sync is purely additive and opt-in.
    static let defaultEnabled = false
    static let defaultInterval = SyncInterval.hourly.rawValue
    static let defaultRaw = MirrorSection.defaultRaw

    static func interval(_ raw: String) -> SyncInterval {
        SyncInterval(rawValue: raw) ?? .hourly
    }
}

/// App metadata shown in Settings → About. `creator` is a plain constant you can edit.
enum AppInfo {
    static var version: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0" }
    static var build: String { Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1" }
    static let creator = ASCAppInfo.creator
    static let license = ASCAppInfo.license
    static let appStoreConnectApps = URL(string: "https://appstoreconnect.apple.com/apps")!
    static let developerIdentifiers = URL(string: "https://developer.apple.com/account/resources/identifiers/list")!
}

/// Common App Store screenshot/preview device types for the media uploader pickers.
enum DeviceType {
    static let all = [
        "IPHONE_67", "IPHONE_69", "IPHONE_65", "IPHONE_61", "IPHONE_58",
        "IPAD_PRO_3GEN_129", "IPAD_PRO_129", "IPAD_109",
        "MAC", "APPLE_TV", "APPLE_VISION_PRO"
    ]
}
