import SwiftUI
import ASCShared
import AppKit

/// One page that runs the whole ASO pipeline: current metadata via `asc`,
/// keyword research via the Appfigures API, optional review mining, and a
/// deterministic proposal (optimized keyword field + title/subtitle ideas)
/// that can be applied back through `asc localizations update`.
struct ASOAgentView: View {
    @EnvironmentObject var ascService: ASCService
    @EnvironmentObject var loc: LocalizationManager
    let selectedApp: ASCApp?

    private static let keychainAccount = "appfigures-pat"

    // Inputs
    @State private var apiKey = ""
    @AppStorage("aso.country") private var country = Locale.current.region?.identifier ?? "US"
    @AppStorage("aso.useTracked") private var useTracked = true
    @AppStorage("aso.mineReviews") private var mineReviews = true
    @AppStorage("aso.useCompetitors") private var useCompetitors = true
    @State private var productIdOverride = ""
    @State private var seeds = ""
    @State private var subtitleText = ""
    @State private var competitorTerm = ""

    // Version / locale
    @State private var selectedVersionId: String?
    @State private var selectedLocale: String?

    // Run state
    @State private var steps: [AgentStep] = []
    @State private var runTask: Task<Void, Never>?
    @State private var proposal: ASOProposal?
    @State private var proposalInput: ASOInput?
    @State private var scorecard: ASOScorecard?
    @State private var copiedField: String?

    // Apply / export
    @State private var showApplyConfirm = false
    @State private var applyResult: String?
    @State private var isApplying = false
    @State private var reportMessage: String?

    // Tracking agent (plan → paste into Appfigures → verify via API)
    @State private var trackingPlan: KeywordTrackingPlan?
    @State private var trackingSelection: Set<String> = []
    @State private var resolvedProductId: Int64?
    @State private var isVerifying = false
    @State private var verifySummary: String?
    @State private var verifiedTerms: Set<String> = []
    @State private var missingTerms: Set<String> = []

    private var isRunning: Bool { runTask != nil }

    var body: some View {
        VStack(spacing: 0) {
            SectionHeader(title: loc(.asoTitle), subtitle: selectedApp?.name) {
                EmptyView()
            }
            Divider()
            if let app = selectedApp {
                content(app: app)
            } else {
                ContentUnavailableView(loc(.noAppSelectedTitle), systemImage: "wand.and.stars",
                                       description: Text(loc(.pickAppToolbar)))
            }
        }
        .task(id: selectedApp?.id) { await reload() }
        .onAppear { apiKey = KeychainStore.load(account: Self.keychainAccount) ?? "" }
        .onDisappear { runTask?.cancel() }
        .alert(loc(.asoApplyConfirmTitle), isPresented: $showApplyConfirm) {
            Button(loc(.cancel), role: .cancel) {}
            Button(loc(.asoApply)) { applyKeywords() }
        } message: {
            Text(loc(.asoApplyConfirmMsg))
        }
    }

    private func content(app: ASCApp) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(loc(.asoBody)).font(.callout).foregroundStyle(.secondary)
                configCard
                runCard(app: app)
                if let proposal {
                    resultsCard(proposal)
                }
                trackingCard
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Inputs

    private var configCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 16) {
                    versionPicker
                    localePicker
                    Spacer()
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(loc(.asoApiKey)).font(.caption).foregroundStyle(.secondary)
                    SecureField("", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 420)
                        .onSubmit { persistKey() }
                    HStack(spacing: 8) {
                        Text(loc(.asoApiKeyHint)).font(.caption2).foregroundStyle(.tertiary)
                        Link(loc(.asoGetKey),
                             destination: URL(string: "https://appfigures.com/developers")!)
                            .font(.caption2)
                    }
                }
                HStack(alignment: .top, spacing: 16) {
                    labeled(loc(.asoCountry), hint: loc(.asoCountryHint)) {
                        TextField("", text: $country)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 70)
                    }
                    labeled(loc(.asoProductId), hint: loc(.asoProductIdHint)) {
                        TextField("", text: $productIdOverride)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 160)
                    }
                }
                labeled(loc(.asoSeeds), hint: loc(.asoSeedsHint)) {
                    TextField("", text: $seeds)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 420)
                }
                labeled(loc(.asoSubtitleField), hint: loc(.asoSubtitleFieldHint)) {
                    TextField("", text: $subtitleText)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 420)
                }
                labeled(loc(.asoCompetitorTermField), hint: loc(.asoCompetitorTermHint)) {
                    TextField("", text: $competitorTerm)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 420)
                }
                HStack(spacing: 16) {
                    Toggle(loc(.asoUseTracked), isOn: $useTracked).toggleStyle(.checkbox)
                    Toggle(loc(.asoMineReviews), isOn: $mineReviews).toggleStyle(.checkbox)
                    Toggle(loc(.asoUseCompetitors), isOn: $useCompetitors).toggleStyle(.checkbox)
                }
            }
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label(loc(.asoConfigTitle), systemImage: "slider.horizontal.3")
        }
    }

    private var versionPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(loc(.mdSelectVersion)).font(.caption).foregroundStyle(.secondary)
            Picker("", selection: $selectedVersionId) {
                ForEach(ascService.versions) { v in
                    Text("\(v.versionString) · \(v.state)").tag(String?.some(v.id))
                }
            }
            .labelsHidden()
            .frame(minWidth: 200)
            .onChange(of: selectedVersionId) { _, newValue in
                if let vid = newValue { Task { await loadLocales(vid) } }
            }
        }
    }

    @ViewBuilder
    private var localePicker: some View {
        if !ascService.versionLocalizations.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(loc(.mdLocale)).font(.caption).foregroundStyle(.secondary)
                Picker("", selection: $selectedLocale) {
                    ForEach(ascService.versionLocalizations) { l in
                        Text(l.locale).tag(String?.some(l.locale))
                    }
                }
                .labelsHidden()
                .frame(minWidth: 120)
            }
        }
    }

    private func labeled<Content: View>(_ label: String, hint: String,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            content()
            Text(hint).font(.caption2).foregroundStyle(.tertiary)
        }
    }

    // MARK: - Run card

    private func runCard(app: ASCApp) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    if isRunning {
                        Button(role: .cancel) {
                            runTask?.cancel()
                        } label: {
                            Label(loc(.asoCancelRun), systemImage: "stop.circle")
                        }
                    } else {
                        Button {
                            startRun(app: app)
                        } label: {
                            Label(loc(.asoStart), systemImage: "wand.and.stars")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canRun)
                    }
                    if !canRun {
                        Text(loc(.asoNeedKeyOrSeeds)).font(.caption).foregroundStyle(.orange)
                    }
                    Spacer()
                }
                if !steps.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(steps) { step in stepRow(step) }
                    }
                }
            }
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label(loc(.asoStart), systemImage: "play.circle")
        }
    }

    /// Without either research data or the user's own ideas there is nothing to optimize from.
    private var canRun: Bool {
        let hasKey = !apiKey.trimmingCharacters(in: .whitespaces).isEmpty && useTracked
        let hasSeeds = !seeds.trimmingCharacters(in: .whitespaces).isEmpty
        return hasKey || hasSeeds || mineReviews || useCompetitors
    }

    private func stepRow(_ step: AgentStep) -> some View {
        HStack(spacing: 8) {
            switch step.status {
            case .pending:
                Image(systemName: "circle").foregroundStyle(.tertiary)
            case .running:
                ProgressView().controlSize(.small)
            case .done:
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            case .skipped:
                Image(systemName: "minus.circle").foregroundStyle(.secondary)
            case .failed:
                Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
            }
            Text(loc(step.key)).font(.callout)
            switch step.status {
            case .done(let detail) where detail != nil:
                Text(detail!).font(.caption).foregroundStyle(.secondary)
            case .skipped:
                Text(loc(.asoSkipped)).font(.caption).foregroundStyle(.tertiary)
            case .failed(let message):
                Text(message).font(.caption).foregroundStyle(.red)
                    .lineLimit(2)
            default:
                EmptyView()
            }
            Spacer()
        }
    }

    // MARK: - Results

    private func resultsCard(_ proposal: ASOProposal) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                if let scorecard {
                    scorecardView(scorecard)
                }
                keywordFieldResult(proposal)

                if !proposal.titleSuggestions.isEmpty {
                    suggestionList(title: loc(.asoTitleIdeas), items: proposal.titleSuggestions,
                                   limit: ASOAgentEngine.nameLimit)
                }
                if !proposal.subtitleSuggestions.isEmpty {
                    suggestionList(title: loc(.asoSubtitleIdeas), items: proposal.subtitleSuggestions,
                                   limit: ASOAgentEngine.subtitleLimit)
                }
                if !proposal.warnings.isEmpty {
                    warningsList(proposal.warnings)
                }
                candidateTable(proposal.candidates)

                HStack(spacing: 12) {
                    Button {
                        saveReport(proposal)
                    } label: {
                        Label(loc(.asoSaveReport), systemImage: "doc.badge.arrow.up")
                    }
                    if let reportMessage {
                        Text(reportMessage).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label(loc(.asoResults), systemImage: "sparkles")
        }
    }

    private func scorecardView(_ scorecard: ASOScorecard) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(loc(.asoScoreTitle)).font(.headline)
                Spacer()
                Text("\(scorecard.total)/\(scorecard.maxTotal)")
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(scoreColor(scorecard.total, of: scorecard.maxTotal))
            }
            HStack(spacing: 12) {
                ForEach(scorecard.items) { item in
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(item.points)/\(item.maxPoints)")
                            .font(.callout.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(scoreColor(item.points, of: item.maxPoints))
                        Text(scoreLabel(item.kind))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    private func scoreLabel(_ kind: ASOScorecard.Item.Kind) -> String {
        switch kind {
        case .keywordBudget: return loc(.asoScoreKeywordBudget)
        case .cleanliness:   return loc(.asoScoreClean)
        case .titleUsage:    return loc(.asoScoreTitleUse)
        case .subtitleUsage: return loc(.asoScoreSubtitleUse)
        }
    }

    private func scoreColor(_ points: Int, of max: Int) -> Color {
        guard max > 0 else { return .secondary }
        let ratio = Double(points) / Double(max)
        if ratio >= 0.75 { return .green }
        if ratio >= 0.4 { return .orange }
        return .red
    }

    private func keywordFieldResult(_ proposal: ASOProposal) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(loc(.asoProposedKeywords)).font(.headline)
                Spacer()
                Text(loc(.asoCharsFmt, proposal.keywordField.count,
                         proposalInput?.keywordLimit ?? 100))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Text(proposal.keywordField.isEmpty ? "—" : proposal.keywordField)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            HStack(spacing: 12) {
                Button {
                    copy(proposal.keywordField, id: "keywords")
                } label: {
                    Label(copiedField == "keywords" ? loc(.asoCopied) : loc(.asoCopy),
                          systemImage: "doc.on.doc")
                }
                Button {
                    showApplyConfirm = true
                } label: {
                    if isApplying {
                        HStack(spacing: 6) { ProgressView().controlSize(.small); Text(loc(.asoApply)) }
                    } else {
                        Label(loc(.asoApply), systemImage: "arrow.up.doc")
                    }
                }
                .disabled(isApplying || proposal.keywordField.isEmpty
                          || selectedVersionId == nil || selectedLocale == nil)
                if let applyResult {
                    Text(applyResult).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }

    private func suggestionList(title: String, items: [String], limit: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            ForEach(items, id: \.self) { item in
                HStack(spacing: 8) {
                    Text(item).textSelection(.enabled)
                    Text("\(item.count)/\(limit)")
                        .font(.caption2).monospacedDigit().foregroundStyle(.tertiary)
                    Button {
                        copy(item, id: item)
                    } label: {
                        Image(systemName: copiedField == item ? "checkmark" : "doc.on.doc")
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    Spacer()
                }
            }
        }
    }

    private func warningsList(_ warnings: [ASOWarning]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(loc(.asoWarningsTitle)).font(.headline)
            ForEach(Array(warnings.enumerated()), id: \.offset) { _, warning in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                    Text(describe(warning)).font(.callout)
                    Spacer()
                }
            }
        }
    }

    private func describe(_ warning: ASOWarning) -> String {
        switch warning {
        case .spacesAfterCommas(let count):
            return loc(.asoWarnSpacesFmt, count)
        case .duplicateWords(let words):
            return loc(.asoWarnDupsFmt, words.joined(separator: ", "))
        case .titleDuplicates(let words):
            return loc(.asoWarnTitleDupsFmt, words.joined(separator: ", "))
        case .overLimit(let current, let max):
            return loc(.asoWarnOverLimitFmt, current, max)
        case .reservedWords(let words):
            return loc(.asoWarnReservedFmt, words.joined(separator: ", "))
        case .unusedBudget(let remaining):
            return loc(.asoWarnBudgetFmt, remaining)
        }
    }

    private func candidateTable(_ candidates: [ASOCandidate]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(loc(.asoCandidates)).font(.headline)
            if candidates.isEmpty {
                Text(loc(.asoNoCandidates)).font(.callout).foregroundStyle(.secondary)
            } else {
                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 5) {
                    GridRow {
                        Text(loc(.asoColTerm))
                        Text(loc(.asoColScore))
                        Text(loc(.asoColPop))
                        Text(loc(.asoColComp))
                        Text(loc(.asoColRank))
                        Text(loc(.asoColSources))
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    Divider()
                    ForEach(candidates.prefix(40)) { candidate in
                        GridRow {
                            HStack(spacing: 6) {
                                Text(candidate.term)
                                if candidate.coveredByTitle {
                                    Text(loc(.asoCoveredBadge))
                                        .font(.caption2)
                                        .padding(.horizontal, 5).padding(.vertical, 1)
                                        .background(Color.orange.opacity(0.15), in: Capsule())
                                        .foregroundStyle(.orange)
                                }
                            }
                            Text(number(candidate.score)).monospacedDigit()
                            Text(candidate.popularity.map(number) ?? "—").monospacedDigit()
                            Text(candidate.competitiveness.map(number) ?? "—").monospacedDigit()
                            Text(candidate.position.map(String.init) ?? "—").monospacedDigit()
                            Text(sourceLabels(candidate.sources))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .font(.callout)
                    }
                }
            }
        }
    }

    private func sourceLabels(_ sources: Set<ASOCandidate.Source>) -> String {
        sources.sorted { $0.rawValue < $1.rawValue }.map { source in
            switch source {
            case .tracked:    return loc(.asoSrcTracked)
            case .seed:       return loc(.asoSrcSeed)
            case .current:    return loc(.asoSrcCurrent)
            case .reviews:    return loc(.asoSrcReviews)
            case .competitor: return loc(.asoSrcCompetitor)
            }
        }
        .joined(separator: ", ")
    }

    private func number(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(value)
    }

    // MARK: - Tracking agent

    private var trackingCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Text(loc(.trkBody)).font(.callout).foregroundStyle(.secondary)
                if let plan = trackingPlan {
                    trackingContent(plan)
                } else {
                    Text(loc(.trkNeedRun)).font(.callout).foregroundStyle(.tertiary)
                }
            }
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label(loc(.trkTitle), systemImage: "plus.magnifyingglass")
        }
    }

    @ViewBuilder
    private func trackingContent(_ plan: KeywordTrackingPlan) -> some View {
        if plan.suggestions.isEmpty {
            Text(loc(.trkNoSuggestions)).font(.callout).foregroundStyle(.secondary)
        } else {
            HStack(spacing: 12) {
                Text(loc(.trkSuggestionsFmt, plan.suggestions.count))
                    .font(.caption.weight(.semibold))
                if !plan.alreadyTracked.isEmpty {
                    Text(loc(.trkAlreadyFmt, plan.alreadyTracked.count))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button(loc(.trkSelectAll)) { trackingSelection = Set(plan.suggestions) }
                    .buttonStyle(.link).font(.caption)
                Button(loc(.trkSelectNone)) { trackingSelection = [] }
                    .buttonStyle(.link).font(.caption)
            }
            VStack(alignment: .leading, spacing: 4) {
                ForEach(plan.suggestions, id: \.self) { term in
                    HStack(spacing: 8) {
                        Toggle(term, isOn: Binding(
                            get: { trackingSelection.contains(term) },
                            set: { on in
                                if on { trackingSelection.insert(term) } else { trackingSelection.remove(term) }
                            }
                        ))
                        .toggleStyle(.checkbox)
                        if verifiedTerms.contains(term) {
                            trackingBadge(loc(.trkTrackedBadge), color: .green)
                        } else if missingTerms.contains(term) {
                            trackingBadge(loc(.trkMissingBadge), color: .orange)
                        }
                        Spacer()
                    }
                }
            }
            HStack(spacing: 12) {
                Button {
                    copy(KeywordTrackingPlan.exportText(selectedTrackingTerms(plan)), id: "tracking")
                } label: {
                    Label(copiedField == "tracking" ? loc(.asoCopied) : loc(.trkCopyList),
                          systemImage: "doc.on.doc")
                }
                .disabled(trackingSelection.isEmpty)
                Button {
                    NSWorkspace.shared.open(URL(string: "https://analytics.appfigures.com/reports/keyword-performance")!)
                } label: {
                    Label(loc(.trkOpenAppfigures), systemImage: "arrow.up.forward.app")
                }
                Button {
                    verifyTracking(plan)
                } label: {
                    if isVerifying {
                        HStack(spacing: 6) { ProgressView().controlSize(.small); Text(loc(.trkVerifying)) }
                    } else {
                        Label(loc(.trkVerify), systemImage: "checkmark.seal")
                    }
                }
                .disabled(isVerifying || resolvedProductId == nil
                          || apiKey.trimmingCharacters(in: .whitespaces).isEmpty)
                if let verifySummary {
                    Text(verifySummary).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }

    private func trackingBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6).padding(.vertical, 1)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }

    /// Selected terms in plan order (a `Set` alone would scramble the ranking).
    private func selectedTrackingTerms(_ plan: KeywordTrackingPlan) -> [String] {
        plan.suggestions.filter { trackingSelection.contains($0) }
    }

    private func verifyTracking(_ plan: KeywordTrackingPlan) {
        guard let productId = resolvedProductId else { return }
        let client = AppfiguresClient(token: apiKey.trimmingCharacters(in: .whitespaces))
        isVerifying = true
        verifySummary = nil
        Task { @MainActor in
            do {
                let tracked = try await client.keywords(productId: productId, country: country)
                let result = KeywordTrackingPlan.verify(planned: selectedTrackingTerms(plan),
                                                        tracked: tracked)
                verifiedTerms = Set(result.tracked)
                missingTerms = Set(result.missing)
                verifySummary = loc(.trkVerifyResultFmt, result.tracked.count, result.missing.count)
            } catch {
                verifySummary = error.localizedDescription
            }
            isVerifying = false
        }
    }

    // MARK: - Pipeline

    private func startRun(app: ASCApp) {
        persistKey()
        proposal = nil
        applyResult = nil
        reportMessage = nil
        trackingPlan = nil
        trackingSelection = []
        resolvedProductId = nil
        verifySummary = nil
        verifiedTerms = []
        missingTerms = []
        let wantsAppfigures = useTracked && !apiKey.trimmingCharacters(in: .whitespaces).isEmpty
        scorecard = nil
        steps = [
            AgentStep(key: .asoStepMetadata),
            AgentStep(key: .asoStepProduct, status: wantsAppfigures ? .pending : .skipped),
            AgentStep(key: .asoStepKeywords, status: wantsAppfigures ? .pending : .skipped),
            AgentStep(key: .asoStepReviews, status: mineReviews ? .pending : .skipped),
            AgentStep(key: .asoStepCompetitors, status: useCompetitors ? .pending : .skipped),
            AgentStep(key: .asoStepCompose)
        ]
        runTask = Task {
            await run(app: app, wantsAppfigures: wantsAppfigures)
            runTask = nil
        }
    }

    @MainActor
    private func run(app: ASCApp, wantsAppfigures: Bool) async {
        // 1 — current metadata via asc
        setStep(.asoStepMetadata, .running)
        await ascService.ensureVersions(for: app.id)
        if selectedVersionId == nil { selectedVersionId = ascService.versions.first?.id }
        if let vid = selectedVersionId { await loadLocales(vid) }
        let localization = ascService.versionLocalizations.first { $0.locale == selectedLocale }
        setStep(.asoStepMetadata, .done(selectedLocale))
        if Task.isCancelled { return }

        // 2 + 3 — Appfigures research
        var tracked: [AppfiguresKeyword] = []
        if wantsAppfigures {
            let client = AppfiguresClient(token: apiKey.trimmingCharacters(in: .whitespaces))
            var productId = Int64(productIdOverride.trimmingCharacters(in: .whitespaces))
            setStep(.asoStepProduct, .running)
            if productId == nil {
                do {
                    let products = try await client.products()
                    productId = products.first { $0.refNo == app.id || $0.bundleId == app.bundleId }?.id
                    if productId == nil {
                        setStep(.asoStepProduct, .failed(loc(.asoProductNotFound)))
                    }
                } catch {
                    setStep(.asoStepProduct, .failed(error.localizedDescription))
                }
            }
            if Task.isCancelled { return }
            resolvedProductId = productId
            if let productId {
                setStep(.asoStepProduct, .done(loc(.asoProductResolvedFmt, String(productId))))
                setStep(.asoStepKeywords, .running)
                do {
                    tracked = try await client.keywords(productId: productId, country: country)
                    setStep(.asoStepKeywords, .done(loc(.asoKeywordCountFmt, tracked.count)))
                } catch {
                    setStep(.asoStepKeywords, .failed(error.localizedDescription))
                }
            } else {
                setStep(.asoStepKeywords, .skipped)
            }
        }
        if Task.isCancelled { return }

        // 4 — review mining via asc
        var reviewTexts: [String] = []
        if mineReviews {
            setStep(.asoStepReviews, .running)
            let result = await ascService.reviewsList(appId: app.id, stars: nil,
                                                      territory: "", onlyUnresponded: false)
            if result.succeeded {
                let reviews = CustomerReviewParser.parse(result.output)
                reviewTexts = reviews.flatMap { [$0.title, $0.body].compactMap { $0 } }
                setStep(.asoStepReviews, .done(loc(.asoReviewCountFmt, reviews.count)))
            } else {
                setStep(.asoStepReviews, .failed(result.errorMessage))
            }
        }
        if Task.isCancelled { return }

        let seedList = seeds.split(separator: ",").map { String($0) }
        let languageCode = (selectedLocale ?? loc.code).hasPrefix("de") ? "de" : "en"

        // 5 — competitor titles via iTunes search (no API key needed)
        var competitorTerms: [String: Int] = [:]
        if useCompetitors {
            setStep(.asoStepCompetitors, .running)
            let term = [competitorTerm, seedList.first ?? "", app.name]
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .first { !$0.isEmpty } ?? app.name
            do {
                let results = try await ITunesSearchClient.search(term: term, country: country, limit: 12)
                let mined = CompetitorMiner.mine(results,
                                                 excludingBundleId: app.bundleId,
                                                 language: languageCode)
                competitorTerms = Dictionary(uniqueKeysWithValues: mined.map { ($0.term, $0.appCount) })
                setStep(.asoStepCompetitors, .done(loc(.asoCompetitorCountFmt, mined.count, results.count)))
            } catch {
                setStep(.asoStepCompetitors, .failed(error.localizedDescription))
            }
        }
        if Task.isCancelled { return }

        // 6 — compose (pure)
        setStep(.asoStepCompose, .running)
        let input = ASOInput(
            appName: app.name,
            subtitle: subtitleText.isEmpty ? nil : subtitleText,
            currentKeywords: localization?.keywords,
            seedKeywords: seedList,
            tracked: tracked,
            reviewTexts: reviewTexts,
            competitorTerms: competitorTerms,
            languageCode: languageCode
        )
        proposalInput = input
        let result = ASOAgentEngine.propose(input)
        proposal = result
        scorecard = ASOScorecard.evaluate(input: input, warnings: result.warnings)
        let plan = KeywordTrackingPlan.build(input: input, candidates: result.candidates)
        trackingPlan = plan
        trackingSelection = Set(plan.suggestions)
        setStep(.asoStepCompose, .done(nil))
    }

    private func setStep(_ key: LocKey, _ status: AgentStep.Status) {
        if let index = steps.firstIndex(where: { $0.key == key }) {
            steps[index].status = status
        }
    }

    // MARK: - Actions

    private func applyKeywords() {
        guard let proposal, let vid = selectedVersionId, let locale = selectedLocale else { return }
        isApplying = true
        applyResult = nil
        Task {
            let result = await ascService.updateLocalization(
                versionId: vid, locale: locale,
                description: nil, keywords: proposal.keywordField,
                whatsNew: nil, promotionalText: nil, supportUrl: nil, marketingUrl: nil
            )
            isApplying = false
            applyResult = result.succeeded ? loc(.asoApplied) : result.errorMessage
        }
    }

    private func saveReport(_ proposal: ASOProposal) {
        guard let app = selectedApp, let input = proposalInput,
              let dir = FilePanel.pickDirectory() else { return }
        let markdown = ASOResearchReport.markdown(appName: app.name, country: country,
                                                  input: input, proposal: proposal)
        let url = URL(fileURLWithPath: dir).appendingPathComponent("ASO_RESEARCH.md")
        do {
            try markdown.write(to: url, atomically: true, encoding: .utf8)
            reportMessage = loc(.asoReportSavedFmt, url.path)
        } catch {
            reportMessage = error.localizedDescription
        }
    }

    private func copy(_ text: String, id: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        copiedField = id
        Task {
            try? await Task.sleep(for: .seconds(2))
            if copiedField == id { copiedField = nil }
        }
    }

    private func persistKey() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            KeychainStore.delete(account: Self.keychainAccount)
        } else {
            KeychainStore.save(trimmed, account: Self.keychainAccount)
        }
    }

    // MARK: - Data

    @MainActor
    private func reload() async {
        guard let app = selectedApp else { return }
        await ascService.ensureVersions(for: app.id)
        if selectedVersionId == nil || !(ascService.versions.contains { $0.id == selectedVersionId }) {
            selectedVersionId = ascService.versions.first?.id
        }
        if let vid = selectedVersionId { await loadLocales(vid) }
    }

    @MainActor
    private func loadLocales(_ versionId: String) async {
        await ascService.loadVersionLocalizations(versionId: versionId)
        let locales = ascService.versionLocalizations.map(\.locale)
        if selectedLocale == nil || !locales.contains(selectedLocale!) {
            // Prefer the locale matching the app's primary locale, else the first one.
            selectedLocale = locales.first { $0 == selectedApp?.primaryLocale } ?? locales.first
        }
    }
}

// MARK: - Step model

private struct AgentStep: Identifiable {
    enum Status {
        case pending, running, skipped
        case done(String?)
        case failed(String)
    }

    let key: LocKey
    var status: Status = .pending
    var id: String { key.rawValue }
}
