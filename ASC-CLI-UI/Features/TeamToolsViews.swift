import SwiftUI
import ASCShared

// MARK: - Team & Devices

struct TeamView: View {
    @EnvironmentObject var ascService: ASCService
    @EnvironmentObject var loc: LocalizationManager

    @State private var tab = 0
    @State private var email = ""
    @State private var roles = "ADMIN"
    @State private var allApps = true
    @State private var deviceName = ""
    @State private var udid = ""
    @State private var platform = "IOS"

    var body: some View {
        CommandScreen(title: loc(.secTeam), intro: loc(.tmBody)) { run, isRunning in
            Picker("", selection: $tab) {
                Text(loc(.tmUsers)).tag(0)
                Text(loc(.tmDevices)).tag(1)
                Text(loc(.tmSandbox)).tag(2)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch tab {
            case 1: devicesPane(run, isRunning)
            case 2:
                actionBox(isRunning) {
                    Button { run { await ascService.sandboxList() } } label: {
                        Label(loc(.actList), systemImage: "person.crop.circle.badge.questionmark")
                    }
                }
            default: usersPane(run, isRunning)
            }
        }
    }

    private func usersPane(_ run: @escaping (@escaping () async -> CommandResult) -> Void, _ isRunning: Bool) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Button { run { await ascService.usersList() } } label: {
                        Label(loc(.actList), systemImage: "person.2")
                    }
                    if isRunning { ProgressView().controlSize(.small) }
                    Spacer()
                }
                Divider()
                FlowButtons {
                    TextField(loc(.tmEmail), text: $email)
                        .textFieldStyle(.roundedBorder).frame(maxWidth: 220)
                    TextField(loc(.tmRoles), text: $roles)
                        .textFieldStyle(.roundedBorder).frame(maxWidth: 160)
                    Toggle(loc(.tmAllApps), isOn: $allApps).toggleStyle(.checkbox)
                    Button { run { await ascService.usersInvite(email: email, roles: roles, allApps: allApps) } } label: {
                        Label(loc(.tmInvite), systemImage: "envelope")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRunning || email.isEmpty || roles.isEmpty)
                }
            }.padding(6)
        }
    }

    private func devicesPane(_ run: @escaping (@escaping () async -> CommandResult) -> Void, _ isRunning: Bool) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Button { run { await ascService.devicesList() } } label: {
                        Label(loc(.actList), systemImage: "iphone")
                    }
                    Button { run { await ascService.deviceLocalUdid() } } label: {
                        Label(loc(.tmLocalUdid), systemImage: "desktopcomputer")
                    }
                    if isRunning { ProgressView().controlSize(.small) }
                    Spacer()
                }
                Divider()
                FlowButtons {
                    TextField(loc(.tmDeviceName), text: $deviceName)
                        .textFieldStyle(.roundedBorder).frame(maxWidth: 170)
                    TextField(loc(.tmUdid), text: $udid)
                        .textFieldStyle(.roundedBorder).font(.system(.body, design: .monospaced)).frame(maxWidth: 220)
                    TextField(loc(.smPlatform), text: $platform)
                        .textFieldStyle(.roundedBorder).frame(maxWidth: 100)
                    Button { run { await ascService.deviceRegister(name: deviceName, udid: udid, platform: platform) } } label: {
                        Label(loc(.actRegister), systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRunning || deviceName.isEmpty || udid.isEmpty || platform.isEmpty)
                }
            }.padding(6)
        }
    }
}

// MARK: - Tools (account, diagnostics, webhooks, fastlane)

struct ToolsView: View {
    @EnvironmentObject var ascService: ASCService
    @EnvironmentObject var loc: LocalizationManager
    let selectedApp: ASCApp?

    @State private var tab = 0
    @State private var webhookId = ""
    @State private var versionId = ""
    @State private var fastlaneDir = ""

    var body: some View {
        CommandScreen(title: loc(.secTools), subtitle: selectedApp?.name, intro: loc(.tlBody)) { run, isRunning in
            Picker("", selection: $tab) {
                Text(loc(.tlAccount)).tag(0)
                Text(loc(.tlWebhooks)).tag(1)
                Text(loc(.tlFastlane)).tag(2)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch tab {
            case 1: webhooksPane(run, isRunning)
            case 2: fastlanePane(run, isRunning)
            default:
                actionBox(isRunning) {
                    Button { run { await ascService.accountStatus(appId: selectedApp?.id) } } label: {
                        Label(loc(.actStatus), systemImage: "heart.text.square")
                    }
                    Button { run { await ascService.authDoctor() } } label: {
                        Label(loc(.actDoctor), systemImage: "stethoscope")
                    }
                }
            }
        }
    }

    private func webhooksPane(_ run: @escaping (@escaping () async -> CommandResult) -> Void, _ isRunning: Bool) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Button { if let a = selectedApp { run { await ascService.webhooksList(appId: a.id) } } } label: {
                        Label(loc(.actList), systemImage: "bell.badge")
                    }.disabled(isRunning || selectedApp == nil)
                    if selectedApp == nil { Text(loc(.selectAppFromApps)).font(.caption).foregroundStyle(.orange) }
                    if isRunning { ProgressView().controlSize(.small) }
                    Spacer()
                }
                Divider()
                FlowButtons {
                    TextField(loc(.tlWebhookId), text: $webhookId)
                        .textFieldStyle(.roundedBorder).font(.system(.body, design: .monospaced)).frame(maxWidth: 240)
                    Button { run { await ascService.webhookPing(webhookId: webhookId) } } label: {
                        Label(loc(.actPing), systemImage: "wave.3.right")
                    }.disabled(isRunning || webhookId.isEmpty)
                    Button { run { await ascService.webhookDeliveries(webhookId: webhookId) } } label: {
                        Label(loc(.actDeliveries), systemImage: "shippingbox")
                    }.disabled(isRunning || webhookId.isEmpty)
                }
            }.padding(6)
        }
    }

    private func fastlanePane(_ run: @escaping (@escaping () async -> CommandResult) -> Void, _ isRunning: Bool) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Text(loc(.distAppNote)).font(.caption).foregroundStyle(.tertiary)
                HStack(spacing: 10) {
                    TextField(loc(.tlVersionId), text: $versionId)
                        .textFieldStyle(.roundedBorder).font(.system(.body, design: .monospaced)).frame(maxWidth: 200)
                    PathPickerRow(label: loc(.tlFastlaneDir), path: $fastlaneDir, chooseTitle: loc(.rpChooseFolder)) {
                        FilePanel.pickDirectory()
                    }
                }
                FlowButtons {
                    Button {
                        if let a = selectedApp { run { await ascService.migrateImport(appId: a.id, versionId: versionId, fastlaneDir: fastlaneDir) } }
                    } label: { Label(loc(.tlMigrateImport), systemImage: "square.and.arrow.down") }
                    .disabled(isRunning || selectedApp == nil || versionId.isEmpty || fastlaneDir.isEmpty)
                    Button {
                        if let a = selectedApp { run { await ascService.migrateExport(appId: a.id, versionId: versionId, outputDir: fastlaneDir) } }
                    } label: { Label(loc(.tlMigrateExport), systemImage: "square.and.arrow.up") }
                    .disabled(isRunning || selectedApp == nil || versionId.isEmpty || fastlaneDir.isEmpty)
                    if isRunning { ProgressView().controlSize(.small) }
                }
            }.padding(6)
        }
    }
}
