import SwiftUI
import AppKit

struct HelpView: View {
    @EnvironmentObject var loc: LocalizationManager
    @EnvironmentObject var ascService: ASCService

    @State private var isInstallingSkills = false
    @State private var skillsOutput: String?

    private let keysURL = URL(string: "https://appstoreconnect.apple.com/access/integrations/api")!
    private let ascHomeURL = URL(string: "https://appstoreconnect.apple.com")!
    private let docsURL = URL(string: "https://asccli.sh/")!
    private let setupAscURL = URL(string: "https://github.com/rudrankriyam/setup-asc")!

    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(title: loc(.helpTitle), subtitle: nil) { EmptyView() }
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    getKeyCard
                    newAppCard
                    installCard
                    skillsCard
                    faqCard
                    linksCard
                }
                .padding(20)
                .frame(maxWidth: 720, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var getKeyCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                Text(loc(.helpGetKeyIntro))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 12) {
                    numberedStep(1, loc(.helpStep1))
                    numberedStep(2, loc(.helpStep2))
                    numberedStep(3, loc(.helpStep3))
                    numberedStep(4, loc(.helpStep4))
                    numberedStep(5, loc(.helpStep5), highlight: true)
                }

                Button {
                    NSWorkspace.shared.open(keysURL)
                } label: {
                    Label(loc(.helpOpenKeysPage), systemImage: "arrow.up.right.square")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label(loc(.helpGetKeyTitle), systemImage: "key.horizontal")
        }
    }

    private var newAppCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                Text(loc(.newAppIntro)).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 12) {
                    numberedStep(1, loc(.newAppStep1))
                    numberedStep(2, loc(.newAppStep2))
                    numberedStep(3, loc(.newAppStep3))
                }
                Text(loc(.newAppApiNote)).font(.caption).foregroundStyle(.tertiary)
                HStack {
                    Button {
                        NSWorkspace.shared.open(AppInfo.developerIdentifiers)
                    } label: {
                        Label(loc(.newAppOpenBundleIds), systemImage: "number.square")
                    }
                    Button {
                        NSWorkspace.shared.open(AppInfo.appStoreConnectApps)
                    } label: {
                        Label(loc(.newAppOpenASC), systemImage: "arrow.up.right.square")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label(loc(.newAppTitle), systemImage: "plus.app")
        }
    }

    private var installCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Text(loc(.helpInstallBody)).foregroundStyle(.secondary)
                CommandBox(command: "brew install asc")
            }
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label(loc(.helpInstallTitle), systemImage: "terminal")
        }
    }

    private var skillsCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                Text(loc(.helpSkillsBody)).foregroundStyle(.secondary)
                HStack {
                    Button {
                        installSkills()
                    } label: {
                        if isInstallingSkills {
                            HStack(spacing: 6) { ProgressView().controlSize(.small); Text(loc(.helpInstalling)) }
                        } else {
                            Label(loc(.helpInstallSkills), systemImage: "wand.and.stars")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isInstallingSkills)
                    Spacer()
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(loc(.helpSkillsNpx)).font(.caption).foregroundStyle(.secondary)
                    CommandBox(command: "npx skills add rorkai/app-store-connect-cli-skills")
                }
                if let skillsOutput { OutputPanel(title: loc(.output), text: skillsOutput, maxHeight: 200) }

                Divider()

                Text(loc(.helpCITitle)).fontWeight(.semibold)
                Text(loc(.helpCIBody)).font(.callout).foregroundStyle(.secondary)
                Button {
                    NSWorkspace.shared.open(setupAscURL)
                } label: {
                    Label(loc(.helpOpenSetupAsc), systemImage: "arrow.up.right.square")
                }
            }
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label(loc(.helpSkillsTitle), systemImage: "wand.and.stars")
        }
    }

    private func installSkills() {
        isInstallingSkills = true
        skillsOutput = nil
        Task {
            let result = await ascService.installSkills()
            skillsOutput = result.succeeded ? (result.output.isEmpty ? "✓" : result.output) : result.errorMessage
            isInstallingSkills = false
        }
    }

    private var faqCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                faqItem(loc(.faqQ1), loc(.faqA1))
                Divider()
                faqItem(loc(.faqQ2), loc(.faqA2))
                Divider()
                faqItem(loc(.faqQ3), loc(.faqA3))
                Divider()
                faqItem(loc(.faqQ4), loc(.faqA4))
                Divider()
                faqItem(loc(.faqQ5), loc(.faqA5))
            }
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label(loc(.helpFaqTitle), systemImage: "questionmark.circle")
        }
    }

    private var linksCard: some View {
        GroupBox {
            HStack(spacing: 12) {
                Button {
                    NSWorkspace.shared.open(ascHomeURL)
                } label: {
                    Label(loc(.helpOpenASCHome), systemImage: "safari")
                }
                Button {
                    NSWorkspace.shared.open(docsURL)
                } label: {
                    Label(loc(.helpOpenAscDocs), systemImage: "book")
                }
                Spacer()
            }
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label(loc(.helpLinksTitle), systemImage: "link")
        }
    }

    // MARK: - Building blocks

    private func numberedStep(_ n: Int, _ text: String, highlight: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(n)")
                .font(.callout.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(highlight ? Color.orange : Color.accentColor, in: Circle())
            Text(text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(highlight ? .primary : .primary)
        }
    }

    private func faqItem(_ q: String, _ a: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(q).fontWeight(.semibold)
            Text(a).font(.callout).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
