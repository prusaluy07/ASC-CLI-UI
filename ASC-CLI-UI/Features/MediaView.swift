import SwiftUI
import ASCShared

struct MediaView: View {
    @EnvironmentObject var ascService: ASCService
    @EnvironmentObject var loc: LocalizationManager
    let selectedApp: ASCApp?

    @State private var selectedVersionId: String?
    @State private var selectedLocale: String?
    @State private var tab = 0
    @State private var deviceType = DeviceType.all.first ?? "IPHONE_67"
    @State private var output: String?
    @State private var isRunning = false

    private var localizationId: String? {
        ascService.versionLocalizations.first(where: { $0.locale == selectedLocale })?.id
    }

    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(title: loc(.mediaTitle), subtitle: selectedApp?.name) {
                Button { Task { await reload() } } label: {
                    Label(loc(.refresh), systemImage: "arrow.clockwise")
                }
                .disabled(ascService.isLoading || selectedApp == nil)
            }
            Divider()

            if selectedApp == nil {
                ContentUnavailableView(loc(.noAppSelectedTitle), systemImage: "photo.on.rectangle",
                                       description: Text(loc(.mdPickAppVersion)))
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        pickers
                        Picker("", selection: $tab) {
                            Text(loc(.mediaScreenshots)).tag(0)
                            Text(loc(.mediaPreviews)).tag(1)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()

                        if localizationId == nil {
                            Text(loc(.mdNoLocalizations)).foregroundStyle(.secondary)
                        } else if tab == 0 {
                            screenshotActions
                        } else {
                            previewActions
                        }

                        if let output { OutputPanel(title: loc(.output), text: output) }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .task(id: selectedApp?.id) { await reload() }
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
                .labelsHidden().frame(minWidth: 220)
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
                    .labelsHidden().frame(minWidth: 140)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(loc(.mediaDevice)).font(.caption).foregroundStyle(.secondary)
                Picker("", selection: $deviceType) {
                    ForEach(DeviceType.all, id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden().frame(minWidth: 180)
            }
            Spacer()
        }
    }

    private var screenshotActions: some View {
        HStack(spacing: 12) {
            actionButton(loc(.mediaList), "list.bullet") { _ in
                await ascService.screenshotsList(versionLocalizationId: localizationId!)
            }
            actionButton(loc(.mediaSizes), "ruler") { _ in
                await ascService.screenshotSizes()
            }
            actionButton(loc(.mediaUpload), "arrow.up.circle", needsFolder: true) { dir in
                await ascService.screenshotsUpload(versionLocalizationId: localizationId!, path: dir, deviceType: deviceType)
            }
            actionButton(loc(.mediaDownload), "arrow.down.circle", needsFolder: true) { dir in
                await ascService.screenshotsDownload(versionLocalizationId: localizationId!, outputDir: dir)
            }
            Spacer()
            if isRunning { ProgressView().controlSize(.small) }
        }
    }

    private var previewActions: some View {
        HStack(spacing: 12) {
            actionButton(loc(.mediaList), "list.bullet") { _ in
                await ascService.videoPreviewsList(versionLocalizationId: localizationId!)
            }
            actionButton(loc(.mediaUpload), "arrow.up.circle", needsFolder: true) { dir in
                await ascService.videoPreviewsUpload(versionLocalizationId: localizationId!, path: dir, deviceType: deviceType)
            }
            actionButton(loc(.mediaDownload), "arrow.down.circle", needsFolder: true) { dir in
                await ascService.videoPreviewsDownload(versionLocalizationId: localizationId!, outputDir: dir)
            }
            Spacer()
            if isRunning { ProgressView().controlSize(.small) }
        }
    }

    @ViewBuilder
    private func actionButton(_ title: String, _ icon: String,
                              needsFolder: Bool = false,
                              op: @escaping (String) async -> CommandResult) -> some View {
        Button {
            if needsFolder {
                if let dir = FilePanel.pickDirectory() { run { await op(dir) } }
            } else {
                run { await op("") }
            }
        } label: {
            Label(title, systemImage: icon)
        }
        .disabled(isRunning)
    }

    private func run(_ operation: @escaping () async -> CommandResult) {
        isRunning = true
        output = nil
        Task {
            let result = await operation()
            output = result.succeeded ? (result.output.isEmpty ? "✓" : result.output) : result.errorMessage
            isRunning = false
        }
    }

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
        if selectedLocale == nil || !(ascService.versionLocalizations.contains { $0.locale == selectedLocale }) {
            selectedLocale = ascService.versionLocalizations.first?.locale
        }
    }
}
