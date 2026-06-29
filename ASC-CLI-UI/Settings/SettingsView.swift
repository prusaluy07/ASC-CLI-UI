import SwiftUI
import ASCShared
import UniformTypeIdentifiers

// MARK: - Settings panes

enum SettingsPane: String, CaseIterable, Identifiable {
    case language, profiles, profileRoles, binary, connection, prefetch, remoteSync, onboarding, about

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .language:     return "globe"
        case .profiles:     return "key"
        case .profileRoles: return "person.2.badge.gearshape"
        case .binary:       return "terminal"
        case .connection:   return "network"
        case .prefetch:     return "arrow.down.circle"
        case .remoteSync:   return "icloud"
        case .onboarding:   return "book"
        case .about:        return "info.circle"
        }
    }

    func title(_ loc: LocalizationManager) -> String {
        switch self {
        case .language:     return loc(.secLanguage)
        case .profiles:     return loc(.authProfiles)
        case .profileRoles: return loc(.profileRolesSection)
        case .binary:       return loc(.ascBinary)
        case .connection:   return loc(.connection)
        case .prefetch:     return loc(.secPrefetch)
        case .remoteSync:   return loc(.secRemoteSync)
        case .onboarding:   return loc(.onboardingSection)
        case .about:        return loc(.secAbout)
        }
    }
}

enum SettingsPresentation {
    case sheet
    case preferences
}

// MARK: - Root

struct SettingsView: View {
    var presentation: SettingsPresentation = .sheet

    @EnvironmentObject var ascService: ASCService
    @EnvironmentObject var loc: LocalizationManager
    @EnvironmentObject var syncEngine: SnapshotEngine
    @Environment(\.dismiss) private var dismiss

    @State private var selection: SettingsPane = .language
    @State private var showAddKey = false

    var body: some View {
        Group {
            if presentation == .sheet {
                sheetChrome
            } else {
                splitView
            }
        }
        .task { await ascService.refreshAuthStatus() }
        .sheet(isPresented: $showAddKey) {
            AddKeyView()
                .environmentObject(ascService)
                .environmentObject(loc)
        }
    }

    private var sheetChrome: some View {
        VStack(spacing: 0) {
            HStack {
                Text(loc(.settingsTitle))
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider()
            splitView
            Divider()

            HStack {
                Button(loc(.refresh)) {
                    Task { await ascService.refreshAuthStatus() }
                }
                Spacer()
                Button(loc(.done)) {
                    ascService.saveSettings()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return)
            }
            .padding(16)
        }
        .frame(width: 760, height: 560)
    }

    private var splitView: some View {
        NavigationSplitView {
            List(SettingsPane.allCases, selection: $selection) { pane in
                Label(pane.title(loc), systemImage: pane.icon)
                    .tag(pane)
            }
            .listStyle(.sidebar)
            .navigationTitle(loc(.settingsTitle))
            .frame(minWidth: 200)
        } detail: {
            SettingsPaneDetail(pane: selection, showAddKey: $showAddKey)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .navigationSplitViewStyle(.balanced)
    }
}

// MARK: - Detail router

private struct SettingsPaneDetail: View {
    let pane: SettingsPane
    @Binding var showAddKey: Bool

    @EnvironmentObject var ascService: ASCService
    @EnvironmentObject var loc: LocalizationManager
    @EnvironmentObject var syncEngine: SnapshotEngine

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch pane {
                case .language:     SettingsLanguagePane()
                case .profiles:     SettingsProfilesPane(showAddKey: $showAddKey)
                case .profileRoles: SettingsProfileRolesPane()
                case .binary:       SettingsBinaryPane()
                case .connection:   SettingsConnectionPane()
                case .prefetch:     SettingsPrefetchPane()
                case .remoteSync:   SettingsRemoteSyncPane()
                case .onboarding:   SettingsOnboardingPane()
                case .about:        SettingsAboutPane()
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(pane.title(loc))
    }
}

// MARK: - Shared pane chrome

private struct SettingsPaneHeader: View {
    let title: String
    let subtitle: String?

    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.bottom, 4)
    }
}

// MARK: - Language

private struct SettingsLanguagePane: View {
    @EnvironmentObject var loc: LocalizationManager

    var body: some View {
        SettingsPaneHeader(loc(.secLanguage), subtitle: loc(.languageHelp))
        Picker(loc(.language), selection: $loc.language) {
            ForEach(AppLanguage.allCases) { lang in
                Text(loc.displayName(for: lang)).tag(lang)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }
}

// MARK: - Profiles

private struct SettingsProfilesPane: View {
    @Binding var showAddKey: Bool

    @EnvironmentObject var ascService: ASCService
    @EnvironmentObject var loc: LocalizationManager

    var body: some View {
        SettingsPaneHeader(loc(.authProfiles), subtitle: loc(.noKeysDesc))

        let credentials = ascService.authStatus?.credentials ?? []
        if credentials.isEmpty {
            Label(loc(.noKeysFound), systemImage: "exclamationmark.triangle")
                .foregroundStyle(.orange)
                .font(.callout)
        } else {
            VStack(spacing: 0) {
                ForEach(credentials) { cred in
                    profileRow(cred)
                    if cred.id != credentials.last?.id { Divider() }
                }
            }
            .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))

            if let backend = ascService.authStatus?.storageBackend {
                Text(loc(.storedInFmt, backend))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }

        Button { showAddKey = true } label: {
            Label(loc(.addApiKey), systemImage: "plus")
        }
    }

    private func profileRow(_ cred: ASCAuthCredential) -> some View {
        let isActive = ascService.activeProfile == cred.name
        return Button {
            ascService.selectProfile(cred.name)
            Task { await ascService.refreshAuthStatus() }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(cred.name).fontWeight(.medium)
                        if cred.isDefault {
                            Text(loc(.defaultTag))
                                .font(.caption2)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.secondary.opacity(0.15), in: Capsule())
                        }
                    }
                    Text(loc(.keyIdFmt, cred.keyId))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Profile roles

private struct SettingsProfileRolesPane: View {
    @EnvironmentObject var ascService: ASCService
    @EnvironmentObject var loc: LocalizationManager

    var body: some View {
        SettingsPaneHeader(loc(.profileRolesSection), subtitle: loc(.profileRolesDesc))

        let credentials = ascService.authStatus?.credentials ?? []
        if credentials.count < 2 {
            Text(loc(.profileCapUseDefault))
                .font(.callout)
                .foregroundStyle(.secondary)
        } else {
            VStack(spacing: 0) {
                ForEach(ProfileCapability.assignable) { cap in
                    profileRoleRow(cap, credentials: credentials)
                    if cap != ProfileCapability.assignable.last { Divider() }
                }
            }
            .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private func profileRoleRow(_ capability: ProfileCapability, credentials: [ASCAuthCredential]) -> some View {
        let selected = ascService.profileMappings[capability]
        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(loc(capability.locKey))
                    .fontWeight(.medium)
                Text(loc(capability.helpLocKey))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Picker("", selection: Binding(
                get: { selected ?? "" },
                set: { ascService.setProfile($0.isEmpty ? nil : $0, for: capability) }
            )) {
                Text(loc(.profileCapUseDefault)).tag("")
                ForEach(credentials) { cred in
                    Text(cred.name).tag(cred.name)
                }
            }
            .labelsHidden()
            .frame(width: 180)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// MARK: - Binary

private struct SettingsBinaryPane: View {
    @EnvironmentObject var ascService: ASCService
    @EnvironmentObject var loc: LocalizationManager

    var body: some View {
        SettingsPaneHeader(loc(.ascBinary))

        HStack {
            TextField("/opt/homebrew/bin/asc", text: $ascService.ascBinaryPath)
                .textFieldStyle(.roundedBorder)
            Button(loc(.browse), action: browseForBinary)
        }

        if ascService.binaryExists {
            Label(loc(.binaryFound), systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Label(loc(.binaryNotFound), systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Text(loc(.installHintFmt, "brew install asc"))
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func browseForBinary() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/opt/homebrew/bin")
        if panel.runModal() == .OK, let url = panel.url {
            ascService.ascBinaryPath = url.path
            ascService.saveSettings()
        }
    }
}

// MARK: - Connection

private struct SettingsConnectionPane: View {
    @EnvironmentObject var ascService: ASCService
    @EnvironmentObject var loc: LocalizationManager

    @State private var testResult: TestResult?
    @State private var isTesting = false

    enum TestResult {
        case success(String)
        case failure(String)
    }

    var body: some View {
        SettingsPaneHeader(loc(.connection))

        Button { runTest() } label: {
            if isTesting {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(loc(.testing))
                }
            } else {
                Label(loc(.testConnection), systemImage: "network")
            }
        }
        .buttonStyle(.borderedProminent)
        .disabled(isTesting || !ascService.isConfigured)

        switch testResult {
        case .success(let msg):
            SettingsResultBanner(text: msg, color: .green, icon: "checkmark.circle.fill")
        case .failure(let msg):
            SettingsResultBanner(text: msg, color: .red, icon: "xmark.octagon.fill")
        case .none:
            EmptyView()
        }
    }

    private func runTest() {
        isTesting = true
        testResult = nil
        Task {
            let result = await ascService.run(["apps", "list", "--limit", "1"])
            if result.succeeded {
                testResult = .success(loc(.connectionSuccessFmt, ascService.activeProfile ?? "default"))
            } else {
                testResult = .failure(String(result.errorMessage.prefix(400)))
            }
            isTesting = false
        }
    }
}

// MARK: - Prefetch

private struct SettingsPrefetchPane: View {
    @EnvironmentObject var loc: LocalizationManager

    @AppStorage(PrefetchSettings.enabledKey) private var prefetchEnabled = false
    @AppStorage(PrefetchSettings.sectionsKey) private var prefetchSectionsRaw = PrefetchSettings.defaultRaw

    private var prefetchBinding: Binding<Set<ASCService.PrefetchSection>> {
        Binding(
            get: { PrefetchSettings.decode(prefetchSectionsRaw) },
            set: { prefetchSectionsRaw = PrefetchSettings.encode($0) }
        )
    }

    var body: some View {
        SettingsPaneHeader(loc(.secPrefetch), subtitle: loc(.prefetchEnableDesc))

        Toggle(isOn: $prefetchEnabled) {
            Text(loc(.prefetchEnable)).fontWeight(.medium)
        }

        if prefetchEnabled {
            Text(loc(.prefetchSectionsLabel))
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            ForEach(ASCService.PrefetchSection.allCases) { sec in
                Toggle(loc(sec.locKey), isOn: Binding(
                    get: { prefetchBinding.wrappedValue.contains(sec) },
                    set: { on in
                        var set = prefetchBinding.wrappedValue
                        if on { set.insert(sec) } else { set.remove(sec) }
                        prefetchBinding.wrappedValue = set
                    }
                ))
            }
            Text(loc(.prefetchNote))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Remote sync

private struct SettingsRemoteSyncPane: View {
    @EnvironmentObject var loc: LocalizationManager
    @EnvironmentObject var syncEngine: SnapshotEngine

    @AppStorage(RemoteSyncSettings.enabledKey) private var syncEnabled = RemoteSyncSettings.defaultEnabled
    @AppStorage(RemoteSyncSettings.intervalKey) private var syncIntervalRaw = RemoteSyncSettings.defaultInterval
    @AppStorage(RemoteSyncSettings.sectionsKey) private var syncSectionsRaw = RemoteSyncSettings.defaultRaw

    private var syncSectionBinding: Binding<Set<MirrorSection>> {
        Binding(
            get: { MirrorSection.decode(syncSectionsRaw) },
            set: { syncSectionsRaw = MirrorSection.encode($0) }
        )
    }

    private static let statusFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        SettingsPaneHeader(loc(.secRemoteSync), subtitle: loc(.syncEnableDesc))

        Toggle(isOn: $syncEnabled) {
            Text(loc(.syncEnable)).fontWeight(.medium)
        }

        if syncEnabled {
            Picker(loc(.syncIntervalLabel), selection: $syncIntervalRaw) {
                ForEach(SyncInterval.allCases) { interval in
                    Text(loc(interval.locKey)).tag(interval.rawValue)
                }
            }
            .padding(.top, 4)

            Text(loc(.syncSectionsLabel))
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            ForEach(MirrorSection.allCases) { sec in
                Toggle(loc(sec.locKey), isOn: Binding(
                    get: { syncSectionBinding.wrappedValue.contains(sec) },
                    set: { on in
                        var set = syncSectionBinding.wrappedValue
                        if on { set.insert(sec) } else { set.remove(sec) }
                        syncSectionBinding.wrappedValue = set
                    }
                ))
            }

            HStack(spacing: 10) {
                Button {
                    Task { await syncEngine.captureCurrent(manual: true) }
                } label: {
                    if syncEngine.isSyncing {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text(loc(.syncNowRunning))
                        }
                    } else {
                        Label(loc(.syncNow), systemImage: "arrow.triangle.2.circlepath.icloud")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(syncEngine.isSyncing || syncEngine.currentAppId == nil)

                if syncEngine.currentAppId == nil {
                    Text(loc(.syncNeedApp))
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .padding(.top, 2)

            HStack {
                Text(loc(.syncStatusLabel)).foregroundStyle(.secondary)
                Spacer()
                Text(syncEngine.lastSyncDate.map { Self.statusFormatter.string(from: $0) } ?? loc(.syncNever))
            }
            .font(.caption)

            if let error = syncEngine.lastError {
                Label(loc(.syncFailedFmt, error), systemImage: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }

            Text(loc(.syncNote))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Onboarding

private struct SettingsOnboardingPane: View {
    @EnvironmentObject var loc: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    @AppStorage("asc.hasOnboarded") private var hasOnboarded = false

    var body: some View {
        SettingsPaneHeader(loc(.onboardingSection), subtitle: loc(.replayOnboardingDesc))

        Button(loc(.showOnboarding)) {
            hasOnboarded = false
            dismiss()
        }
        .buttonStyle(.borderedProminent)
    }
}

// MARK: - About

private struct SettingsAboutPane: View {
    @EnvironmentObject private var loc: LocalizationManager

    var body: some View {
        SettingsPaneHeader(loc(.secAbout))

        aboutRow(loc(.aboutVersion), "\(AppInfo.version) (\(AppInfo.build))")
        aboutRow(loc(.aboutCreator), AppInfo.creator)
        aboutRow(loc(.aboutLicense), AppInfo.license)
    }

    private func aboutRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).textSelection(.enabled)
        }
        .font(.callout)
    }
}

// MARK: - Shared UI

private struct SettingsResultBanner: View {
    let text: String
    let color: Color
    let icon: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon).foregroundStyle(color)
            Text(text)
                .font(.caption)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Add Key

struct AddKeyView: View {
    @EnvironmentObject var ascService: ASCService
    @EnvironmentObject var loc: LocalizationManager
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var keyId = ""
    @State private var issuerId = ""
    @State private var privateKeyPath = ""
    @State private var isSaving = false
    @State private var errorText: String?

    private var canSave: Bool {
        !name.isEmpty && !keyId.isEmpty && !issuerId.isEmpty && !privateKeyPath.isEmpty && !isSaving
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(loc(.addKeyTitle))
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    field(loc(.profileName), placeholder: "Work", text: $name, hint: loc(.profileNameHint))
                    field(loc(.keyId), placeholder: "XXXXXXXXXX", text: $keyId, hint: loc(.keyIdHint))
                    field(loc(.issuerId), placeholder: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx", text: $issuerId, hint: loc(.issuerIdHint))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(loc(.privateKey)).font(.caption).foregroundStyle(.secondary)
                        HStack {
                            TextField("/path/to/AuthKey_XXXXXXXXXX.p8", text: $privateKeyPath)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                            Button(loc(.browse), action: browseForKey)
                        }
                        Text(loc(.privateKeyHint))
                            .font(.caption2).foregroundStyle(.tertiary)
                    }

                    if let errorText {
                        Text(errorText)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .textSelection(.enabled)
                    }
                }
                .padding(20)
            }

            Divider()
            HStack {
                Spacer()
                Button(loc(.cancel)) { dismiss() }
                Button { save() } label: {
                    if isSaving {
                        HStack(spacing: 6) { ProgressView().controlSize(.small); Text(loc(.saving)) }
                    } else {
                        Text(loc(.saveKey))
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
            }
            .padding(16)
        }
        .frame(width: 480, height: 480)
    }

    @ViewBuilder
    private func field(_ label: String, placeholder: String, text: Binding<String>, hint: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
            Text(hint).font(.caption2).foregroundStyle(.tertiary)
        }
    }

    private func browseForKey() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if let p8 = UTType(filenameExtension: "p8") {
            panel.allowedContentTypes = [p8]
        }
        if panel.runModal() == .OK, let url = panel.url {
            privateKeyPath = url.path
        }
    }

    private func save() {
        isSaving = true
        errorText = nil
        Task {
            let result = await ascService.login(
                name: name, keyId: keyId, issuerId: issuerId, privateKeyPath: privateKeyPath
            )
            isSaving = false
            if result.succeeded {
                dismiss()
            } else {
                errorText = result.errorMessage
            }
        }
    }
}
