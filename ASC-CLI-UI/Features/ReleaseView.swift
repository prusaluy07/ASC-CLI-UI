import SwiftUI
import AppKit

struct ReleaseView: View {
    @EnvironmentObject var ascService: ASCService
    @EnvironmentObject var loc: LocalizationManager
    let selectedApp: ASCApp?

    @State private var validateOutput: String?
    @State private var isValidating = false
    @State private var isReleasing = false
    @State private var showReleaseConfirm = false

    // Publish flow
    @State private var ipaPath = ""
    @State private var publishVersion = ""
    @State private var metadataDir = ""
    @State private var submitForReview = false
    @State private var publishDryRun = true
    @State private var isPublishing = false
    @State private var showPublishConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(title: loc(.releaseTitle), subtitle: selectedApp?.name) {
                Button {
                    if let app = selectedApp { Task { await ascService.loadStatus(for: app.id) } }
                } label: {
                    Label(loc(.refresh), systemImage: "arrow.clockwise")
                }
                .disabled(ascService.isLoading || selectedApp == nil)
            }
            Divider()

            if selectedApp == nil {
                ContentUnavailableView(loc(.noAppSelectedTitle), systemImage: "paperplane",
                                       description: Text(loc(.pickAppToolbar)))
            } else {
                content
            }
        }
        .task(id: selectedApp?.id) {
            if let app = selectedApp {
                await ascService.ensureStatus(for: app.id)
                if publishVersion.isEmpty {
                    publishVersion = ascService.statusReport?.appstore?.version ?? ""
                }
            }
        }
        .alert(loc(.relReleaseConfirmTitle), isPresented: $showReleaseConfirm) {
            Button(loc(.relNo), role: .cancel) {}
            Button(loc(.relYes), role: .destructive) { release() }
        } message: {
            Text(loc(.relReleaseConfirmMsg))
        }
        .alert(loc(.pubConfirmTitle), isPresented: $showPublishConfirm) {
            Button(loc(.cancel), role: .cancel) {}
            Button(loc(.pubSubmit), role: .destructive) { publish() }
        } message: {
            Text(loc(.pubConfirmMsg))
        }
    }

    @ViewBuilder
    private var content: some View {
        if let status = ascService.statusReport {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    healthCard(status)
                    detailsCard(status)
                    actionsCard(status)
                    publishCard
                    if let validateOutput {
                        outputCard(validateOutput)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else if !ascService.isLoading {
            ContentUnavailableView(loc(.relNoStatus), systemImage: "antenna.radiowaves.left.and.right")
        } else {
            Spacer()
        }
    }

    private func healthCard(_ status: ASCStatusReport) -> some View {
        let health = status.summary?.health ?? "—"
        return GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Circle().fill(healthColor(health)).frame(width: 12, height: 12)
                    Text(health.capitalized).font(.title3.weight(.semibold))
                    Spacer()
                }
                if let next = status.summary?.nextAction {
                    labeled(loc(.relNextAction), next)
                }
                if let blockers = status.summary?.blockers, !blockers.isEmpty {
                    labeled(loc(.relBlockers), blockers.joined(separator: "\n"))
                        .foregroundStyle(.orange)
                }
            }
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label(loc(.relHealth), systemImage: "heart.text.square")
        }
    }

    private func detailsCard(_ status: ASCStatusReport) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                if let b = status.builds?.latest {
                    labeled(loc(.relLatestBuild),
                            "\(b.version ?? "—") (\(b.buildNumber ?? "—")) · \(b.processingState ?? "—")")
                }
                if let a = status.appstore {
                    labeled(loc(.relAppStoreState), "\(a.version ?? "—") · \(stateText(a.state))")
                }
                if let r = status.review?.state {
                    labeled(loc(.relReviewState), stateText(r))
                }
                if let tf = status.testflight?.betaReviewState {
                    labeled(loc(.relTestflightState), stateText(tf))
                }
                if let p = status.phasedRelease?.configured {
                    labeled(loc(.relPhased), p ? loc(.relConfigured) : "—")
                }
            }
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label(selectedApp?.name ?? "", systemImage: "info.circle")
        }
    }

    private func actionsCard(_ status: ASCStatusReport) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Button {
                        runValidate(status)
                    } label: {
                        if isValidating {
                            HStack(spacing: 6) { ProgressView().controlSize(.small); Text(loc(.relValidating)) }
                        } else {
                            Label(loc(.relValidate), systemImage: "checklist")
                        }
                    }
                    .disabled(isValidating || status.appstore?.versionId == nil)

                    if let link = status.links?.appStoreConnect, let url = URL(string: link) {
                        Button {
                            NSWorkspace.shared.open(url)
                        } label: {
                            Label(loc(.relOpenASC), systemImage: "arrow.up.right.square")
                        }
                    }
                    Spacer()
                }

                // Developer-release is only meaningful for an approved, pending-release version.
                if canReleaseNow(status) {
                    Button {
                        showReleaseConfirm = true
                    } label: {
                        if isReleasing {
                            HStack(spacing: 6) { ProgressView().controlSize(.small); Text(loc(.relReleasing)) }
                        } else {
                            Label(loc(.relReleaseNow), systemImage: "paperplane.fill")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .disabled(isReleasing)
                }
            }
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label(loc(.releaseTitle), systemImage: "shippingbox")
        }
    }

    private var publishCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Text(loc(.pubBody)).font(.callout).foregroundStyle(.secondary)

                PathPickerRow(label: loc(.pubIpa), path: $ipaPath, chooseTitle: loc(.rpChooseFolder)) {
                    FilePanel.pickFile(extensions: ["ipa"])
                }

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(loc(.pubVersion)).font(.caption).foregroundStyle(.secondary)
                        TextField("1.2.3", text: $publishVersion).textFieldStyle(.roundedBorder)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(loc(.pubMetadataDir)).font(.caption).foregroundStyle(.secondary)
                        HStack {
                            Text(metadataDir.isEmpty ? loc(.pubOptional) : metadataDir)
                                .font(.system(.caption, design: .monospaced))
                                .lineLimit(1).truncationMode(.middle)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Button(loc(.rpChooseFolder)) {
                                if let d = FilePanel.pickDirectory() { metadataDir = d }
                            }
                        }
                    }
                }

                Toggle(loc(.pubSubmitForReview), isOn: $submitForReview).toggleStyle(.checkbox)
                Toggle(loc(.buDryRun), isOn: $publishDryRun).toggleStyle(.checkbox)

                HStack {
                    Spacer()
                    Button {
                        if submitForReview && !publishDryRun {
                            showPublishConfirm = true
                        } else {
                            publish()
                        }
                    } label: {
                        if isPublishing {
                            HStack(spacing: 6) { ProgressView().controlSize(.small); Text(loc(.pubRunning)) }
                        } else {
                            Label(publishLabel, systemImage: "paperplane.fill")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(submitForReview && !publishDryRun ? .orange : .accentColor)
                    .disabled(isPublishing || ipaPath.isEmpty || publishVersion.isEmpty)
                }
            }
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label(loc(.pubTitle), systemImage: "square.and.arrow.up.on.square")
        }
    }

    private var publishLabel: String {
        if publishDryRun { return loc(.buDryRunAction) }
        return submitForReview ? loc(.pubSubmit) : loc(.pubUploadOnly)
    }

    private func publish() {
        guard let app = selectedApp else { return }
        isPublishing = true
        validateOutput = nil
        Task {
            let result = await ascService.publishAppStore(
                appId: app.id,
                ipaPath: ipaPath,
                version: publishVersion,
                metadataDir: metadataDir.isEmpty ? nil : metadataDir,
                submit: submitForReview,
                dryRun: publishDryRun
            )
            validateOutput = result.succeeded ? (result.output.isEmpty ? "✓" : result.output) : result.errorMessage
            isPublishing = false
            await ascService.loadStatus(for: app.id)
        }
    }

    private func outputCard(_ text: String) -> some View {
        GroupBox {
            ScrollView {
                Text(text)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 280)
            .padding(6)
        } label: {
            Label(loc(.relResultTitle), systemImage: "doc.plaintext")
        }
    }

    // MARK: - Helpers

    private func labeled(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 130, alignment: .leading)
            Text(value)
                .font(.callout)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func stateText(_ s: String?) -> String {
        (s ?? "—").capitalized.replacingOccurrences(of: "_", with: " ")
    }

    private func healthColor(_ h: String) -> Color {
        switch h.lowercased() {
        case "green": return .green
        case "yellow", "orange": return .orange
        case "red": return .red
        default: return .secondary
        }
    }

    private func canReleaseNow(_ status: ASCStatusReport) -> Bool {
        (status.appstore?.state ?? "").uppercased() == "PENDING_DEVELOPER_RELEASE"
            && status.appstore?.versionId != nil
    }

    private func runValidate(_ status: ASCStatusReport) {
        guard let app = selectedApp, let vid = status.appstore?.versionId else { return }
        isValidating = true
        validateOutput = nil
        Task {
            let result = await ascService.validate(appId: app.id, versionId: vid)
            validateOutput = result.succeeded ? result.output : result.errorMessage
            isValidating = false
        }
    }

    private func release() {
        guard let vid = ascService.statusReport?.appstore?.versionId else { return }
        isReleasing = true
        Task {
            let result = await ascService.releaseVersion(versionId: vid)
            validateOutput = result.succeeded ? result.output : result.errorMessage
            isReleasing = false
            if let app = selectedApp { await ascService.loadStatus(for: app.id) }
        }
    }
}
