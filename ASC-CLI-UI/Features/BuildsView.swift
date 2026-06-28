import SwiftUI
import ASCShared

struct BuildsView: View {
    @EnvironmentObject var ascService: ASCService
    @EnvironmentObject var loc: LocalizationManager
    let selectedApp: ASCApp?

    @State private var showUpload = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(loc(.buildsTitle))
                        .font(.title2)
                        .fontWeight(.semibold)
                    if let app = selectedApp {
                        Text(app.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button {
                    showUpload = true
                } label: {
                    Label(loc(.buUpload), systemImage: "arrow.up.circle")
                }
                .disabled(selectedApp == nil)
                Button {
                    if let app = selectedApp {
                        Task { await ascService.loadBuilds(for: app.id) }
                    }
                } label: {
                    Label(loc(.refresh), systemImage: "arrow.clockwise")
                }
                .disabled(ascService.isLoading || selectedApp == nil)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider()

            if selectedApp == nil {
                noAppSelected
            } else if ascService.builds.isEmpty && !ascService.isLoading {
                emptyState
            } else {
                buildsTable
            }
        }
        .task(id: selectedApp?.id) {
            if let app = selectedApp { await ascService.ensureBuilds(for: app.id) }
        }
        .sheet(isPresented: $showUpload) {
            if let app = selectedApp {
                BuildUploadSheet(app: app)
            }
        }
    }

    private var noAppSelected: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.left")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text(loc(.selectAppInApps))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "hammer.slash")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(loc(.noBuilds))
                .font(.title3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var buildsTable: some View {
        Table(ascService.builds) {
            TableColumn(loc(.colBuild)) { build in
                Text(build.buildNumber)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)
            }
            TableColumn(loc(.colStatus)) { build in
                BuildStatusBadge(state: build.processingState)
            }
            TableColumn(loc(.colMinOS)) { build in
                Text(build.minOsVersion ?? "—")
                    .foregroundStyle(.secondary)
            }
            TableColumn(loc(.colUploaded)) { build in
                if let date = build.uploadedDate {
                    Text(formatDate(date))
                        .foregroundStyle(.secondary)
                } else {
                    Text("—").foregroundStyle(.tertiary)
                }
            }
            TableColumn(loc(.colExpires)) { build in
                if let date = build.expirationDate {
                    Text(formatDate(date))
                        .foregroundStyle(.secondary)
                } else {
                    Text("—").foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let rel = RelativeDateTimeFormatter()
            rel.unitsStyle = .abbreviated
            return rel.localizedString(for: date, relativeTo: .now)
        }
        return dateString
    }
}

struct BuildUploadSheet: View {
    @EnvironmentObject var ascService: ASCService
    @EnvironmentObject var loc: LocalizationManager
    @Environment(\.dismiss) private var dismiss
    let app: ASCApp

    enum Kind: String, CaseIterable { case ipa, pkg }
    @State private var kind: Kind = .ipa
    @State private var filePath = ""
    @State private var version = ""
    @State private var buildNumber = ""
    @State private var dryRun = true
    @State private var isRunning = false
    @State private var output: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(loc(.buUploadTitle)).font(.title3.weight(.semibold))
                Spacer()
                Text(app.name).font(.caption).foregroundStyle(.secondary)
            }
            .padding(20)
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Picker("", selection: $kind) {
                        Text("IPA (iOS/tvOS/visionOS)").tag(Kind.ipa)
                        Text("PKG (macOS)").tag(Kind.pkg)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    PathPickerRow(label: loc(.buFile), path: $filePath, chooseTitle: loc(.rpChooseFolder)) {
                        FilePanel.pickFile(extensions: [kind.rawValue])
                    }

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(loc(.buVersion)).font(.caption).foregroundStyle(.secondary)
                            TextField(loc(.buAutoExtract), text: $version).textFieldStyle(.roundedBorder)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(loc(.buBuildNumber)).font(.caption).foregroundStyle(.secondary)
                            TextField(loc(.buAutoExtract), text: $buildNumber).textFieldStyle(.roundedBorder)
                        }
                    }

                    Toggle(loc(.buDryRun), isOn: $dryRun).toggleStyle(.checkbox)
                    Text(loc(.buDryRunHint)).font(.caption2).foregroundStyle(.tertiary)

                    if let output {
                        OutputPanel(title: loc(.output), text: output)
                    }
                }
                .padding(20)
            }

            Divider()
            HStack {
                Button(loc(.cancel)) { dismiss() }
                Spacer()
                Button {
                    upload()
                } label: {
                    if isRunning {
                        HStack(spacing: 6) { ProgressView().controlSize(.small); Text(loc(.buUploading)) }
                    } else {
                        Label(dryRun ? loc(.buDryRunAction) : loc(.buUpload),
                              systemImage: dryRun ? "checklist" : "arrow.up.circle")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRunning || filePath.isEmpty)
            }
            .padding(20)
        }
        .frame(width: 560, height: 540)
    }

    private func upload() {
        isRunning = true
        output = nil
        Task {
            let result = await ascService.uploadBuild(
                appId: app.id,
                ipaPath: kind == .ipa ? filePath : nil,
                pkgPath: kind == .pkg ? filePath : nil,
                version: version,
                buildNumber: buildNumber,
                dryRun: dryRun
            )
            output = result.succeeded ? (result.output.isEmpty ? "✓" : result.output) : result.errorMessage
            isRunning = false
            if result.succeeded && !dryRun { await ascService.loadBuilds(for: app.id) }
        }
    }
}

struct BuildStatusBadge: View {
    let state: String

    var color: Color {
        switch state.uppercased() {
        case "VALID", "PROCESSING_COMPLETE": return .green
        case "PROCESSING": return .orange
        case "FAILED", "INVALID": return .red
        default: return .secondary
        }
    }

    var label: String {
        switch state.uppercased() {
        case "PROCESSING_COMPLETE": return "Ready"
        case "PROCESSING": return "Processing"
        case "FAILED": return "Failed"
        case "INVALID": return "Invalid"
        default: return state.capitalized
        }
    }

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.caption)
                .foregroundStyle(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color.opacity(0.12), in: Capsule())
    }
}
