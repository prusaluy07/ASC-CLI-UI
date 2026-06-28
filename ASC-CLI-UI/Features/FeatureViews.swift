import SwiftUI
import ASCShared

// MARK: - TestFlight View

struct TestFlightView: View {
    @EnvironmentObject var ascService: ASCService
    @EnvironmentObject var loc: LocalizationManager
    let selectedApp: ASCApp?

    @State private var tab = 0
    @State private var feedbackOutput = ""
    @State private var crashesOutput = ""
    @State private var includeScreens = false
    @State private var submissionId = ""
    @State private var crashLogOutput: String?
    @State private var isNotifying = false
    @State private var showNotifyConfirm = false
    @State private var notifyResult: String?

    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(title: loc(.testflightTitle), subtitle: selectedApp?.name) {
                Button {
                    Task { await reload(force: true) }
                } label: {
                    Label(loc(.refresh), systemImage: "arrow.clockwise")
                }
                .disabled(ascService.isLoading || selectedApp == nil)
            }
            Divider()

            if selectedApp == nil {
                ContentUnavailableView(
                    loc(.noAppSelectedTitle),
                    systemImage: "airplane.slash",
                    description: Text(loc(.selectAppFromApps))
                )
            } else {
                Picker("", selection: $tab) {
                    Text(loc(.tfGroups)).tag(0)
                    Text(loc(.tfTesters)).tag(1)
                    Text(loc(.feedback)).tag(2)
                    Text(loc(.tfCrashes)).tag(3)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(.horizontal, 20)
                .padding(.vertical, 10)

                Group {
                    switch tab {
                    case 0: groupsTable
                    case 1: testersTable
                    case 2: feedbackPane
                    default: crashesPane
                    }
                }

                Divider()
                notifyBar
            }
        }
        .task(id: selectedApp?.id) { await reload() }
        .alert(loc(.tfNotifyConfirmTitle), isPresented: $showNotifyConfirm) {
            Button(loc(.cancel), role: .cancel) {}
            Button(loc(.tfNotify)) { notify() }
        } message: {
            Text(loc(.tfNotifyConfirmMsg))
        }
    }

    @ViewBuilder
    private var groupsTable: some View {
        if ascService.betaGroups.isEmpty && !ascService.isLoading {
            ContentUnavailableView(loc(.tfNoGroups), systemImage: "person.3")
        } else {
            Table(ascService.betaGroups) {
                TableColumn(loc(.tfColName)) { g in Text(g.name).fontWeight(.medium) }
                TableColumn(loc(.tfColType)) { g in
                    Text(g.isInternal ? loc(.tfInternal) : loc(.tfExternal)).foregroundStyle(.secondary)
                }
                TableColumn(loc(.tfColAccess)) { g in
                    Text(g.hasAccessToAllBuilds ? loc(.tfYes) : loc(.tfNo)).foregroundStyle(.secondary)
                }
                TableColumn(loc(.tfColFeedback)) { g in
                    Text(g.feedbackEnabled ? loc(.tfYes) : loc(.tfNo)).foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var testersTable: some View {
        if ascService.betaTesters.isEmpty && !ascService.isLoading {
            ContentUnavailableView(loc(.tfNoTesters), systemImage: "person.crop.circle.badge.questionmark")
        } else {
            Table(ascService.betaTesters) {
                TableColumn(loc(.tfColName)) { t in Text(t.fullName).fontWeight(.medium) }
                TableColumn(loc(.tfColEmail)) { t in
                    Text(t.email ?? "—").foregroundStyle(.secondary)
                }
                TableColumn(loc(.tfColType)) { t in
                    Text((t.inviteType ?? "—").capitalized).foregroundStyle(.secondary)
                }
                TableColumn(loc(.tfColState)) { t in
                    Text((t.state ?? "—").capitalized).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var feedbackPane: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Toggle(loc(.tfIncludeScreens), isOn: $includeScreens).toggleStyle(.checkbox)
                Button {
                    Task { await loadFeedback() }
                } label: {
                    Label(loc(.tfLoadFeedback), systemImage: "arrow.clockwise")
                }
                .disabled(ascService.isLoading)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            Divider()
            ScrollView {
                Text(feedbackOutput.isEmpty ? "—" : feedbackOutput)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
        }
    }

    private var crashesPane: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button {
                    Task { await loadCrashes() }
                } label: {
                    Label(loc(.tfLoadCrashes), systemImage: "arrow.clockwise")
                }
                .disabled(ascService.isLoading)
                Divider().frame(height: 16)
                TextField(loc(.tfSubmissionId), text: $submissionId)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: 240)
                Button {
                    Task { await fetchCrashLog() }
                } label: {
                    Label(loc(.tfCrashLog), systemImage: "doc.text.magnifyingglass")
                }
                .disabled(ascService.isLoading || submissionId.isEmpty)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            Divider()
            ScrollView {
                Text((crashLogOutput ?? crashesOutput).isEmpty ? "—" : (crashLogOutput ?? crashesOutput))
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
        }
    }

    private var notifyBar: some View {
        HStack {
            if let notifyResult {
                Text(notifyResult)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Button {
                showNotifyConfirm = true
            } label: {
                if isNotifying {
                    HStack(spacing: 6) { ProgressView().controlSize(.small); Text(loc(.tfNotify)) }
                } else {
                    Label(loc(.tfNotify), systemImage: "bell.badge")
                }
            }
            .disabled(isNotifying || ascService.builds.first == nil)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private func reload(force: Bool = false) async {
        guard let app = selectedApp else { return }
        if force {
            await ascService.loadBetaGroups(for: app.id)
            await ascService.loadBetaTesters(for: app.id)
            await ascService.loadBuilds(for: app.id)
        } else {
            await ascService.ensureBetaGroups(for: app.id)
            await ascService.ensureBetaTesters(for: app.id)
            await ascService.ensureBuilds(for: app.id)
        }
        await loadFeedback()
    }

    private func loadFeedback() async {
        guard let app = selectedApp else { return }
        let fb = await ascService.testflightFeedbackList(appId: app.id, includeScreenshots: includeScreens)
        feedbackOutput = fb.succeeded ? (fb.output.isEmpty ? "—" : fb.output) : fb.errorMessage
    }

    private func loadCrashes() async {
        guard let app = selectedApp else { return }
        crashLogOutput = nil
        let cr = await ascService.testflightCrashesList(appId: app.id)
        crashesOutput = cr.succeeded ? (cr.output.isEmpty ? "—" : cr.output) : cr.errorMessage
    }

    private func fetchCrashLog() async {
        let log = await ascService.testflightCrashLog(submissionId: submissionId)
        crashLogOutput = log.succeeded ? (log.output.isEmpty ? "—" : log.output) : log.errorMessage
    }

    private func notify() {
        guard let buildId = ascService.builds.first?.id else {
            notifyResult = loc(.tfNoLatestBuild)
            return
        }
        isNotifying = true
        notifyResult = nil
        Task {
            let result = await ascService.sendBuildNotification(buildId: buildId)
            notifyResult = result.succeeded ? "✓" : result.errorMessage
            isNotifying = false
        }
    }
}

// MARK: - Signing View

struct SigningView: View {
    @EnvironmentObject var ascService: ASCService
    @EnvironmentObject var loc: LocalizationManager

    @State private var tab = 0
    @State private var notarizeFile = ""
    @State private var notarizeWait = false
    @State private var notarizeOutput: String?
    @State private var isNotarizing = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(loc(.signingTitle))
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button {
                    refreshCurrentTab()
                } label: {
                    Label(loc(.refresh), systemImage: "arrow.clockwise")
                }
                .disabled(ascService.isLoading)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Picker("", selection: $tab) {
                Text(loc(.signCertsProfiles)).tag(0)
                Text(loc(.secBundleIds)).tag(1)
                Text(loc(.secNotarization)).tag(2)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 20)
            .padding(.bottom, 10)

            Divider()

            switch tab {
            case 1: bundleIdsPane
            case 2: notarizationPane
            default: certsAndProfiles
            }
        }
        .task {
            if ascService.certificates.isEmpty {
                await ascService.loadCertificates()
                await ascService.loadProfiles()
            }
        }
    }

    private func refreshCurrentTab() {
        Task {
            switch tab {
            case 1: await ascService.loadBundleIds()
            case 2: notarizationOutput { await ascService.notarizationList() }
            default:
                await ascService.loadCertificates()
                await ascService.loadProfiles()
            }
        }
    }

    private var bundleIdsPane: some View {
        Group {
            if ascService.bundleIds.isEmpty && !ascService.isLoading {
                ContentUnavailableView(loc(.biEmpty), systemImage: "number.square",
                                       description: Text(loc(.biLoadHint)))
            } else {
                Table(ascService.bundleIds) {
                    TableColumn(loc(.biName)) { Text($0.name).fontWeight(.medium) }
                    TableColumn(loc(.biIdentifier)) { Text($0.identifier).font(.system(.body, design: .monospaced)).foregroundStyle(.secondary) }
                    TableColumn(loc(.tfColType)) { Text($0.platform).foregroundStyle(.secondary) }
                }
            }
        }
        .task { if ascService.bundleIds.isEmpty { await ascService.loadBundleIds() } }
    }

    private var notarizationPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(loc(.notarizeBody)).font(.callout).foregroundStyle(.secondary)
                        PathPickerRow(label: loc(.notarizeFile), path: $notarizeFile, chooseTitle: loc(.rpChooseFolder)) {
                            FilePanel.pickFile(extensions: ["zip", "dmg", "pkg"])
                        }
                        Toggle(loc(.xcWait), isOn: $notarizeWait).toggleStyle(.checkbox)
                        HStack {
                            Button {
                                notarizationOutput { await ascService.notarizationList() }
                            } label: { Label(loc(.notarizeList), systemImage: "list.bullet") }
                            .disabled(isNotarizing)
                            Spacer()
                            Button {
                                notarizationOutput { await ascService.notarizationSubmit(file: notarizeFile, wait: notarizeWait) }
                            } label: {
                                if isNotarizing {
                                    HStack(spacing: 6) { ProgressView().controlSize(.small); Text(loc(.notarizeSubmitting)) }
                                } else {
                                    Label(loc(.notarizeSubmit), systemImage: "checkmark.shield")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isNotarizing || notarizeFile.isEmpty)
                        }
                    }
                    .padding(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    Label(loc(.secNotarization), systemImage: "checkmark.shield")
                }
                if let notarizeOutput { OutputPanel(title: loc(.output), text: notarizeOutput) }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func notarizationOutput(_ operation: @escaping () async -> CommandResult) {
        isNotarizing = true
        notarizeOutput = nil
        Task {
            let result = await operation()
            notarizeOutput = result.succeeded ? (result.output.isEmpty ? "✓" : result.output) : result.errorMessage
            isNotarizing = false
        }
    }

    private var certsAndProfiles: some View {
        HSplitView {
                // Certificates
                VStack(alignment: .leading, spacing: 0) {
                    Text(loc(.certificates))
                        .font(.headline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)

                    Divider()

                    if ascService.certificates.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "checkmark.seal.slash")
                                .font(.system(size: 28))
                                .foregroundStyle(.secondary)
                            Text(loc(.noCertificates))
                                .foregroundStyle(.secondary)
                            Button(loc(.load)) {
                                Task { await ascService.loadCertificates() }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List(ascService.certificates) { cert in
                            CertificateRow(cert: cert)
                        }
                        .listStyle(.plain)
                    }
                }
                .frame(minWidth: 220)

                // Profiles
                VStack(alignment: .leading, spacing: 0) {
                    Text(loc(.profiles))
                        .font(.headline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)

                    Divider()

                    if ascService.profiles.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "person.crop.rectangle.badge.plus.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(.secondary)
                            Text(loc(.noProfiles))
                                .foregroundStyle(.secondary)
                            Button(loc(.load)) {
                                Task { await ascService.loadProfiles() }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List(ascService.profiles) { profile in
                            ProfileRow(profile: profile)
                        }
                        .listStyle(.plain)
                    }
                }
                .frame(minWidth: 220)
            }
    }
}

struct CertificateRow: View {
    @EnvironmentObject var loc: LocalizationManager
    let cert: ASCCertificate

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(cert.displayName ?? cert.name)
                .fontWeight(.medium)
                .lineLimit(1)
            HStack {
                Text(cert.type)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 3))
                if let exp = cert.expirationDate {
                    Text("\(loc(.certExp)) \(formatShortDate(exp))")
                        .font(.caption2)
                        .foregroundStyle(isExpiringSoon(exp) ? .orange : .secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func formatShortDate(_ dateStr: String) -> String {
        let f = ISO8601DateFormatter()
        if let d = f.date(from: dateStr) {
            let out = DateFormatter()
            out.dateStyle = .short
            return out.string(from: d)
        }
        return dateStr
    }

    private func isExpiringSoon(_ dateStr: String) -> Bool {
        let f = ISO8601DateFormatter()
        guard let d = f.date(from: dateStr) else { return false }
        return d.timeIntervalSinceNow < 60 * 24 * 3600 // 60 days
    }
}

struct ProfileRow: View {
    let profile: ASCProfile

    var stateColor: Color {
        switch profile.state?.uppercased() {
        case "ACTIVE": return .green
        case "INVALID": return .red
        default: return .secondary
        }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(profile.name)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(profile.type)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let state = profile.state {
                Circle()
                    .fill(stateColor)
                    .frame(width: 7, height: 7)
                Text(state.capitalized)
                    .font(.caption2)
                    .foregroundStyle(stateColor)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Terminal View

struct TerminalEntry: Identifiable {
    let id = UUID()
    let command: String
    let output: String
    let success: Bool
}

struct TerminalEntryView: View {
    let entry: TerminalEntry

    private var outputColor: Color { entry.success ? .secondary : .red }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("$").foregroundStyle(.green)
                Text("asc \(entry.command)").foregroundStyle(.primary)
            }
            .font(.system(.body, design: .monospaced))

            Text(entry.output)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(outputColor)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(Color.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 16)
    }
}

struct TerminalView: View {
    @EnvironmentObject var ascService: ASCService
    @EnvironmentObject var loc: LocalizationManager
    @State private var commandText: String = ""
    @State private var outputHistory: [TerminalEntry] = []
    @State private var isRunning = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(loc(.terminalTitle))
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button(loc(.clear)) {
                    outputHistory = []
                }
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if outputHistory.isEmpty {
                            Text(loc(.terminalHint))
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 16)
                                .padding(.top, 16)
                        }

                        ForEach(outputHistory) { entry in
                            TerminalEntryView(entry: entry)
                                .id(entry.id)
                        }
                    }
                    .padding(.bottom, 16)
                }
                .background(Color(NSColor.textBackgroundColor).opacity(0.3))
                .onChange(of: outputHistory.count) { _, _ in
                    if let last = outputHistory.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            Divider()

            // Input
            HStack(spacing: 10) {
                Text("asc")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)

                TextField(loc(.terminalPlaceholder), text: $commandText)
                    .font(.system(.body, design: .monospaced))
                    .textFieldStyle(.plain)
                    .onSubmit { runCommand() }

                if isRunning {
                    ProgressView().scaleEffect(0.7).frame(width: 20, height: 20)
                } else {
                    Button(action: runCommand) {
                        Image(systemName: "return")
                    }
                    .disabled(commandText.trimmingCharacters(in: .whitespaces).isEmpty)
                    .keyboardShortcut(.return, modifiers: [])
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private func runCommand() {
        let input = commandText.trimmingCharacters(in: .whitespaces)
        guard !input.isEmpty else { return }

        let args = input.components(separatedBy: " ").filter { !$0.isEmpty }
        commandText = ""
        isRunning = true

        Task {
            let result = await ascService.run(args, json: false)
            let out = result.succeeded
                ? (result.output.isEmpty ? "(no output)" : result.output)
                : result.errorMessage

            outputHistory.append(TerminalEntry(command: input, output: out, success: result.succeeded))
            isRunning = false
        }
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
    let title: String
    let icon: String
    let description: String
    let action: () async -> Void

    @State private var isRunning = false

    var body: some View {
        Button {
            isRunning = true
            Task {
                await action()
                isRunning = false
            }
        } label: {
            VStack(spacing: 8) {
                if isRunning {
                    ProgressView().frame(width: 24, height: 24)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .foregroundStyle(.tint)
                }
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(isRunning)
    }
}
