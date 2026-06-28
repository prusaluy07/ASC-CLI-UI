import SwiftUI
import ASCShared
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var ascService: ASCService
    @EnvironmentObject var loc: LocalizationManager
    @Environment(\.dismiss) var dismiss
    @AppStorage("asc.hasOnboarded") private var hasOnboarded = false
    @AppStorage(PrefetchSettings.enabledKey) private var prefetchEnabled = false
    @AppStorage(PrefetchSettings.sectionsKey) private var prefetchSectionsRaw = PrefetchSettings.defaultRaw

    @State private var testResult: TestResult?
    @State private var isTesting = false
    @State private var showAddKey = false

    enum TestResult {
        case success(String)
        case failure(String)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    languageSection
                    profilesSection
                    binarySection
                    testSection
                    prefetchSection
                    onboardingSection
                    aboutSection
                }
                .padding(20)
            }

            Divider()
            footer
        }
        .frame(width: 520, height: 680)
        .task { await ascService.refreshAuthStatus() }
        .sheet(isPresented: $showAddKey) {
            AddKeyView()
                .environmentObject(ascService)
                .environmentObject(loc)
        }
    }

    private var header: some View {
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
    }

    private var footer: some View {
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

    // MARK: - Language

    private var languageSection: some View {
        section(title: loc(.secLanguage)) {
            Picker(loc(.language), selection: $loc.language) {
                ForEach(AppLanguage.allCases) { lang in
                    Text(loc.displayName(for: lang)).tag(lang)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            Text(loc(.languageHelp))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Profiles

    private var profilesSection: some View {
        section(title: loc(.authProfiles)) {
            let credentials = ascService.authStatus?.credentials ?? []
            if credentials.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Label(loc(.noKeysFound), systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                        .font(.callout)
                    Text(loc(.noKeysDesc))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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

            Button {
                showAddKey = true
            } label: {
                Label(loc(.addApiKey), systemImage: "plus")
            }
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

    // MARK: - Binary

    private var binarySection: some View {
        section(title: loc(.ascBinary)) {
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
    }

    // MARK: - Test

    private var testSection: some View {
        section(title: loc(.connection)) {
            Button {
                runTest()
            } label: {
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
                resultBanner(msg, color: .green, icon: "checkmark.circle.fill")
            case .failure(let msg):
                resultBanner(msg, color: .red, icon: "xmark.octagon.fill")
            case .none:
                EmptyView()
            }
        }
    }

    // MARK: - Onboarding

    private var onboardingSection: some View {
        section(title: loc(.onboardingSection)) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(loc(.replayOnboarding)).fontWeight(.medium)
                    Text(loc(.replayOnboardingDesc))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(loc(.showOnboarding)) {
                    hasOnboarded = false
                    dismiss()
                }
            }
        }
    }

    // MARK: - Prefetch

    private var prefetchBinding: Binding<Set<ASCService.PrefetchSection>> {
        Binding(
            get: { PrefetchSettings.decode(prefetchSectionsRaw) },
            set: { prefetchSectionsRaw = PrefetchSettings.encode($0) }
        )
    }

    private var prefetchSection: some View {
        section(title: loc(.secPrefetch)) {
            Toggle(isOn: $prefetchEnabled) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(loc(.prefetchEnable)).fontWeight(.medium)
                    Text(loc(.prefetchEnableDesc))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            if prefetchEnabled {
                Text(loc(.prefetchSectionsLabel))
                    .font(.caption).foregroundStyle(.secondary)
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
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        section(title: loc(.secAbout)) {
            aboutRow(loc(.aboutVersion), "\(AppInfo.version) (\(AppInfo.build))")
            aboutRow(loc(.aboutCreator), AppInfo.creator)
            aboutRow(loc(.aboutLicense), AppInfo.license)
        }
    }

    private func aboutRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).textSelection(.enabled)
        }
        .font(.callout)
    }

    private func resultBanner(_ text: String, color: Color, icon: String) -> some View {
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

    // MARK: - Helpers

    @ViewBuilder
    private func section(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                Button {
                    save()
                } label: {
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
