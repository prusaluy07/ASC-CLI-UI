import SwiftUI
import AppKit

struct MetadataView: View {
    @EnvironmentObject var ascService: ASCService
    @EnvironmentObject var loc: LocalizationManager
    let selectedApp: ASCApp?

    @State private var selectedVersionId: String?
    @State private var selectedLocale: String?
    @State private var compareLocale: String?
    @State private var mode = 0   // 0 = edit, 1 = compare

    @State private var descriptionText = ""
    @State private var keywords = ""
    @State private var whatsNew = ""
    @State private var promotional = ""
    @State private var supportUrl = ""
    @State private var marketingUrl = ""

    @State private var isSaving = false
    @State private var showSaveConfirm = false
    @State private var resultText: String?

    // File workflow
    @State private var metaDir = ""
    @State private var metaDryRun = true
    @State private var metaRunning = false
    @State private var metaOutput: String?

    // Source mode: 0 = online (ASC), 1 = local folder
    @State private var sourceMode = 0

    // Agent brief
    @State private var briefGoal = ""
    @State private var briefAudience = ""
    @State private var briefTone = ""
    @State private var briefPrinciples = ""
    @State private var briefLocales = ""
    @State private var briefIncludeCurrent = true
    @State private var briefResult: String?
    @State private var briefURL: URL?

    // Local folder browser
    @State private var localFiles: [LocalMetadataFile] = []
    @State private var selectedFile: LocalMetadataFile?
    @State private var fileContent = ""
    @State private var fileDirty = false
    @State private var fileMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(title: loc(.metadataTitle), subtitle: selectedApp?.name) {
                Button {
                    Task { await reload() }
                } label: {
                    Label(loc(.refresh), systemImage: "arrow.clockwise")
                }
                .disabled(ascService.isLoading || selectedApp == nil)
            }
            Divider()

            if selectedApp == nil {
                ContentUnavailableView(loc(.noAppSelectedTitle), systemImage: "doc.text",
                                       description: Text(loc(.mdPickAppVersion)))
            } else {
                editor
            }
        }
        .task(id: selectedApp?.id) { await reload() }
        .alert(loc(.mdSaveConfirmTitle), isPresented: $showSaveConfirm) {
            Button(loc(.cancel), role: .cancel) {}
            Button(loc(.mdSave)) { save() }
        } message: {
            Text(loc(.mdSaveConfirmMsg))
        }
    }

    private var editor: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                sourcePicker
                pickers
                filesCard

                if sourceMode == 0 {
                    onlineEditor
                    agentBriefCard
                } else {
                    localBrowserCard
                }
            }
            .padding(20)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    private var sourcePicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(loc(.mdSource)).font(.caption).foregroundStyle(.secondary)
            Picker("", selection: $sourceMode) {
                Label(loc(.mdSourceOnline), systemImage: "cloud").tag(0)
                Label(loc(.mdSourceLocal), systemImage: "folder").tag(1)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 360)
            .onChange(of: sourceMode) { _, newValue in
                if newValue == 1 { reloadLocalFiles() }
            }
        }
    }

    @ViewBuilder
    private var onlineEditor: some View {
        if selectedLocale == nil {
            Text(loc(.mdNoLocalizations))
                .foregroundStyle(.secondary)
                .padding(.top, 8)
        } else {
            Picker("", selection: $mode) {
                Text(loc(.mdEdit)).tag(0)
                Text(loc(.mdCompare)).tag(1)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 280)

            if mode == 0 {
                fieldsCard
                saveBar
                if let resultText {
                    Text(resultText)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                compareView
            }
        }
    }

    private var pickers: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(loc(.mdSelectVersion)).font(.caption).foregroundStyle(.secondary)
                Picker("", selection: $selectedVersionId) {
                    ForEach(ascService.versions) { v in
                        Text("\(v.versionString) · \(v.state)").tag(String?.some(v.id))
                    }
                }
                .labelsHidden()
                .frame(minWidth: 220)
                .onChange(of: selectedVersionId) { _, newValue in
                    if let vid = newValue { Task { await loadLocalizations(vid) } }
                }
            }

            if !ascService.versionLocalizations.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(loc(.mdLocale)).font(.caption).foregroundStyle(.secondary)
                    Picker("", selection: $selectedLocale) {
                        ForEach(ascService.versionLocalizations) { l in
                            Text(l.locale).tag(String?.some(l.locale))
                        }
                    }
                    .labelsHidden()
                    .frame(minWidth: 140)
                    .onChange(of: selectedLocale) { _, _ in populateFields() }
                }
            }
            Spacer()
        }
    }

    private var fieldsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            labeledEditor(loc(.mdWhatsNew), text: $whatsNew, minHeight: 70)
            labeledEditor(loc(.mdDescription), text: $descriptionText, minHeight: 120)
            labeledEditor(loc(.mdPromotional), text: $promotional, minHeight: 50)
            labeledField(loc(.mdKeywords), text: $keywords)
            labeledField(loc(.mdSupportUrl), text: $supportUrl)
            labeledField(loc(.mdMarketingUrl), text: $marketingUrl)
        }
    }

    private var saveBar: some View {
        HStack {
            Spacer()
            Button {
                showSaveConfirm = true
            } label: {
                if isSaving {
                    HStack(spacing: 6) { ProgressView().controlSize(.small); Text(loc(.mdSaving)) }
                } else {
                    Label(loc(.mdSave), systemImage: "square.and.arrow.down")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSaving || selectedLocale == nil)
        }
    }

    private var compareView: some View {
        let a = ascService.versionLocalizations.first { $0.locale == selectedLocale }
        let b = ascService.versionLocalizations.first { $0.locale == compareLocale }
        let fields: [(String, String?, String?)] = [
            (loc(.mdWhatsNew), a?.whatsNew, b?.whatsNew),
            (loc(.mdDescription), a?.description, b?.description),
            (loc(.mdPromotional), a?.promotionalText, b?.promotionalText),
            (loc(.mdKeywords), a?.keywords, b?.keywords),
            (loc(.mdSupportUrl), a?.supportUrl, b?.supportUrl),
            (loc(.mdMarketingUrl), a?.marketingUrl, b?.marketingUrl)
        ]
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                comparePicker(loc(.mdLangA), selection: $selectedLocale)
                Image(systemName: "arrow.left.arrow.right").foregroundStyle(.secondary)
                comparePicker(loc(.mdLangB), selection: $compareLocale)
                Spacer()
            }
            ForEach(fields.indices, id: \.self) { i in
                compareRow(title: fields[i].0, a: fields[i].1, b: fields[i].2)
            }
        }
    }

    private func comparePicker(_ label: String, selection: Binding<String?>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Picker("", selection: selection) {
                ForEach(ascService.versionLocalizations) { l in
                    Text(l.locale).tag(String?.some(l.locale))
                }
            }
            .labelsHidden()
            .frame(minWidth: 120)
        }
    }

    private func compareRow(title: String, a: String?, b: String?) -> some View {
        let aEmpty = (a ?? "").isEmpty
        let bEmpty = (b ?? "").isEmpty
        let differ = (a ?? "") != (b ?? "")
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                if aEmpty != bEmpty {
                    Text(loc(.mdMissingTranslation))
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
            HStack(alignment: .top, spacing: 12) {
                compareCell(a, emphasize: differ)
                compareCell(b, emphasize: differ)
            }
        }
    }

    private func compareCell(_ text: String?, emphasize: Bool) -> some View {
        let value = text ?? ""
        return Text(value.isEmpty ? "—" : value)
            .font(.callout)
            .foregroundStyle(value.isEmpty ? .tertiary : .primary)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(emphasize ? Color.orange.opacity(0.4) : Color.secondary.opacity(0.18))
            )
    }

    private var filesCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Text(loc(.mdFilesBody)).font(.callout).foregroundStyle(.secondary)
                HStack {
                    Text(metaDir.isEmpty ? loc(.pubOptional) : metaDir)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1).truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button(loc(.rpChooseFolder)) {
                        if let d = FilePanel.pickDirectory() { metaDir = d; reloadLocalFiles() }
                    }
                }
                HStack(spacing: 12) {
                    Button { runFiles { vid, app in
                        await ascService.metadataPull(appId: app, version: vid, dir: metaDir)
                    } } label: { Label(loc(.mdPull), systemImage: "arrow.down.doc") }
                    Button { runFiles { _, _ in
                        await ascService.metadataValidate(dir: metaDir)
                    } } label: { Label(loc(.mdValidate), systemImage: "checkmark.seal") }
                    Button { runFiles { vid, app in
                        await ascService.metadataApply(appId: app, version: vid, dir: metaDir, dryRun: metaDryRun)
                    } } label: { Label(loc(.mdApply), systemImage: "arrow.up.doc") }
                    Toggle(loc(.buDryRun), isOn: $metaDryRun).toggleStyle(.checkbox)
                    Spacer()
                    if metaRunning { ProgressView().controlSize(.small) }
                }
                .disabled(metaDir.isEmpty || metaRunning || selectedVersionString == nil)
                if let metaOutput {
                    OutputPanel(title: loc(.output), text: metaOutput, maxHeight: 200)
                }
            }
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label(loc(.mdFilesTitle), systemImage: "folder.badge.gearshape")
        }
    }

    // MARK: - Agent brief

    private var agentBriefCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Text(loc(.mdAgentBody)).font(.callout).foregroundStyle(.secondary)
                labeledEditor(loc(.mdAgentGoal), text: $briefGoal, minHeight: 60)
                labeledField(loc(.mdAgentAudience), text: $briefAudience)
                labeledField(loc(.mdAgentTone), text: $briefTone)
                labeledEditor(loc(.mdAgentPrinciples), text: $briefPrinciples, minHeight: 60)
                labeledField(loc(.mdAgentLocales), text: $briefLocales)
                Toggle(loc(.mdAgentInclCurrent), isOn: $briefIncludeCurrent).toggleStyle(.checkbox)
                HStack(spacing: 12) {
                    Button {
                        generateBrief()
                    } label: {
                        Label(loc(.mdAgentGenerate), systemImage: "doc.badge.gearshape")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(metaDir.isEmpty)
                    if metaDir.isEmpty {
                        Text(loc(.mdAgentNeedsFolder)).font(.caption).foregroundStyle(.orange)
                    }
                    Spacer()
                    if briefURL != nil {
                        Button {
                            if let url = briefURL {
                                NSWorkspace.shared.activateFileViewerSelecting([url])
                            }
                        } label: {
                            Label(loc(.mdAgentShowFinder), systemImage: "folder")
                        }
                    }
                }
                if let briefResult {
                    Text(briefResult)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label(loc(.mdAgentTitle), systemImage: "wand.and.stars")
        }
    }

    private func generateBrief() {
        guard let app = selectedApp, !metaDir.isEmpty else { return }
        let requested = briefLocales
            .split(whereSeparator: { $0 == "," || $0 == " " })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let locales = requested.isEmpty ? ascService.versionLocalizations.map(\.locale) : requested

        var current: [String: [String: String]] = [:]
        for l in ascService.versionLocalizations {
            current[l.locale] = [
                "description": l.description ?? "",
                "keywords": l.keywords ?? "",
                "whatsNew": l.whatsNew ?? "",
                "promotionalText": l.promotionalText ?? "",
                "supportUrl": l.supportUrl ?? "",
                "marketingUrl": l.marketingUrl ?? ""
            ]
        }

        let input = AgentBriefInput(
            appName: app.name, bundleId: app.bundleId, appId: app.id,
            versionString: selectedVersionString,
            goal: briefGoal, audience: briefAudience, tone: briefTone, principles: briefPrinciples,
            locales: locales, includeCurrent: briefIncludeCurrent, current: current
        )
        do {
            let url = try AgentBriefBuilder.write(input, to: metaDir)
            briefURL = url
            briefResult = "\(loc(.mdAgentGenerated)) \(url.deletingLastPathComponent().path)"
        } catch {
            briefURL = nil
            briefResult = error.localizedDescription
        }
    }

    // MARK: - Local folder browser

    private var localBrowserCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Text(loc(.mdLocalBody)).font(.callout).foregroundStyle(.secondary)
                if metaDir.isEmpty {
                    Text(loc(.mdLocalNoFolder)).foregroundStyle(.secondary).padding(.vertical, 8)
                } else if localFiles.isEmpty {
                    HStack {
                        Text(loc(.mdLocalNoFiles)).foregroundStyle(.secondary)
                        Button(loc(.mdLocalReload)) { reloadLocalFiles() }
                    }
                    .padding(.vertical, 8)
                } else {
                    HStack(alignment: .top, spacing: 12) {
                        fileList
                        fileEditorPane
                    }
                }
            }
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label(loc(.mdLocalTitle), systemImage: "folder.badge.gearshape")
        }
    }

    private var fileList: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(loc(.mdLocalFiles)).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Button { reloadLocalFiles() } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.borderless)
                    .help(loc(.mdLocalReload))
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(localFiles) { file in
                        Button { openFile(file) } label: {
                            Text(file.relativePath)
                                .font(.system(.caption, design: .monospaced))
                                .lineLimit(1).truncationMode(.middle)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 4).padding(.horizontal, 6)
                                .background(selectedFile == file ? Color.accentColor.opacity(0.15) : .clear,
                                            in: RoundedRectangle(cornerRadius: 5))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(width: 240, height: 320)
        }
    }

    @ViewBuilder
    private var fileEditorPane: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let selectedFile {
                Text(selectedFile.relativePath)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1).truncationMode(.middle)
                TextEditor(text: $fileContent)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 280)
                    .padding(4)
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.secondary.opacity(0.3)))
                    .onChange(of: fileContent) { _, _ in fileDirty = true }
                HStack {
                    Button { saveFile() } label: { Label(loc(.mdLocalSave), systemImage: "square.and.arrow.down") }
                        .buttonStyle(.borderedProminent)
                        .disabled(!fileDirty)
                    if let fileMessage {
                        Text(fileMessage).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            } else {
                Text("—").foregroundStyle(.tertiary).frame(maxWidth: .infinity, minHeight: 280)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func reloadLocalFiles() {
        localFiles = LocalMetadataStore.files(in: metaDir)
        if let sel = selectedFile, !localFiles.contains(sel) {
            selectedFile = nil
            fileContent = ""
            fileDirty = false
        }
    }

    private func openFile(_ file: LocalMetadataFile) {
        selectedFile = file
        fileMessage = nil
        do {
            fileContent = try LocalMetadataStore.read(file)
            fileDirty = false
        } catch {
            fileContent = ""
            fileMessage = loc(.mdLocalReadErr)
        }
    }

    private func saveFile() {
        guard let file = selectedFile else { return }
        do {
            try LocalMetadataStore.write(fileContent, to: file)
            fileDirty = false
            fileMessage = loc(.mdLocalSaved)
        } catch {
            fileMessage = error.localizedDescription
        }
    }

    private var selectedVersionString: String? {
        ascService.versions.first(where: { $0.id == selectedVersionId })?.versionString
    }

    private func runFiles(_ op: @escaping (_ versionString: String, _ appId: String) async -> CommandResult) {
        guard let app = selectedApp, let vstr = selectedVersionString else { return }
        metaRunning = true
        metaOutput = nil
        Task {
            let result = await op(vstr, app.id)
            metaOutput = result.succeeded ? (result.output.isEmpty ? "✓" : result.output) : result.errorMessage
            metaRunning = false
        }
    }

    private func labeledField(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextField("", text: text).textFieldStyle(.roundedBorder)
        }
    }

    private func labeledEditor(_ label: String, text: Binding<String>, minHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextEditor(text: text)
                .font(.body)
                .frame(minHeight: minHeight)
                .padding(4)
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.secondary.opacity(0.3)))
        }
    }

    // MARK: - Data

    private func reload() async {
        guard let app = selectedApp else { return }
        await ascService.loadVersions(for: app.id)
        if selectedVersionId == nil || !(ascService.versions.contains { $0.id == selectedVersionId }) {
            selectedVersionId = ascService.versions.first?.id
        }
        if let vid = selectedVersionId { await loadLocalizations(vid) }
    }

    private func loadLocalizations(_ versionId: String) async {
        await ascService.loadVersionLocalizations(versionId: versionId)
        let locales = ascService.versionLocalizations.map(\.locale)
        if selectedLocale == nil || !locales.contains(selectedLocale!) {
            selectedLocale = locales.first
        }
        if compareLocale == nil || !locales.contains(compareLocale!) {
            compareLocale = locales.first(where: { $0 != selectedLocale }) ?? selectedLocale
        }
        populateFields()
    }

    private func populateFields() {
        guard let locale = selectedLocale,
              let l = ascService.versionLocalizations.first(where: { $0.locale == locale }) else { return }
        descriptionText = l.description ?? ""
        keywords = l.keywords ?? ""
        whatsNew = l.whatsNew ?? ""
        promotional = l.promotionalText ?? ""
        supportUrl = l.supportUrl ?? ""
        marketingUrl = l.marketingUrl ?? ""
        resultText = nil
    }

    private func save() {
        guard let vid = selectedVersionId, let locale = selectedLocale else { return }
        isSaving = true
        resultText = nil
        Task {
            let result = await ascService.updateLocalization(
                versionId: vid,
                locale: locale,
                description: descriptionText,
                keywords: keywords,
                whatsNew: whatsNew,
                promotionalText: promotional,
                supportUrl: supportUrl.isEmpty ? nil : supportUrl,
                marketingUrl: marketingUrl.isEmpty ? nil : marketingUrl
            )
            isSaving = false
            resultText = result.succeeded ? loc(.mdSaved) : result.errorMessage
            if result.succeeded { await loadLocalizations(vid) }
        }
    }
}
