import SwiftUI
import ASCShared

// MARK: - Submission / App Review lifecycle

struct SubmissionView: View {
    @EnvironmentObject var ascService: ASCService
    @EnvironmentObject var loc: LocalizationManager
    let selectedApp: ASCApp?

    @State private var tab = 0
    @State private var versionId = ""
    @State private var detailId = ""
    @State private var submissionId = ""
    @State private var platform = "IOS"
    @State private var buildId = ""
    @State private var sinceTag = ""

    var body: some View {
        CommandScreen(title: loc(.secSubmission), subtitle: selectedApp?.name, intro: loc(.smBody),
                      requireApp: true, hasApp: selectedApp != nil) { run, isRunning in
            Picker("", selection: $tab) {
                Text(loc(.smTabStatus)).tag(0)
                Text(loc(.smTabDetails)).tag(1)
                Text(loc(.smTabSubmissions)).tag(2)
                Text(loc(.smTabNotes)).tag(3)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch tab {
            case 1: detailsPane(run, isRunning)
            case 2: submissionsPane(run, isRunning)
            case 3: notesPane(run, isRunning)
            default: statusPane(run, isRunning)
            }
        }
    }

    private func statusPane(_ run: @escaping (@escaping () async -> CommandResult) -> Void, _ isRunning: Bool) -> some View {
        actionBox(isRunning) {
            Button { if let a = selectedApp { run { await ascService.reviewStatus(appId: a.id) } } } label: {
                Label(loc(.smReviewStatus), systemImage: "checkmark.circle")
            }
            Button { if let a = selectedApp { run { await ascService.reviewDoctor(appId: a.id) } } } label: {
                Label(loc(.smReviewDoctor), systemImage: "stethoscope")
            }
        }
    }

    private func detailsPane(_ run: @escaping (@escaping () async -> CommandResult) -> Void, _ isRunning: Bool) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    TextField(loc(.smVersionId), text: $versionId)
                        .textFieldStyle(.roundedBorder).font(.system(.body, design: .monospaced)).frame(maxWidth: 240)
                    Button { run { await ascService.reviewDetailsForVersion(versionId: versionId) } } label: {
                        Label(loc(.smDetailsForVersion), systemImage: "doc.text")
                    }.disabled(isRunning || versionId.isEmpty)
                }
                Divider()
                HStack(spacing: 10) {
                    TextField(loc(.smDetailId), text: $detailId)
                        .textFieldStyle(.roundedBorder).font(.system(.body, design: .monospaced)).frame(maxWidth: 240)
                    Button { run { await ascService.reviewAttachments(detailId: detailId) } } label: {
                        Label(loc(.smAttachments), systemImage: "paperclip")
                    }.disabled(isRunning || detailId.isEmpty)
                    if isRunning { ProgressView().controlSize(.small) }
                    Spacer()
                }
            }.padding(6)
        }
    }

    private func submissionsPane(_ run: @escaping (@escaping () async -> CommandResult) -> Void, _ isRunning: Bool) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                FlowButtons {
                    Button { if let a = selectedApp { run { await ascService.reviewSubmissionsList(appId: a.id) } } } label: {
                        Label(loc(.smSubmissionsList), systemImage: "list.bullet")
                    }
                    TextField(loc(.smPlatform), text: $platform)
                        .textFieldStyle(.roundedBorder).frame(maxWidth: 110)
                    Button { if let a = selectedApp { run { await ascService.reviewSubmissionsCreate(appId: a.id, platform: platform) } } } label: {
                        Label(loc(.smSubmissionsCreate), systemImage: "plus")
                    }.disabled(isRunning || platform.isEmpty)
                }
                Divider()
                FlowButtons {
                    TextField(loc(.smSubmissionId), text: $submissionId)
                        .textFieldStyle(.roundedBorder).font(.system(.body, design: .monospaced)).frame(maxWidth: 240)
                    Button { run { await ascService.reviewSubmissionsSubmit(submissionId: submissionId) } } label: {
                        Label(loc(.smSubmit), systemImage: "paperplane.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRunning || submissionId.isEmpty)
                    Button(role: .destructive) { run { await ascService.reviewSubmissionsCancel(submissionId: submissionId) } } label: {
                        Label(loc(.smSubmitCancel), systemImage: "xmark.circle")
                    }.disabled(isRunning || submissionId.isEmpty)
                    if isRunning { ProgressView().controlSize(.small) }
                }
            }.padding(6)
        }
    }

    private func notesPane(_ run: @escaping (@escaping () async -> CommandResult) -> Void, _ isRunning: Bool) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    TextField(loc(.smBuildId), text: $buildId)
                        .textFieldStyle(.roundedBorder).font(.system(.body, design: .monospaced)).frame(maxWidth: 240)
                    Button { run { await ascService.buildLocalizationsList(buildId: buildId) } } label: {
                        Label(loc(.smBuildNotes), systemImage: "text.bubble")
                    }.disabled(isRunning || buildId.isEmpty)
                }
                Divider()
                HStack(spacing: 10) {
                    TextField(loc(.smSinceTag), text: $sinceTag)
                        .textFieldStyle(.roundedBorder).frame(maxWidth: 160)
                    Button { run { await ascService.releaseNotesGenerate(sinceTag: sinceTag) } } label: {
                        Label(loc(.smGenerateNotes), systemImage: "wand.and.stars")
                    }.disabled(isRunning || sinceTag.isEmpty)
                    if isRunning { ProgressView().controlSize(.small) }
                    Spacer()
                }
            }.padding(6)
        }
    }
}

// MARK: - Compliance

struct ComplianceView: View {
    @EnvironmentObject var ascService: ASCService
    @EnvironmentObject var loc: LocalizationManager
    let selectedApp: ASCApp?

    @State private var tab = 0
    @State private var primary = ""
    @State private var secondary = ""

    var body: some View {
        CommandScreen(title: loc(.secCompliance), subtitle: selectedApp?.name, intro: loc(.cmBody),
                      requireApp: true, hasApp: selectedApp != nil) { run, isRunning in
            Picker("", selection: $tab) {
                Text(loc(.cmAgeRating)).tag(0)
                Text(loc(.cmEncryption)).tag(1)
                Text(loc(.cmCategories)).tag(2)
                Text(loc(.cmEula)).tag(3)
                Text(loc(.cmAppTags)).tag(4)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch tab {
            case 1:
                actionBox(isRunning) {
                    Button { if let a = selectedApp { run { await ascService.encryptionDeclarations(appId: a.id) } } } label: {
                        Label(loc(.actList), systemImage: "lock.doc")
                    }
                }
            case 2:
                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Button { run { await ascService.categoriesList() } } label: {
                                Label(loc(.actList), systemImage: "square.grid.2x2")
                            }
                            if isRunning { ProgressView().controlSize(.small) }
                            Spacer()
                        }
                        Divider()
                        FlowButtons {
                            TextField(loc(.cmPrimary), text: $primary)
                                .textFieldStyle(.roundedBorder).frame(maxWidth: 180)
                            TextField(loc(.cmSecondary), text: $secondary)
                                .textFieldStyle(.roundedBorder).frame(maxWidth: 180)
                            Button {
                                if let a = selectedApp { run { await ascService.categoriesSet(appId: a.id, primary: primary, secondary: secondary) } }
                            } label: { Label(loc(.cmCatSet), systemImage: "checkmark") }
                            .buttonStyle(.borderedProminent)
                            .disabled(isRunning || primary.isEmpty)
                        }
                    }.padding(6)
                }
            case 3:
                actionBox(isRunning) {
                    Button { if let a = selectedApp { run { await ascService.eulaView(appId: a.id) } } } label: {
                        Label(loc(.actView), systemImage: "doc.plaintext")
                    }
                }
            case 4:
                actionBox(isRunning) {
                    Button { if let a = selectedApp { run { await ascService.appTagsList(appId: a.id) } } } label: {
                        Label(loc(.actList), systemImage: "tag")
                    }
                }
            default:
                actionBox(isRunning) {
                    Button { if let a = selectedApp { run { await ascService.ageRatingView(appId: a.id) } } } label: {
                        Label(loc(.actView), systemImage: "person.crop.square")
                    }
                }
            }
        }
    }
}
