import SwiftUI

// MARK: - Marketing (custom product pages, experiments, pre-orders, featuring nominations)

struct MarketingView: View {
    @EnvironmentObject var ascService: ASCService
    @EnvironmentObject var loc: LocalizationManager
    let selectedApp: ASCApp?

    @State private var tab = 0

    // Product pages
    @State private var pageId = ""
    @State private var pageName = ""
    @State private var experimentVersionId = ""

    // Pre-orders
    @State private var territories = ""
    @State private var releaseDate = ""
    @State private var taId = ""

    // Nominations
    @State private var nomStatus = ""
    @State private var nomId = ""
    @State private var nomName = ""
    @State private var nomType = "APP_LAUNCH"
    @State private var nomDesc = ""
    @State private var nomSubmitted = false

    // Confirmation for mutating actions
    @State private var showConfirm = false
    @State private var pendingAction: (() async -> CommandResult)?

    private var appId: String? { selectedApp?.id }

    var body: some View {
        CommandScreen(title: loc(.secMarketing), subtitle: selectedApp?.name, intro: loc(.mkBody)) { run, isRunning in
            VStack(alignment: .leading, spacing: 16) {
                Picker("", selection: $tab) {
                    Text(loc(.mkProductPages)).tag(0)
                    Text(loc(.mkPreOrders)).tag(1)
                    Text(loc(.mkNominations)).tag(2)
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                if appId == nil && tab != 2 {
                    Label(loc(.mkAppNote), systemImage: "info.circle")
                        .font(.caption).foregroundStyle(.orange)
                }

                switch tab {
                case 1: preOrdersPane(run, isRunning)
                case 2: nominationsPane(run, isRunning)
                default: productPagesPane(run, isRunning)
                }
            }
            .confirmationDialog(loc(.mkConfirmTitle), isPresented: $showConfirm, titleVisibility: .visible) {
                Button(loc(.ok)) {
                    if let action = pendingAction { run(action) }
                    pendingAction = nil
                }
                Button(loc(.cancel), role: .cancel) { pendingAction = nil }
            } message: {
                Text(loc(.mkConfirmMsg))
            }
        }
    }

    private func confirm(_ action: @escaping () async -> CommandResult) {
        pendingAction = action
        showConfirm = true
    }

    // MARK: Product pages

    private func productPagesPane(_ run: @escaping (@escaping () async -> CommandResult) -> Void, _ isRunning: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            GroupBox(loc(.mkCustomPages)) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Button { if let a = appId { run { await ascService.customPagesList(appId: a) } } } label: {
                            Label(loc(.actList), systemImage: "doc.richtext")
                        }.disabled(isRunning || appId == nil)
                        if isRunning { ProgressView().controlSize(.small) }
                        Spacer()
                    }
                    Divider()
                    FlowButtons {
                        TextField(loc(.mkPageId), text: $pageId)
                            .textFieldStyle(.roundedBorder).font(.system(.body, design: .monospaced)).frame(maxWidth: 240)
                        Button { run { await ascService.customPageView(pageId: pageId) } } label: {
                            Label(loc(.actView), systemImage: "eye")
                        }.disabled(isRunning || pageId.isEmpty)
                    }
                    Divider()
                    FlowButtons {
                        TextField(loc(.mkPageName), text: $pageName)
                            .textFieldStyle(.roundedBorder).frame(maxWidth: 220)
                        Button {
                            if let a = appId { confirm { await ascService.customPageCreate(appId: a, name: pageName) } }
                        } label: {
                            Label(loc(.actCreate), systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isRunning || appId == nil || pageName.isEmpty)
                    }
                }.padding(6)
            }

            GroupBox(loc(.mkExperiments)) {
                FlowButtons {
                    Button { if let a = appId { run { await ascService.experimentsList(appId: a) } } } label: {
                        Label(loc(.actList), systemImage: "flask")
                    }.disabled(isRunning || appId == nil)
                    TextField(loc(.tlVersionId), text: $experimentVersionId)
                        .textFieldStyle(.roundedBorder).font(.system(.body, design: .monospaced)).frame(maxWidth: 200)
                    Button { run { await ascService.experimentsListByVersion(versionId: experimentVersionId) } } label: {
                        Label(loc(.actView), systemImage: "list.bullet")
                    }.disabled(isRunning || experimentVersionId.isEmpty)
                    if isRunning { ProgressView().controlSize(.small) }
                }.padding(6)
            }
        }
    }

    // MARK: Pre-orders

    private func preOrdersPane(_ run: @escaping (@escaping () async -> CommandResult) -> Void, _ isRunning: Bool) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Button { if let a = appId { run { await ascService.preOrderView(appId: a) } } } label: {
                        Label(loc(.actView), systemImage: "calendar.badge.clock")
                    }.disabled(isRunning || appId == nil)
                    if isRunning { ProgressView().controlSize(.small) }
                    Spacer()
                }
                Divider()
                FlowButtons {
                    TextField(loc(.mkTerritories), text: $territories)
                        .textFieldStyle(.roundedBorder).frame(maxWidth: 200)
                    TextField(loc(.mkReleaseDate), text: $releaseDate)
                        .textFieldStyle(.roundedBorder).frame(maxWidth: 180)
                    Button {
                        if let a = appId { confirm { await ascService.preOrderEnable(appId: a, territories: territories, releaseDate: releaseDate) } }
                    } label: {
                        Label(loc(.actEnable), systemImage: "checkmark.circle")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRunning || appId == nil || territories.isEmpty)
                }
                Divider()
                FlowButtons {
                    TextField(loc(.mkTaId), text: $taId)
                        .textFieldStyle(.roundedBorder).font(.system(.body, design: .monospaced)).frame(maxWidth: 260)
                    Button {
                        confirm { await ascService.preOrderDisable(territoryAvailabilityId: taId) }
                    } label: {
                        Label(loc(.actDisable), systemImage: "xmark.circle")
                    }.disabled(isRunning || taId.isEmpty)
                }
            }.padding(6)
        }
    }

    // MARK: Nominations

    private func nominationsPane(_ run: @escaping (@escaping () async -> CommandResult) -> Void, _ isRunning: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    FlowButtons {
                        TextField(loc(.mkStatus), text: $nomStatus)
                            .textFieldStyle(.roundedBorder).frame(maxWidth: 160)
                        Button { run { await ascService.nominationsList(status: nomStatus) } } label: {
                            Label(loc(.actList), systemImage: "star.circle")
                        }.disabled(isRunning)
                        TextField(loc(.mkNomId), text: $nomId)
                            .textFieldStyle(.roundedBorder).font(.system(.body, design: .monospaced)).frame(maxWidth: 200)
                        Button { run { await ascService.nominationView(id: nomId) } } label: {
                            Label(loc(.actView), systemImage: "eye")
                        }.disabled(isRunning || nomId.isEmpty)
                        Button {
                            confirm { await ascService.nominationDelete(id: nomId) }
                        } label: {
                            Label(loc(.actDelete), systemImage: "trash")
                        }.disabled(isRunning || nomId.isEmpty)
                        if isRunning { ProgressView().controlSize(.small) }
                    }
                }.padding(6)
            }

            GroupBox(loc(.actCreate)) {
                VStack(alignment: .leading, spacing: 10) {
                    FlowButtons {
                        TextField(loc(.mkNomName), text: $nomName)
                            .textFieldStyle(.roundedBorder).frame(maxWidth: 200)
                        TextField(loc(.mkNomType), text: $nomType)
                            .textFieldStyle(.roundedBorder).frame(maxWidth: 200)
                        Toggle(loc(.mkSubmitted), isOn: $nomSubmitted).toggleStyle(.checkbox)
                    }
                    TextField(loc(.mkNomDesc), text: $nomDesc, axis: .vertical)
                        .textFieldStyle(.roundedBorder).lineLimit(2...4)
                    Button {
                        if let a = appId {
                            confirm { await ascService.nominationCreate(appId: a, name: nomName, type: nomType, description: nomDesc, submitted: nomSubmitted) }
                        }
                    } label: {
                        Label(loc(.actCreate), systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRunning || appId == nil || nomName.isEmpty || nomType.isEmpty)
                }.padding(6)
            }
        }
    }
}
