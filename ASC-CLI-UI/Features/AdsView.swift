import SwiftUI
import ASCShared

/// Apple Ads (Search Ads) campaign management. Uses separate Apple Ads OAuth credentials
/// from the App Store Connect API key, and an organization ID shared across the tabs.
struct AdsView: View {
    @EnvironmentObject var ascService: ASCService
    @EnvironmentObject var loc: LocalizationManager

    @State private var tab = 0
    @State private var output: String?
    @State private var isRunning = false

    // Auth form
    @State private var name = "Ads"
    @State private var clientId = ""
    @State private var teamId = ""
    @State private var keyId = ""
    @State private var privateKey = ""
    @State private var isLoggingIn = false

    // Query inputs
    @State private var campaign = ""
    @State private var adGroup = ""
    @State private var payloadFile = ""

    private var org: String { ascService.adsOrg.trimmingCharacters(in: .whitespaces) }
    private var hasOrg: Bool { !org.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(title: loc(.grpAds), subtitle: nil) { EmptyView() }
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(loc(.adsBody)).font(.callout).foregroundStyle(.secondary)
                    orgCard

                    Picker("", selection: $tab) {
                        Text(loc(.adsTabAuth)).tag(0)
                        Text(loc(.adsTabCampaigns)).tag(1)
                        Text(loc(.adsTabAdGroups)).tag(2)
                        Text(loc(.adsTabKeywords)).tag(3)
                        Text(loc(.adsTabReports)).tag(4)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    switch tab {
                    case 1: campaignsPane
                    case 2: adGroupsPane
                    case 3: keywordsPane
                    case 4: reportsPane
                    default: authPane
                    }

                    if let output { OutputPanel(title: loc(.output), text: output, maxHeight: 380) }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var orgCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                Text(loc(.adsOrg)).font(.caption).foregroundStyle(.secondary)
                HStack {
                    TextField("123456", text: $ascService.adsOrg)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: 260)
                        .onChange(of: ascService.adsOrg) { _, _ in ascService.saveSettings() }
                }
                Text(loc(.adsOrgHint)).font(.caption2).foregroundStyle(.tertiary)
            }
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label(loc(.adsOrg), systemImage: "building.2")
        }
    }

    // MARK: - Auth

    private var authPane: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Text(loc(.adsAuthBody)).font(.callout).foregroundStyle(.secondary)

                HStack {
                    Button { run { await ascService.adsAuthStatus() } } label: {
                        Label(loc(.adsAuthStatusBtn), systemImage: "person.badge.shield.checkmark")
                    }
                    Button { run { await ascService.adsAuthDiscover() } } label: {
                        Label(loc(.adsDiscover), systemImage: "sparkle.magnifyingglass")
                    }
                    Button { run { await ascService.adsViewMe() } } label: {
                        Label(loc(.adsViewMe), systemImage: "person.crop.circle")
                    }
                    if isRunning { ProgressView().controlSize(.small) }
                }

                Divider()

                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                    GridRow {
                        Text(loc(.adsName)).gridColumnAlignment(.trailing).foregroundStyle(.secondary)
                        TextField("Ads", text: $name).textFieldStyle(.roundedBorder)
                    }
                    GridRow {
                        Text(loc(.adsClientId)).gridColumnAlignment(.trailing).foregroundStyle(.secondary)
                        TextField("SEARCHADS.xxxx", text: $clientId).textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    }
                    GridRow {
                        Text(loc(.adsTeamId)).gridColumnAlignment(.trailing).foregroundStyle(.secondary)
                        TextField("SEARCHADS.xxxx", text: $teamId).textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    }
                    GridRow {
                        Text(loc(.adsKeyId)).gridColumnAlignment(.trailing).foregroundStyle(.secondary)
                        TextField("KEY_ID", text: $keyId).textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    }
                }

                PathPickerRow(label: loc(.adsPrivateKey), path: $privateKey, chooseTitle: loc(.rpChooseFolder)) {
                    FilePanel.pickFile(extensions: ["pem", "p8", "key"])
                }
                Text(loc(.adsPrivateKeyHint)).font(.caption2).foregroundStyle(.tertiary)

                HStack {
                    Spacer()
                    Button { login() } label: {
                        if isLoggingIn {
                            HStack(spacing: 6) { ProgressView().controlSize(.small); Text(loc(.adsLoggingIn)) }
                        } else {
                            Label(loc(.adsLoginBtn), systemImage: "key.horizontal")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoggingIn || clientId.isEmpty || teamId.isEmpty || keyId.isEmpty || privateKey.isEmpty)
                }
            }
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label(loc(.adsTabAuth), systemImage: "lock.shield")
        }
    }

    // MARK: - Query panes

    private var campaignsPane: some View {
        actionPane {
            Button { runOrg { await ascService.adsCampaignsList(org: org) } } label: {
                Label(loc(.adsListCampaigns), systemImage: "list.bullet.rectangle")
            }
            .disabled(isRunning || !hasOrg)
        }
    }

    private var adGroupsPane: some View {
        actionPane {
            TextField(loc(.adsCampaign), text: $campaign)
                .textFieldStyle(.roundedBorder).font(.system(.body, design: .monospaced)).frame(maxWidth: 200)
            Button {
                guard !campaign.isEmpty else { output = loc(.adsNeedCampaign); return }
                runOrg { await ascService.adsAdGroupsList(org: org, campaign: campaign) }
            } label: {
                Label(loc(.adsListAdGroups), systemImage: "rectangle.stack")
            }
            .disabled(isRunning || !hasOrg)
        }
    }

    private var keywordsPane: some View {
        actionPane {
            TextField(loc(.adsCampaign), text: $campaign)
                .textFieldStyle(.roundedBorder).font(.system(.body, design: .monospaced)).frame(maxWidth: 170)
            TextField(loc(.adsAdGroup), text: $adGroup)
                .textFieldStyle(.roundedBorder).font(.system(.body, design: .monospaced)).frame(maxWidth: 170)
            Button {
                guard !campaign.isEmpty, !adGroup.isEmpty else { output = loc(.adsNeedAdGroup); return }
                runOrg { await ascService.adsTargetingKeywords(org: org, campaign: campaign, adGroup: adGroup) }
            } label: {
                Label(loc(.adsListKeywords), systemImage: "key")
            }
            .disabled(isRunning || !hasOrg)
        }
    }

    private var reportsPane: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Text(loc(.adsReportsBody)).font(.callout).foregroundStyle(.secondary)
                PathPickerRow(label: loc(.adsPayloadFile), path: $payloadFile, chooseTitle: loc(.rpChooseFolder)) {
                    FilePanel.pickFile(extensions: ["json"])
                }
                HStack {
                    if !hasOrg { Text(loc(.adsNeedOrg)).font(.caption).foregroundStyle(.orange) }
                    Spacer()
                    Button { runOrg { await ascService.adsReportCampaigns(org: org, payloadFile: payloadFile) } } label: {
                        Label(loc(.adsRunReport), systemImage: "chart.bar.doc.horizontal")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRunning || !hasOrg || payloadFile.isEmpty)
                    if isRunning { ProgressView().controlSize(.small) }
                }
            }
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label(loc(.adsTabReports), systemImage: "chart.bar")
        }
    }

    @ViewBuilder
    private func actionPane<Controls: View>(@ViewBuilder _ controls: () -> Controls) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                if !hasOrg {
                    Text(loc(.adsNeedOrg)).font(.caption).foregroundStyle(.orange)
                }
                HStack(spacing: 10) {
                    controls()
                    if isRunning { ProgressView().controlSize(.small) }
                    Spacer()
                }
            }
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Actions

    private func login() {
        isLoggingIn = true
        output = nil
        Task {
            let result = await ascService.adsLogin(name: name, clientId: clientId, teamId: teamId,
                                                   keyId: keyId, privateKeyPath: privateKey, org: org)
            output = result.succeeded ? (result.output.isEmpty ? "✓" : result.output) : result.errorMessage
            isLoggingIn = false
        }
    }

    private func runOrg(_ operation: @escaping () async -> CommandResult) {
        guard hasOrg else { output = loc(.adsNeedOrg); return }
        run(operation)
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
}
