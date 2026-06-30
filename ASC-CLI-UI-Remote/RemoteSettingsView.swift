import SwiftUI
import ASCShared

/// Settings & information for the read-only companion: language, mirror status, app/version
/// info (including the compatible Mac app build), source link, license, and legal notice.
struct RemoteSettingsView: View {
    @EnvironmentObject private var loc: LocalizationManager
    @EnvironmentObject private var reader: CloudKitMirrorReader
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                generalSection
                dataSection
                aboutSection
                impressumSection
            }
            .navigationTitle(loc(.settingsTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(loc(.done)) { dismiss() }
                }
            }
        }
    }

    private var generalSection: some View {
        Section(loc(.secGeneral)) {
            Picker(loc(.language), selection: $loc.language) {
                ForEach(AppLanguage.allCases) { lang in
                    Text(loc.displayName(for: lang)).tag(lang)
                }
            }
        }
    }

    private var dataSection: some View {
        Section(loc(.rmDataSection)) {
            LabeledContent(loc(.rmAppsTitle), value: loc(.rmMirroredCountFmt, reader.groups.count))
            LabeledContent(loc(.rmLastSync),
                           value: reader.lastRefreshed.map(Self.dateString) ?? loc(.rmNever))
            Button {
                Task { await reader.refresh() }
            } label: {
                Label(loc(.refresh), systemImage: "arrow.clockwise")
            }
            .disabled(reader.isRefreshing)
        }
    }

    private var aboutSection: some View {
        Section {
            LabeledContent(loc(.aboutVersion),
                           value: "\(ASCAppInfo.bundleVersion) (\(ASCAppInfo.bundleBuild))")
            LabeledContent(loc(.rmCompatMacApp),
                           value: "\(ASCAppInfo.compatibleMacAppVersion) (\(ASCAppInfo.compatibleMacAppBuild))")
            LabeledContent(loc(.aboutLicense), value: ASCAppInfo.license)
            Link(destination: ASCAppInfo.repositoryURL) {
                Label(loc(.rmSourceCode), systemImage: "chevron.left.forwardslash.chevron.right")
            }
        } header: {
            Text(loc(.secAbout))
        } footer: {
            Text(loc(.rmAppInfoNote))
        }
    }

    private var impressumSection: some View {
        Section(loc(.rmImpressum)) {
            LabeledContent(loc(.aboutCreator), value: ASCAppInfo.creator)
            Text(loc(.rmImpressumBody))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private static func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    RemoteSettingsView()
        .environmentObject(LocalizationManager())
        .environmentObject(CloudKitMirrorReader())
}
