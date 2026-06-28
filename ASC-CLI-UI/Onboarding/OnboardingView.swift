import SwiftUI
import AppKit

struct OnboardingView: View {
    @EnvironmentObject var ascService: ASCService
    @EnvironmentObject var loc: LocalizationManager

    var onFinish: () -> Void

    @State private var step = 0
    @State private var showAddKey = false
    @State private var recheckToken = 0

    private let totalSteps = 4

    var body: some View {
        VStack(spacing: 0) {
            progressBar
            Divider()

            Group {
                switch step {
                case 0: welcomeStep
                case 1: installStep
                case 2: connectStep
                default: finishStep
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
            .id(step)

            Divider()
            footer
        }
        .frame(width: 620, height: 560)
        .sheet(isPresented: $showAddKey) {
            AddKeyView()
                .environmentObject(ascService)
                .environmentObject(loc)
        }
    }

    // MARK: - Chrome

    private var progressBar: some View {
        HStack(spacing: 10) {
            ForEach(0..<totalSteps, id: \.self) { i in
                Capsule()
                    .fill(i <= step ? Color.accentColor : Color.secondary.opacity(0.25))
                    .frame(height: 5)
                    .animation(.easeInOut, value: step)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 16)
        .overlay(alignment: .trailing) {
            Text(loc(.stepOfFmt, "\(step + 1)", "\(totalSteps)"))
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.trailing, 28)
                .offset(y: 16)
        }
    }

    private var footer: some View {
        HStack {
            if step > 0 {
                Button(loc(.back)) {
                    withAnimation { step -= 1 }
                }
            } else {
                Button(loc(.skip)) { onFinish() }
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(primaryTitle) {
                advance()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
        }
        .padding(20)
    }

    private var primaryTitle: String {
        switch step {
        case 0: return loc(.obGetStarted)
        case totalSteps - 1: return loc(.obFinish)
        default: return loc(.next)
        }
    }

    private func advance() {
        if step >= totalSteps - 1 {
            onFinish()
        } else {
            withAnimation { step += 1 }
            if step == 1 || step == 2 {
                Task { await ascService.refreshAuthStatus() }
            }
        }
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(LinearGradient(colors: [.accentColor, .accentColor.opacity(0.6)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 104, height: 104)
                    .shadow(color: .accentColor.opacity(0.35), radius: 16, y: 8)
                Image(systemName: "app.gift")
                    .font(.system(size: 50, weight: .medium))
                    .foregroundStyle(.white)
            }
            VStack(spacing: 10) {
                Text(loc(.obWelcomeTitle))
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)
                Text(loc(.obWelcomeSubtitle))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 440)
            }

            VStack(spacing: 8) {
                Text(loc(.obChooseLanguage))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("", selection: $loc.language) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(loc.displayName(for: lang)).tag(lang)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 320)
            }
            .padding(.top, 6)
            Spacer()
        }
        .padding(40)
    }

    private var installStep: some View {
        stepScaffold(icon: "terminal", title: loc(.obInstallTitle), body: loc(.obInstallBody)) {
            VStack(alignment: .leading, spacing: 16) {
                let installed = ascService.binaryExists
                statusRow(
                    ok: installed,
                    okText: loc(.obInstalled),
                    badText: loc(.obNotInstalled)
                )
                .id(recheckToken)

                VStack(alignment: .leading, spacing: 8) {
                    Text(loc(.obBrewHint))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    CommandBox(command: "brew install asc")
                }

                Button {
                    recheckToken += 1
                    Task { await ascService.refreshAuthStatus() }
                } label: {
                    Label(loc(.obRecheck), systemImage: "arrow.clockwise")
                }
            }
        }
    }

    private var connectStep: some View {
        stepScaffold(icon: "key.horizontal", title: loc(.obConnectTitle), body: loc(.obConnectBody)) {
            VStack(alignment: .leading, spacing: 14) {
                let creds = ascService.authStatus?.credentials ?? []
                if creds.isEmpty {
                    Label(loc(.obNoProfilesYet), systemImage: "info.circle")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    Text(loc(.obUseExisting))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    VStack(spacing: 0) {
                        ForEach(creds) { cred in
                            profilePickRow(cred)
                            if cred.id != creds.last?.id { Divider() }
                        }
                    }
                    .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                }

                Button {
                    showAddKey = true
                } label: {
                    Label(loc(.addApiKey), systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)

                if ascService.isConfigured {
                    Label("\(loc(.obConnectedAs)) · \(ascService.activeProfile ?? "")",
                          systemImage: "checkmark.seal.fill")
                        .font(.callout)
                        .foregroundStyle(.green)
                        .padding(.top, 2)
                }
            }
        }
    }

    private func profilePickRow(_ cred: ASCAuthCredential) -> some View {
        let isActive = ascService.activeProfile == cred.name
        return Button {
            ascService.selectProfile(cred.name)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isActive ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isActive ? Color.accentColor : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(cred.name).fontWeight(.medium)
                    Text(loc(.keyIdFmt, cred.keyId)).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var finishStep: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 104, height: 104)
                Image(systemName: "checkmark")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(.green)
            }
            Text(loc(.obFinishTitle))
                .font(.largeTitle.weight(.bold))
            Text(loc(.obFinishBody))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 440)
            Spacer()
        }
        .padding(40)
    }

    // MARK: - Building blocks

    @ViewBuilder
    private func stepScaffold(icon: String, title: String, body: String,
                              @ViewBuilder content: () -> some View) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 14) {
                    Image(systemName: icon)
                        .font(.system(size: 30))
                        .foregroundStyle(.tint)
                        .frame(width: 56, height: 56)
                        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title).font(.title.weight(.semibold))
                    }
                }
                Text(body)
                    .font(.body)
                    .foregroundStyle(.secondary)
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(36)
        }
    }

    private func statusRow(ok: Bool, okText: String, badText: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(ok ? .green : .orange)
                .font(.title3)
            Text(ok ? okText : badText)
                .fontWeight(.medium)
            Spacer()
        }
        .padding(12)
        .background((ok ? Color.green : Color.orange).opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Command box with copy

struct CommandBox: View {
    let command: String
    @State private var copied = false

    var body: some View {
        HStack {
            Text(command)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
            Spacer()
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(command, forType: .string)
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .foregroundStyle(copied ? .green : .secondary)
            }
            .buttonStyle(.plain)
            .help("Copy")
        }
        .padding(12)
        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }
}
