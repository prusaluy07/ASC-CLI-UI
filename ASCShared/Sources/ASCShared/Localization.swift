import SwiftUI
import Combine

// MARK: - Language

public enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english = "en"
    case german = "de"

    public var id: String { rawValue }

    /// Each language shown in its own name (plus a localized "System" entry handled by the manager).
    public var nativeName: String {
        switch self {
        case .system:  return "System"
        case .english: return "English"
        case .german:  return "Deutsch"
        }
    }
}

// MARK: - Keys

public enum LocKey: String {
    // Common
    case appName, refresh, done, cancel, save, browse, back, next, skip, close, ok, load
    case connected, notConfigured

    // Sidebar / sections
    case secOverview, secApps, secVersions, secBuilds, secTestFlight, secSigning, secTerminal
    case selectSection
    case activeAppHelp

    // Not configured
    case notConfiguredTitle, notConfiguredDesc, openSettings

    // Overview
    case overviewTitle, statApps, statCertificates, statProfiles
    case currentApp, noAppSelectedShort, loadAppsPrompt, loadApps
    case ovSwitchApp, ovSwitchAppHelp

    // Apps
    case appsTitle, searchApps, noAppsLoaded

    // Versions
    case versionsTitle, colVersion, colPlatform, colState, colRelease, colCreated
    case noVersions, noVersionsDesc, pickAppToolbar, noAppSelectedTitle

    // Builds
    case buildsTitle, colBuild, colStatus, colMinOS, colUploaded, colExpires
    case selectAppInApps, noBuilds

    // TestFlight
    case testflightTitle, quickActions, betaGroups, betaGroupsDesc
    case testers, testersDesc, feedback, feedbackDesc, output, selectAppFromApps

    // Signing
    case signingTitle, certificates, profiles, noCertificates, noProfiles
    case certExp

    // Terminal
    case terminalTitle, clear, terminalHint, terminalPlaceholder

    // Settings
    case settingsTitle, secGeneral, secLanguage, language, languageHelp
    case authProfiles, noKeysFound, noKeysDesc, addApiKey, storedInFmt, defaultTag
    case profileRolesSection, profileRolesDesc
    case profileCapGeneral, profileCapAnalytics, profileCapFinance, profileCapAdmin
    case profileCapGeneralHelp, profileCapAnalyticsHelp, profileCapFinanceHelp, profileCapAdminHelp
    case profileCapUseDefault, profileCapActiveFmt
    case keyIdFmt, ascBinary, binaryFound, binaryNotFound, installHintFmt
    case ascTimeout, ascTimeoutDesc, ascTimeoutValueFmt
    case connection, testConnection, testing, connectionSuccessFmt
    case onboardingSection, replayOnboarding, replayOnboardingDesc, showOnboarding

    // Add key
    case addKeyTitle, profileName, profileNameHint, keyId, keyIdHint
    case issuerId, issuerIdHint, privateKey, privateKeyHint, saveKey, saving

    // Onboarding
    case obWelcomeTitle, obWelcomeSubtitle, obChooseLanguage, obGetStarted
    case obInstallTitle, obInstallBody, obInstalled, obNotInstalled, obBrewHint, obRecheck
    case obConnectTitle, obConnectBody, obUseExisting, obNoProfilesYet, obConnectedAs
    case obFinishTitle, obFinishBody, obFinish, stepOfFmt

    // New sidebar sections
    case secMetadata, secRelease, secReports, secHelp

    // Help / manual
    case helpTitle, helpGetKeyTitle, helpGetKeyIntro
    case helpStep1, helpStep2, helpStep3, helpStep4, helpStep5
    case helpOpenKeysPage, helpInstallTitle, helpInstallBody
    case helpFaqTitle, faqQ1, faqA1, faqQ2, faqA2, faqQ3, faqA3, faqQ4, faqA4, faqQ5, faqA5
    case helpLinksTitle, helpOpenASCHome, helpOpenAscDocs

    // Release
    case releaseTitle, relHealth, relNextAction, relBlockers, relLatestBuild
    case relAppStoreState, relReviewState, relTestflightState, relPhased, relConfigured
    case relOpenASC, relValidate, relValidating, relReleaseNow, relReleasing
    case relReleaseConfirmTitle, relReleaseConfirmMsg, relNoStatus, relResultTitle
    case relYes, relNo

    // Metadata
    case metadataTitle, mdSelectVersion, mdLocale, mdDescription, mdKeywords, mdWhatsNew
    case mdPromotional, mdSupportUrl, mdMarketingUrl, mdSave, mdSaving
    case mdSaveConfirmTitle, mdSaveConfirmMsg, mdSaved, mdNoLocalizations, mdPickAppVersion

    // TestFlight tables
    case tfGroups, tfTesters, tfInternal, tfExternal, tfColName, tfColEmail
    case tfColState, tfColType, tfColCreated, tfColAccess, tfColFeedback
    case tfNotify, tfNotifyConfirmTitle, tfNotifyConfirmMsg, tfNoGroups, tfNoTesters
    case tfYes, tfNo, tfNoLatestBuild

    // Reports
    case reportsTitle, rpVendor, rpVendorHint, rpNeedVendor, rpAnalytics, rpFinance
    case rpRequests, rpCreateRequest, rpSalesReport, rpFrequency, rpDaily, rpWeekly, rpMonthly
    case rpDate, rpDownload, rpRegion, rpFinanceRegions, rpFinanceReport, rpResult, rpSaveVendor
    case rpFolder, rpChooseFolder, rpDecompress, rpReveal, rpSavedToFmt, rpScanImport, rpImportedFmt

    // Sidebar groups + new sections
    case grpApp, grpBuild, grpRelease, grpDeveloper
    case secMedia, secXcodeCloud, secDiscover, secBundleIds, secNotarization

    // Build upload
    case buUpload, buUploadTitle, buFile, buVersion, buBuildNumber, buAutoExtract
    case buDryRun, buDryRunHint, buUploading, buDryRunAction

    // Publish
    case pubTitle, pubBody, pubIpa, pubVersion, pubMetadataDir, pubOptional
    case pubSubmitForReview, pubRunning, pubUploadOnly, pubSubmit, pubConfirmTitle, pubConfirmMsg

    // Metadata files
    case mdFilesTitle, mdFilesBody, mdPull, mdValidate, mdApply

    // Global online/offline data mode
    case modeOnline, modeOffline, modeTitle, modeOnlineDesc, modeOfflineDesc, modeHeaderHint

    // Metadata validation result
    case mdValValid, mdValInvalid, mdValFilesScanned, mdValErrors, mdValWarnings, mdValIssues, mdValNoIssues

    // Metadata source mode (online / local folder)
    case mdSource, mdSourceOnline, mdSourceLocal
    case mdLocalTitle, mdLocalBody, mdLocalNoFolder, mdLocalNoFiles, mdLocalFiles
    case mdLocalSave, mdLocalSaved, mdLocalReload, mdLocalReadErr

    // Metadata agent brief
    case mdAgentTitle, mdAgentBody, mdAgentGoal, mdAgentGoalHint, mdAgentAudience
    case mdAgentTone, mdAgentPrinciples, mdAgentLocales, mdAgentInclCurrent
    case mdAgentGenerate, mdAgentGenerated, mdAgentNeedsFolder, mdAgentShowFinder

    // Media
    case mediaTitle, mediaScreenshots, mediaPreviews, mediaDevice
    case mediaList, mediaSizes, mediaUpload, mediaDownload

    // Discover
    case discoverTitle, discoverBody, discSearch, discSchema, discCapabilities
    case discSearchPlaceholder, discSchemaPlaceholder, discLookup, discLoadCapabilities

    // Xcode Cloud
    case xcTitle, xcBody, xcWorkflows, xcWorkflowName, xcBranch, xcWait, xcRun
    case xcTrigger, xcRunId, xcCheckStatus, xcBuildRunStatus

    // Signing tabs / bundle IDs / notarization
    case signCertsProfiles, biEmpty, biLoadHint, biName, biIdentifier
    case notarizeBody, notarizeFile, notarizeList, notarizeSubmit, notarizeSubmitting

    // Metadata compare
    case mdEdit, mdCompare, mdLangA, mdLangB, mdMissingTranslation

    // Settings about
    case secAbout, aboutVersion, aboutCreator, aboutLicense

    // New app
    case appsNewApp, newAppTitle, newAppIntro, newAppStep1, newAppStep2, newAppStep3
    case newAppOpenBundleIds, newAppOpenASC, newAppApiNote

    // New sidebar sections/items
    case grpAds, secAds, secWorkflows, secDistribution

    // Apple Ads
    case adsBody, adsOrg, adsOrgHint, adsNeedOrg
    case adsTabAuth, adsTabCampaigns, adsTabAdGroups, adsTabKeywords, adsTabReports
    case adsAuthBody, adsAuthStatusBtn, adsDiscover, adsViewMe, adsLoginBtn, adsLoggingIn
    case adsName, adsClientId, adsTeamId, adsKeyId, adsPrivateKey, adsPrivateKeyHint
    case adsCampaign, adsAdGroup, adsListCampaigns, adsListAdGroups, adsListKeywords
    case adsReportsBody, adsPayloadFile, adsRunReport, adsNeedCampaign, adsNeedAdGroup

    // Workflows
    case wfBody, wfSecurityNote, wfFile, wfList, wfValidate
    case wfName, wfParams, wfParamsHint, wfDryRun, wfResume, wfResumeHint, wfRun, wfRunNow
    case wfRunConfirmTitle, wfRunConfirmMsg, wfRunning

    // Distribution
    case distBody, distAltDist, distMarketplace
    case distDomains, distKeys, distAppKey, distPackageId, distViewPackage
    case distWebhooks, distSearchDetails, distAppNote

    // TestFlight crashes
    case tfCrashes, tfLoadFeedback, tfLoadCrashes, tfSubmissionId, tfCrashLog, tfIncludeScreens

    // Help: skills & CI
    case helpSkillsTitle, helpSkillsBody, helpInstallSkills, helpInstalling, helpSkillsNpx
    case helpCITitle, helpCIBody, helpOpenSetupAsc

    // New groups / section titles
    case grpMonetization
    case secPricing, secReviews, secSubscriptions, secIAP, secAppEvents
    case secSubmission, secCompliance, secTeam, secTools

    // Generic action verbs (reused across the new views)
    case actList, actView, actSummary, actStatus, actCreate, actSet, actRegister
    case actRespond, actGenerate, actPing, actDoctor, actDeliveries, actInvite

    // Pricing
    case prBody, prCurrent, prTerritories, prPricePoints, prSchedule, prAvailability

    // Reviews
    case rvBody, rvReviews, rvRatings, rvRespond, rvStars, rvStarsAll, rvTerritory
    case rvOnlyUnresponded, rvReviewId, rvResponseText

    // Subscriptions
    case subBody, subGroups, subSubs, subPricing, subGroupId

    // IAP
    case iapBody, iapProducts, iapPricing, iapId

    // App events
    case aeBody, aeEvents, aeEventId

    // Submission lifecycle
    case smBody, smTabStatus, smTabDetails, smTabSubmissions, smTabNotes
    case smVersionId, smBuildId, smDetailId, smSubmissionId, smPlatform
    case smReviewStatus, smReviewDoctor, smDetailsForVersion, smAttachments
    case smSubmissionsList, smSubmissionsCreate, smSubmit, smSubmitStatus, smSubmitCancel
    case smBuildNotes, smGenerateNotes, smSinceTag

    // Compliance
    case cmBody, cmAgeRating, cmEncryption, cmCategories, cmEula, cmAppTags
    case cmCatSet, cmPrimary, cmSecondary

    // Team
    case tmBody, tmUsers, tmDevices, tmSandbox
    case tmInvite, tmEmail, tmRoles, tmAllApps
    case tmDeviceName, tmUdid, tmLocalUdid

    // Tools
    case tlBody, tlAccount, tlWebhooks, tlFastlane
    case tlWebhookId, tlMigrateImport, tlMigrateExport, tlFastlaneDir, tlVersionId

    // Analytics dashboard
    case secAnalytics, anTitle, anWeek, anLoad, anNeedVendorSales, anInsufficient
    case anWeekRangeFmt, anRaw, anWeekVsPrev, an30dVsPrev
    case anAcquisition, anRevenue, anSubscriptions, anUsage
    case anFirstDownloads, anRedownloads, anConversion, anImpressions, anPageViews, anUpdates, anReturns
    case anProceeds, anPayingUsers, anIap, anActiveSubs, anPaidSubs, anMrr, anRetention, anCrashes
    case anChartAcq, anChartRev, anNoChartData, an30dRevenue
    case anAllMetrics, anAnalyticsRestricted, anStatusUnavailable
    case anNeedRequest
    case anReportTitle, anReportBody, anReportLoad, anReportCreate
    case anReportProcessing, anReportForbidden, anReportCreated, anReportLoadedFmt, anReportWeekFallbackFmt
    case anAdminRequiredTitle, anAdminRequiredBody, anAnalyticsUsingProfileFmt, anOpenProfileSettings

    // Local metrics store (Milestone 1)
    case msTitle, msBody, msScanFolder, msImportCountFmt, msNoData
    case msDownloads7d, msProceeds7d, msSubscriptions30d, msNextPayout
    case msTrendTitle, msFromReports, msPortfolioTitle
    case ovMetricsTitle, ovFiscalTitle, ovFiscalPeriodFmt, ovFiscalPaymentFmt

    // Prefetch / overview app picker
    case ovChooseApp, secPrefetch, prefetchEnable, prefetchEnableDesc, prefetchSectionsLabel, prefetchNote

    // Marketing (custom product pages, experiments, pre-orders, nominations)
    case secMarketing, mkBody, mkProductPages, mkPreOrders, mkNominations

    // Market (public charts, iTunes search, SDK radar — Milestone 2)
    case grpMarket
    case secMarketCharts, secMarketSearch, secMarketSDKs
    case mktChartsBody, mktSearchBody, mktSDKsBody
    case mktCountry, mktRefresh, mktLoading, mktError
    case mktChartFree, mktChartPaid, mktChartGrossing, mktChartApps, mktChartGames
    case mktBookmark, mktBookmarked, mktRankFmt
    case mktSearchPlaceholder, mktNoResults, mktScreenshots, mktDescription, mktRatingFmt
    case mktMarketIndexTitle, mktMarketIndexUp, mktMarketIndexDown, mktMarketIndexFlat
    case mktMarketIndexFmt, mktRankDeltaFmt, mktSDKDisclaimer, mktSDKMatches
    case mktCompareOwnApps, mktNotInChart, mktOpenStore

    // Export + onboarding reports
    case exportCSV, exportJSON, exportSavedFmt
    case obReportsTitle, obReportsBody, obReportsVendorHint, obReportsFolderHint

    // Reviews table (M3)
    case rvTable, rvSearch, rvDate, rvTitle, rvBodyCol, rvResponded, rvNotResponded
    case rvRatingsSummary, rvAvgRating, rvTotalRatings

    // Payments tracker (M3)
    case secPayments, payBody, payNoDataTitle, payNoDataBody
    case payFiscalCalendar, payCurrentPeriod, payHistory, payPeriod, payPaymentDate
    case payProceeds, payStatus, payStatusUpcoming, payStatusPaid, payStatusIncomplete
    case payIncompleteHint

    // Tools export + local API (M3)
    case tlExport, tlExportBody, tlExportMetricsCSV, tlExportMetricsJSON, tlExportCharts
    case tlLocalAPI, tlLocalAPIHint
    case mkCustomPages, mkExperiments, mkPageName, mkPageId
    case mkTerritories, mkReleaseDate, mkTaId, mkAppNote
    case mkStatus, mkNomId, mkNomName, mkNomType, mkNomDesc, mkSubmitted
    case mkConfirmTitle, mkConfirmMsg
    case actDelete, actEnable, actDisable

    // Structured output rendering
    case outFormatted, outRaw, outCountFmt

    // Remote sync (CloudKit mirror)
    case secRemoteSync, syncEnable, syncEnableDesc, syncIntervalLabel, syncSectionsLabel
    case syncNow, syncNowRunning, syncNote, syncStatusLabel, syncNever
    case syncLastSyncedFmt, syncFailedFmt, syncNeedApp
    case syncEvery15m, syncHourly, syncEvery6h, syncDaily

    // iOS remote consumer (Phase 3b mirror reader)
    case rmAppsTitle, rmEmptyTitle, rmEmptyMessage, rmLoadError, rmUpdatedFmt
    case rmAppFmt, rmSectionsTitle, rmOfflineBadge, rmSignInTitle, rmSignInMessage
    // Remote settings
    case rmDataSection, rmMirroredCountFmt, rmLastSync, rmNever
    case rmCompatMacApp, rmSourceCode, rmImpressum, rmImpressumBody, rmAppInfoNote
}

// MARK: - Manager

@MainActor
public final class LocalizationManager: ObservableObject {
    @Published public var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: Self.storageKey) }
    }

    private static let storageKey = "app.language"

    public init() {
        let raw = UserDefaults.standard.string(forKey: Self.storageKey)
        language = raw.flatMap(AppLanguage.init(rawValue:)) ?? .system
    }

    /// The concrete language code used for lookups ("en" or "de").
    public var code: String {
        switch language {
        case .english: return "en"
        case .german:  return "de"
        case .system:
            let preferred = Locale.preferredLanguages.first ?? "en"
            return preferred.hasPrefix("de") ? "de" : "en"
        }
    }

    /// Localized string for a key, with optional `%@` arguments.
    public func callAsFunction(_ key: LocKey, _ args: CVarArg...) -> String {
        let entry = Strings.table[key]
        let template = entry?[code] ?? entry?["en"] ?? key.rawValue
        return args.isEmpty ? template : String(format: template, arguments: args)
    }

    public func displayName(for language: AppLanguage) -> String {
        language.nativeName
    }
}

// MARK: - Strings

enum Strings {
    static let table: [LocKey: [String: String]] = [
        // Common
        .appName:        ["en": "ASC Manager",      "de": "ASC Manager"],
        .refresh:        ["en": "Refresh",          "de": "Aktualisieren"],
        .done:           ["en": "Done",             "de": "Fertig"],
        .cancel:         ["en": "Cancel",           "de": "Abbrechen"],
        .save:           ["en": "Save",             "de": "Sichern"],
        .browse:         ["en": "Browse",           "de": "Durchsuchen"],
        .back:           ["en": "Back",             "de": "Zurück"],
        .next:           ["en": "Next",             "de": "Weiter"],
        .skip:           ["en": "Skip",             "de": "Überspringen"],
        .close:          ["en": "Close",            "de": "Schließen"],
        .ok:             ["en": "OK",               "de": "OK"],
        .load:           ["en": "Load",             "de": "Laden"],
        .connected:      ["en": "Connected",        "de": "Verbunden"],
        .notConfigured:  ["en": "Not configured",   "de": "Nicht konfiguriert"],

        // Sidebar / sections
        .secOverview:    ["en": "Overview",         "de": "Übersicht"],
        .secApps:        ["en": "Apps",             "de": "Apps"],
        .secVersions:    ["en": "Versions",         "de": "Versionen"],
        .secBuilds:      ["en": "Builds",           "de": "Builds"],
        .secTestFlight:  ["en": "TestFlight",       "de": "TestFlight"],
        .secSigning:     ["en": "Signing",          "de": "Signierung"],
        .secTerminal:    ["en": "Terminal",         "de": "Terminal"],
        .selectSection:  ["en": "Select a section", "de": "Bereich auswählen"],
        .activeAppHelp:  ["en": "Active app for Versions, Builds and TestFlight",
                          "de": "Aktive App für Versionen, Builds und TestFlight"],

        // Not configured
        .notConfiguredTitle: ["en": "No App Store Connect credentials",
                              "de": "Keine App Store Connect Zugangsdaten"],
        .notConfiguredDesc:  ["en": "ASC Manager talks to the asc CLI. Add an API key or select an existing profile to get started.",
                              "de": "ASC Manager nutzt das asc CLI. Füge einen API-Schlüssel hinzu oder wähle ein vorhandenes Profil, um zu starten."],
        .openSettings:       ["en": "Open Settings", "de": "Einstellungen öffnen"],

        // Overview
        .overviewTitle:     ["en": "Overview",       "de": "Übersicht"],
        .statApps:          ["en": "Apps",           "de": "Apps"],
        .statCertificates:  ["en": "Certificates",   "de": "Zertifikate"],
        .statProfiles:      ["en": "Profiles",       "de": "Profile"],
        .currentApp:        ["en": "Current App",    "de": "Aktuelle App"],
        .noAppSelectedShort:["en": "No app selected","de": "Keine App ausgewählt"],
        .loadAppsPrompt:    ["en": "Load your apps to get started.",
                             "de": "Lade deine Apps, um zu starten."],
        .loadApps:          ["en": "Load Apps",      "de": "Apps laden"],

        // Apps
        .appsTitle:     ["en": "Apps",               "de": "Apps"],
        .searchApps:    ["en": "Search apps",        "de": "Apps suchen"],
        .noAppsLoaded:  ["en": "No apps loaded",     "de": "Keine Apps geladen"],

        // Versions
        .versionsTitle: ["en": "Versions",   "de": "Versionen"],
        .colVersion:    ["en": "Version",    "de": "Version"],
        .colPlatform:   ["en": "Platform",   "de": "Plattform"],
        .colState:      ["en": "State",      "de": "Status"],
        .colRelease:    ["en": "Release",    "de": "Freigabe"],
        .colCreated:    ["en": "Created",    "de": "Erstellt"],
        .noVersions:    ["en": "No versions","de": "Keine Versionen"],
        .noVersionsDesc:["en": "This app has no App Store versions yet.",
                         "de": "Diese App hat noch keine App Store Versionen."],
        .pickAppToolbar:["en": "Pick an app from the toolbar menu.",
                         "de": "Wähle eine App im Symbolleisten-Menü."],
        .noAppSelectedTitle: ["en": "No App Selected", "de": "Keine App ausgewählt"],

        // Builds
        .buildsTitle:   ["en": "Builds",   "de": "Builds"],
        .colBuild:      ["en": "Build",    "de": "Build"],
        .colStatus:     ["en": "Status",   "de": "Status"],
        .colMinOS:      ["en": "Min OS",   "de": "Min. OS"],
        .colUploaded:   ["en": "Uploaded", "de": "Hochgeladen"],
        .colExpires:    ["en": "Expires",  "de": "Läuft ab"],
        .selectAppInApps: ["en": "Select an app in the Apps section",
                           "de": "Wähle eine App im Bereich „Apps“"],
        .noBuilds:      ["en": "No builds found", "de": "Keine Builds gefunden"],

        // TestFlight
        .testflightTitle: ["en": "TestFlight",    "de": "TestFlight"],
        .quickActions:    ["en": "Quick Actions", "de": "Schnellaktionen"],
        .betaGroups:      ["en": "Beta Groups",   "de": "Beta-Gruppen"],
        .betaGroupsDesc:  ["en": "List TestFlight groups", "de": "TestFlight-Gruppen anzeigen"],
        .testers:         ["en": "Testers",       "de": "Tester"],
        .testersDesc:     ["en": "List beta testers", "de": "Beta-Tester anzeigen"],
        .feedback:        ["en": "Feedback",      "de": "Feedback"],
        .feedbackDesc:    ["en": "View tester feedback", "de": "Tester-Feedback anzeigen"],
        .output:          ["en": "Output",        "de": "Ausgabe"],
        .selectAppFromApps: ["en": "Select an app from the Apps section",
                             "de": "Wähle eine App im Bereich „Apps“"],

        // Signing
        .signingTitle:   ["en": "Signing",       "de": "Signierung"],
        .certificates:   ["en": "Certificates",  "de": "Zertifikate"],
        .profiles:       ["en": "Profiles",      "de": "Profile"],
        .noCertificates: ["en": "No certificates","de": "Keine Zertifikate"],
        .noProfiles:     ["en": "No profiles",   "de": "Keine Profile"],
        .certExp:        ["en": "Exp:",           "de": "Gültig bis:"],

        // Terminal
        .terminalTitle:  ["en": "Terminal", "de": "Terminal"],
        .clear:          ["en": "Clear",    "de": "Leeren"],
        .terminalHint:   ["en": "Run any asc command. Arguments are space-separated.\nExample: apps list --limit 5",
                          "de": "Führe einen beliebigen asc-Befehl aus. Argumente werden durch Leerzeichen getrennt.\nBeispiel: apps list --limit 5"],
        .terminalPlaceholder: ["en": "apps list --limit 10", "de": "apps list --limit 10"],

        // Settings
        .settingsTitle:  ["en": "Settings",  "de": "Einstellungen"],
        .secGeneral:     ["en": "General",    "de": "Allgemein"],
        .secLanguage:    ["en": "Language",  "de": "Sprache"],
        .language:       ["en": "Language",  "de": "Sprache"],
        .languageHelp:   ["en": "Choose the interface language.",
                          "de": "Wähle die Sprache der Benutzeroberfläche."],
        .authProfiles:   ["en": "Authentication Profiles", "de": "Authentifizierungsprofile"],
        .profileRolesSection: ["en": "Profile Roles", "de": "Profil-Rollen"],
        .profileRolesDesc: ["en": "Assign different API keys to operations that need specific App Store Connect roles. Unassigned roles fall back to the active profile above.",
                            "de": "Weise verschiedenen Abfragen die passenden API-Schlüssel zu, je nach benötigter App-Store-Connect-Rolle. Nicht zugewiesene Rollen nutzen das aktive Profil oben."],
        .profileCapGeneral: ["en": "General (default)", "de": "Allgemein (Standard)"],
        .profileCapAnalytics: ["en": "Analytics", "de": "Analytics"],
        .profileCapFinance: ["en": "Sales & Finance", "de": "Verkauf & Finanzen"],
        .profileCapAdmin: ["en": "Team & Admin", "de": "Team & Admin"],
        .profileCapGeneralHelp: ["en": "Apps, builds, metadata, TestFlight, signing, and most other operations.",
                                 "de": "Apps, Builds, Metadaten, TestFlight, Signierung und die meisten anderen Vorgänge."],
        .profileCapAnalyticsHelp: ["en": "App Analytics insights and report requests. Requires Admin or Account Holder role.",
                                   "de": "App-Analytics-Kennzahlen und Report-Anfragen. Erfordert Admin- oder Account-Holder-Rolle."],
        .profileCapFinanceHelp: ["en": "Sales and finance reports (vendor number required).",
                                  "de": "Verkaufs- und Finanzberichte (Lieferantennummer erforderlich)."],
        .profileCapAdminHelp: ["en": "Team invites and other elevated account operations.",
                               "de": "Team-Einladungen und andere erweiterte Kontovorgänge."],
        .profileCapUseDefault: ["en": "Use active profile", "de": "Aktives Profil verwenden"],
        .profileCapActiveFmt: ["en": "Using profile “%@”", "de": "Verwendet Profil „%@“"],
        .noKeysFound:    ["en": "No API keys found", "de": "Keine API-Schlüssel gefunden"],
        .noKeysDesc:     ["en": "Add an App Store Connect API key to start managing your apps.",
                          "de": "Füge einen App Store Connect API-Schlüssel hinzu, um deine Apps zu verwalten."],
        .addApiKey:      ["en": "Add API Key", "de": "API-Schlüssel hinzufügen"],
        .storedInFmt:    ["en": "Stored in %@", "de": "Gespeichert in %@"],
        .defaultTag:     ["en": "default",     "de": "Standard"],
        .keyIdFmt:       ["en": "Key ID %@",   "de": "Schlüssel-ID %@"],
        .ascBinary:      ["en": "asc Binary",  "de": "asc-Programm"],
        .binaryFound:    ["en": "Binary found", "de": "Programm gefunden"],
        .binaryNotFound: ["en": "Binary not found at this path",
                          "de": "Programm unter diesem Pfad nicht gefunden"],
        .installHintFmt: ["en": "Install with: %@", "de": "Installieren mit: %@"],
        .ascTimeout:     ["en": "Request timeout", "de": "Anfrage-Timeout"],
        .ascTimeoutDesc: ["en": "Maximum time per API call. Raise this if analytics or compare commands fail with “context deadline exceeded”.",
                          "de": "Maximale Dauer pro API-Aufruf. Erhöhe diesen Wert, wenn Analyse- oder Vergleichsbefehle mit „context deadline exceeded“ fehlschlagen."],
        .ascTimeoutValueFmt: ["en": "%d seconds", "de": "%d Sekunden"],
        .connection:     ["en": "Connection",  "de": "Verbindung"],
        .testConnection: ["en": "Test Connection", "de": "Verbindung testen"],
        .testing:        ["en": "Testing…",    "de": "Teste…"],
        .connectionSuccessFmt: ["en": "Connection successful — credentials for profile “%@” are valid.",
                                "de": "Verbindung erfolgreich — Zugangsdaten für Profil „%@“ sind gültig."],
        .onboardingSection: ["en": "Getting Started", "de": "Erste Schritte"],
        .replayOnboarding:  ["en": "Show Setup Guide Again", "de": "Einrichtungsassistent erneut anzeigen"],
        .replayOnboardingDesc: ["en": "Walk through the setup steps again.",
                                "de": "Gehe die Einrichtungsschritte erneut durch."],
        .showOnboarding: ["en": "Show Guide", "de": "Anzeigen"],

        // Add key
        .addKeyTitle:   ["en": "Add API Key", "de": "API-Schlüssel hinzufügen"],
        .profileName:   ["en": "Profile Name", "de": "Profilname"],
        .profileNameHint: ["en": "A friendly name for this key.",
                           "de": "Ein einprägsamer Name für diesen Schlüssel."],
        .keyId:         ["en": "Key ID", "de": "Schlüssel-ID"],
        .keyIdHint:     ["en": "App Store Connect → Users and Access → Integrations → Keys.",
                         "de": "App Store Connect → Benutzer und Zugriff → Integrationen → Schlüssel."],
        .issuerId:      ["en": "Issuer ID", "de": "Aussteller-ID"],
        .issuerIdHint:  ["en": "Shown at the top of the Keys page.",
                         "de": "Wird oben auf der Schlüssel-Seite angezeigt."],
        .privateKey:    ["en": "Private Key (.p8)", "de": "Privater Schlüssel (.p8)"],
        .privateKeyHint:["en": "Downloaded once from App Store Connect. The key is stored in your keychain.",
                         "de": "Einmalig aus App Store Connect geladen. Der Schlüssel wird in deinem Schlüsselbund gespeichert."],
        .saveKey:       ["en": "Save Key", "de": "Schlüssel sichern"],
        .saving:        ["en": "Saving…",  "de": "Sichere…"],

        // Onboarding
        .obWelcomeTitle:    ["en": "Welcome to ASC Manager",
                             "de": "Willkommen bei ASC Manager"],
        .obWelcomeSubtitle: ["en": "A native macOS interface for App Store Connect, powered by the asc CLI. Let’s get you set up in a minute.",
                             "de": "Eine native macOS-Oberfläche für App Store Connect, basierend auf dem asc CLI. Lass uns dich in einer Minute einrichten."],
        .obChooseLanguage:  ["en": "Language", "de": "Sprache"],
        .obGetStarted:      ["en": "Get Started", "de": "Los geht’s"],
        .obInstallTitle:    ["en": "Install the asc CLI", "de": "asc CLI installieren"],
        .obInstallBody:     ["en": "ASC Manager runs the asc command-line tool under the hood. It must be installed on your Mac.",
                             "de": "ASC Manager führt im Hintergrund das asc-Kommandozeilentool aus. Es muss auf deinem Mac installiert sein."],
        .obInstalled:       ["en": "asc is installed and ready.", "de": "asc ist installiert und bereit."],
        .obNotInstalled:    ["en": "asc was not found. Install it, then re-check.",
                             "de": "asc wurde nicht gefunden. Installiere es und prüfe erneut."],
        .obBrewHint:        ["en": "Install via Homebrew:", "de": "Installation über Homebrew:"],
        .obRecheck:         ["en": "Re-check", "de": "Erneut prüfen"],
        .obConnectTitle:    ["en": "Connect your account", "de": "Konto verbinden"],
        .obConnectBody:     ["en": "Add an App Store Connect API key, or pick an existing asc profile. Your key is stored securely in the macOS keychain.",
                             "de": "Füge einen App Store Connect API-Schlüssel hinzu oder wähle ein vorhandenes asc-Profil. Dein Schlüssel wird sicher im macOS-Schlüsselbund gespeichert."],
        .obUseExisting:     ["en": "Existing profiles", "de": "Vorhandene Profile"],
        .obNoProfilesYet:   ["en": "No profiles yet — add your first API key.",
                             "de": "Noch keine Profile — füge deinen ersten API-Schlüssel hinzu."],
        .obConnectedAs:     ["en": "Connected", "de": "Verbunden"],
        .obFinishTitle:     ["en": "You’re all set", "de": "Alles bereit"],
        .obFinishBody:      ["en": "You can manage apps, versions, builds, TestFlight and signing — or run any asc command from the built-in Terminal.",
                             "de": "Du kannst Apps, Versionen, Builds, TestFlight und Signierung verwalten — oder beliebige asc-Befehle im integrierten Terminal ausführen."],
        .obFinish:          ["en": "Start Using ASC Manager", "de": "ASC Manager starten"],
        .stepOfFmt:         ["en": "Step %@ of %@", "de": "Schritt %@ von %@"],

        // New sidebar sections
        .secMetadata: ["en": "Metadata",  "de": "Metadaten"],
        .secRelease:  ["en": "Release",   "de": "Veröffentlichung"],
        .secReports:  ["en": "Reports",   "de": "Berichte"],
        .secHelp:     ["en": "Help",      "de": "Hilfe"],

        // Help / manual
        .helpTitle:        ["en": "Help & Manual", "de": "Hilfe & Handbuch"],
        .helpGetKeyTitle:  ["en": "Get an App Store Connect API key",
                            "de": "App Store Connect API-Schlüssel erstellen"],
        .helpGetKeyIntro:  ["en": "You need an API key to let ASC Manager talk to App Store Connect. You must have the Admin or Account Holder role to create Team keys.",
                            "de": "Du benötigst einen API-Schlüssel, damit ASC Manager mit App Store Connect kommunizieren kann. Zum Erstellen von Team-Schlüsseln brauchst du die Rolle „Admin“ oder „Account Holder“."],
        .helpStep1: ["en": "Sign in at appstoreconnect.apple.com and open Users and Access.",
                     "de": "Melde dich auf appstoreconnect.apple.com an und öffne „Benutzer und Zugriff“."],
        .helpStep2: ["en": "Go to the Integrations tab, then Team Keys (App Store Connect API).",
                     "de": "Öffne den Tab „Integrationen“ und dann „Team-Schlüssel“ (App Store Connect API)."],
        .helpStep3: ["en": "Click the + button, name the key and choose an access role (Admin or App Manager is typical), then Generate.",
                     "de": "Klicke auf „+“, benenne den Schlüssel, wähle eine Zugriffsrolle (üblich: Admin oder App-Manager) und klicke auf „Generieren“."],
        .helpStep4: ["en": "Copy the Key ID, and note the Issuer ID shown at the top of the page.",
                     "de": "Kopiere die Schlüssel-ID und notiere die Aussteller-ID oben auf der Seite."],
        .helpStep5: ["en": "Download the .p8 private key file. Important: it can only be downloaded once — keep it safe.",
                     "de": "Lade die private .p8-Schlüsseldatei herunter. Wichtig: Sie kann nur einmal heruntergeladen werden — bewahre sie sicher auf."],
        .helpOpenKeysPage: ["en": "Open App Store Connect → Keys",
                            "de": "App Store Connect → Schlüssel öffnen"],
        .helpInstallTitle: ["en": "Install the asc CLI", "de": "asc CLI installieren"],
        .helpInstallBody:  ["en": "ASC Manager drives the asc command-line tool. Install it with Homebrew, then set its path in Settings if it isn’t found automatically.",
                            "de": "ASC Manager nutzt das asc-Kommandozeilentool. Installiere es mit Homebrew und lege den Pfad in den Einstellungen fest, falls es nicht automatisch gefunden wird."],
        .helpFaqTitle:     ["en": "Troubleshooting", "de": "Fehlerbehebung"],
        .faqQ1: ["en": "“Binary not found”", "de": "„Programm nicht gefunden“"],
        .faqA1: ["en": "Install asc (brew install asc) or set the correct path in Settings → asc Binary. Homebrew installs to /opt/homebrew/bin on Apple Silicon.",
                 "de": "Installiere asc (brew install asc) oder setze den richtigen Pfad unter Einstellungen → asc-Programm. Homebrew installiert auf Apple Silicon nach /opt/homebrew/bin."],
        .faqQ2: ["en": "“Forbidden” / 403 errors", "de": "„Forbidden“ / 403-Fehler"],
        .faqA2: ["en": "Your API key is valid but lacks permission for that resource. Use a key with a higher role (e.g. Admin), or check that the key has access to the app.",
                 "de": "Dein API-Schlüssel ist gültig, hat aber keine Berechtigung für diese Ressource. Verwende einen Schlüssel mit höherer Rolle (z. B. Admin) oder prüfe den App-Zugriff des Schlüssels."],
        .faqQ3: ["en": "I lost my .p8 file", "de": "Ich habe meine .p8-Datei verloren"],
        .faqA3: ["en": "Apple only lets you download it once. If lost, revoke the old key in App Store Connect and generate a new one.",
                 "de": "Apple erlaubt den Download nur einmal. Bei Verlust widerrufe den alten Schlüssel in App Store Connect und erstelle einen neuen."],
        .faqQ4: ["en": "Where is the Issuer ID?", "de": "Wo finde ich die Aussteller-ID?"],
        .faqA4: ["en": "On the Keys page in App Store Connect, the Issuer ID is shown above the list of keys and is shared by all keys.",
                 "de": "Auf der Schlüssel-Seite in App Store Connect wird die Aussteller-ID über der Schlüsselliste angezeigt und gilt für alle Schlüssel."],
        .faqQ5: ["en": "Where are my credentials stored?", "de": "Wo werden meine Zugangsdaten gespeichert?"],
        .faqA5: ["en": "asc stores keys in your macOS keychain as named profiles. ASC Manager just selects which profile to use.",
                 "de": "asc speichert Schlüssel als benannte Profile in deinem macOS-Schlüsselbund. ASC Manager wählt nur das zu verwendende Profil aus."],
        .helpLinksTitle:  ["en": "Useful links", "de": "Nützliche Links"],
        .helpOpenASCHome: ["en": "Open App Store Connect", "de": "App Store Connect öffnen"],
        .helpOpenAscDocs: ["en": "Open asc CLI website", "de": "asc-CLI-Website öffnen"],

        // Release
        .releaseTitle:       ["en": "Release", "de": "Veröffentlichung"],
        .relHealth:          ["en": "Health", "de": "Status"],
        .relNextAction:      ["en": "Next action", "de": "Nächster Schritt"],
        .relBlockers:        ["en": "Blockers", "de": "Blockierungen"],
        .relLatestBuild:     ["en": "Latest build", "de": "Neuester Build"],
        .relAppStoreState:   ["en": "App Store state", "de": "App-Store-Status"],
        .relReviewState:     ["en": "Review state", "de": "Prüfungsstatus"],
        .relTestflightState: ["en": "TestFlight review", "de": "TestFlight-Prüfung"],
        .relPhased:          ["en": "Phased release", "de": "Schrittweise Freigabe"],
        .relConfigured:      ["en": "configured", "de": "konfiguriert"],
        .relOpenASC:         ["en": "Open in App Store Connect", "de": "In App Store Connect öffnen"],
        .relValidate:        ["en": "Run readiness check", "de": "Bereitschaftsprüfung starten"],
        .relValidating:      ["en": "Checking…", "de": "Prüfe…"],
        .relReleaseNow:      ["en": "Release this version now", "de": "Diese Version jetzt freigeben"],
        .relReleasing:       ["en": "Releasing…", "de": "Gebe frei…"],
        .relReleaseConfirmTitle: ["en": "Release this version?", "de": "Diese Version freigeben?"],
        .relReleaseConfirmMsg:   ["en": "This releases the approved version that is pending developer release. It will go live on the App Store.",
                                  "de": "Dies gibt die genehmigte Version frei, die auf die Entwicklerfreigabe wartet. Sie wird im App Store veröffentlicht."],
        .relNoStatus:        ["en": "No status loaded yet.", "de": "Noch kein Status geladen."],
        .relResultTitle:     ["en": "Result", "de": "Ergebnis"],
        .relYes:             ["en": "Release", "de": "Freigeben"],
        .relNo:              ["en": "Cancel", "de": "Abbrechen"],

        // Metadata
        .metadataTitle:   ["en": "Metadata", "de": "Metadaten"],
        .mdSelectVersion: ["en": "Version", "de": "Version"],
        .mdLocale:        ["en": "Language", "de": "Sprache"],
        .mdDescription:   ["en": "Description", "de": "Beschreibung"],
        .mdKeywords:      ["en": "Keywords (comma-separated)", "de": "Schlüsselwörter (kommagetrennt)"],
        .mdWhatsNew:      ["en": "What’s New", "de": "Neue Funktionen"],
        .mdPromotional:   ["en": "Promotional Text", "de": "Werbetext"],
        .mdSupportUrl:    ["en": "Support URL", "de": "Support-URL"],
        .mdMarketingUrl:  ["en": "Marketing URL", "de": "Marketing-URL"],
        .mdSave:          ["en": "Save Metadata", "de": "Metadaten sichern"],
        .mdSaving:        ["en": "Saving…", "de": "Sichere…"],
        .mdSaveConfirmTitle: ["en": "Save metadata changes?", "de": "Metadaten-Änderungen sichern?"],
        .mdSaveConfirmMsg:   ["en": "This updates the App Store metadata for this locale in App Store Connect.",
                              "de": "Dies aktualisiert die App-Store-Metadaten für diese Sprache in App Store Connect."],
        .mdSaved:         ["en": "Metadata saved.", "de": "Metadaten gesichert."],
        .mdNoLocalizations: ["en": "No localizations for this version.", "de": "Keine Lokalisierungen für diese Version."],
        .mdPickAppVersion:  ["en": "Select an app, then a version to edit its metadata.",
                             "de": "Wähle eine App und dann eine Version, um deren Metadaten zu bearbeiten."],

        // TestFlight tables
        .tfGroups:      ["en": "Beta Groups", "de": "Beta-Gruppen"],
        .tfTesters:     ["en": "Testers", "de": "Tester"],
        .tfInternal:    ["en": "Internal", "de": "Intern"],
        .tfExternal:    ["en": "External", "de": "Extern"],
        .tfColName:     ["en": "Name", "de": "Name"],
        .tfColEmail:    ["en": "Email", "de": "E-Mail"],
        .tfColState:    ["en": "State", "de": "Status"],
        .tfColType:     ["en": "Type", "de": "Typ"],
        .tfColCreated:  ["en": "Created", "de": "Erstellt"],
        .tfColAccess:   ["en": "Builds", "de": "Builds"],
        .tfColFeedback: ["en": "Feedback", "de": "Feedback"],
        .tfNotify:      ["en": "Notify testers of latest build", "de": "Tester über neuesten Build benachrichtigen"],
        .tfNotifyConfirmTitle: ["en": "Notify testers?", "de": "Tester benachrichtigen?"],
        .tfNotifyConfirmMsg:   ["en": "This sends a TestFlight notification for the latest build to your testers.",
                                "de": "Dies sendet deinen Testern eine TestFlight-Benachrichtigung für den neuesten Build."],
        .tfNoGroups:    ["en": "No beta groups", "de": "Keine Beta-Gruppen"],
        .tfNoTesters:   ["en": "No testers", "de": "Keine Tester"],
        .tfYes:         ["en": "Yes", "de": "Ja"],
        .tfNo:          ["en": "No", "de": "Nein"],
        .tfNoLatestBuild: ["en": "No build available to notify about.", "de": "Kein Build zum Benachrichtigen vorhanden."],

        // Reports
        .reportsTitle:    ["en": "Reports", "de": "Berichte"],
        .rpVendor:        ["en": "Vendor Number", "de": "Anbieternummer"],
        .rpVendorHint:    ["en": "Found in App Store Connect → Payments and Financial Reports. Required for sales and finance reports.",
                           "de": "Zu finden in App Store Connect → Zahlungen und Finanzberichte. Erforderlich für Verkaufs- und Finanzberichte."],
        .rpNeedVendor:    ["en": "Enter your vendor number to download reports.", "de": "Gib deine Anbieternummer ein, um Berichte herunterzuladen."],
        .rpAnalytics:     ["en": "Analytics & Sales", "de": "Analysen & Verkäufe"],
        .rpFinance:       ["en": "Finance", "de": "Finanzen"],
        .rpRequests:      ["en": "Report requests", "de": "Berichtsanfragen"],
        .rpCreateRequest: ["en": "Create ongoing report request", "de": "Laufende Berichtsanfrage erstellen"],
        .rpSalesReport:   ["en": "Sales summary", "de": "Verkaufsübersicht"],
        .rpFrequency:     ["en": "Frequency", "de": "Häufigkeit"],
        .rpDaily:         ["en": "Daily", "de": "Täglich"],
        .rpWeekly:        ["en": "Weekly", "de": "Wöchentlich"],
        .rpMonthly:       ["en": "Monthly", "de": "Monatlich"],
        .rpDate:          ["en": "Date", "de": "Datum"],
        .rpDownload:      ["en": "Download", "de": "Herunterladen"],
        .rpRegion:        ["en": "Region", "de": "Region"],
        .rpFinanceRegions:["en": "List finance regions", "de": "Finanzregionen anzeigen"],
        .rpFinanceReport: ["en": "Financial report (YYYY-MM)", "de": "Finanzbericht (JJJJ-MM)"],
        .rpResult:        ["en": "Output", "de": "Ausgabe"],
        .rpSaveVendor:    ["en": "Save", "de": "Sichern"],
        .rpFolder:        ["en": "Save Folder", "de": "Speicherordner"],
        .rpChooseFolder:  ["en": "Choose…", "de": "Auswählen…"],
        .rpDecompress:    ["en": "Decompress to plain .tsv", "de": "In unkomprimiertes .tsv entpacken"],
        .rpReveal:        ["en": "Show in Finder", "de": "Im Finder anzeigen"],
        .rpSavedToFmt:    ["en": "Saved to: %@", "de": "Gespeichert unter: %@"],
        .rpScanImport:    ["en": "Import folder into metrics store", "de": "Ordner in Metrik-Speicher importieren"],
        .rpImportedFmt:   ["en": "Imported %d rows from sales reports.", "de": "%d Zeilen aus Verkaufsberichten importiert."],

        // Sidebar groups + new sections
        .grpApp:        ["en": "App", "de": "App"],
        .grpBuild:      ["en": "Builds", "de": "Builds"],
        .grpRelease:    ["en": "Release", "de": "Veröffentlichung"],
        .grpDeveloper:  ["en": "Developer", "de": "Entwickler"],
        .secMedia:      ["en": "Media", "de": "Medien"],
        .secXcodeCloud: ["en": "Xcode Cloud", "de": "Xcode Cloud"],
        .secDiscover:   ["en": "Discover", "de": "Entdecken"],
        .secBundleIds:  ["en": "Bundle IDs", "de": "Bundle-IDs"],
        .secNotarization: ["en": "Notarization", "de": "Notarisierung"],

        // Build upload
        .buUpload:       ["en": "Upload Build", "de": "Build hochladen"],
        .buUploadTitle:  ["en": "Upload a build", "de": "Build hochladen"],
        .buFile:         ["en": "Artifact file", "de": "Artefaktdatei"],
        .buVersion:      ["en": "Version", "de": "Version"],
        .buBuildNumber:  ["en": "Build number", "de": "Build-Nummer"],
        .buAutoExtract:  ["en": "auto-detected", "de": "automatisch erkannt"],
        .buDryRun:       ["en": "Dry run (preview only)", "de": "Probelauf (nur Vorschau)"],
        .buDryRunHint:   ["en": "Reserves the upload without sending the file. Turn off to upload for real.",
                          "de": "Reserviert den Upload, ohne die Datei zu senden. Deaktivieren, um wirklich hochzuladen."],
        .buUploading:    ["en": "Uploading…", "de": "Lade hoch…"],
        .buDryRunAction: ["en": "Preview (dry run)", "de": "Vorschau (Probelauf)"],

        // Publish
        .pubTitle:          ["en": "Publish to App Store", "de": "Im App Store veröffentlichen"],
        .pubBody:           ["en": "Upload an IPA, attach it to a version, optionally apply metadata, and optionally submit for review.",
                             "de": "IPA hochladen, an eine Version anhängen, optional Metadaten anwenden und optional zur Prüfung einreichen."],
        .pubIpa:            ["en": "IPA file", "de": "IPA-Datei"],
        .pubVersion:        ["en": "Version", "de": "Version"],
        .pubMetadataDir:    ["en": "Metadata folder (optional)", "de": "Metadaten-Ordner (optional)"],
        .pubOptional:       ["en": "Optional", "de": "Optional"],
        .pubSubmitForReview:["en": "Submit for review", "de": "Zur Prüfung einreichen"],
        .pubRunning:        ["en": "Working…", "de": "Arbeite…"],
        .pubUploadOnly:     ["en": "Upload & attach", "de": "Hochladen & anhängen"],
        .pubSubmit:         ["en": "Upload & submit", "de": "Hochladen & einreichen"],
        .pubConfirmTitle:   ["en": "Submit this version for review?", "de": "Diese Version zur Prüfung einreichen?"],
        .pubConfirmMsg:     ["en": "This uploads the build and submits the version to App Review. This is a real submission.",
                             "de": "Dies lädt den Build hoch und reicht die Version zur App-Prüfung ein. Dies ist eine echte Einreichung."],

        // Metadata files
        .mdFilesTitle: ["en": "Metadata files", "de": "Metadaten-Dateien"],
        .mdFilesBody:  ["en": "Pull canonical metadata files for the selected version, validate them offline, then apply changes back.",
                        "de": "Kanonische Metadaten-Dateien für die gewählte Version abrufen, offline prüfen und Änderungen zurück anwenden."],
        .mdPull:       ["en": "Pull", "de": "Abrufen"],
        .mdValidate:   ["en": "Validate", "de": "Prüfen"],
        .mdApply:      ["en": "Apply", "de": "Anwenden"],

        // Global online/offline data mode
        .modeOnline:     ["en": "Online", "de": "Online"],
        .modeOffline:    ["en": "Offline", "de": "Offline"],
        .modeTitle:      ["en": "Data mode", "de": "Datenmodus"],
        .modeOnlineDesc: ["en": "Live data from App Store Connect (network requests allowed).",
                          "de": "Live-Daten von App Store Connect (Netzwerkabrufe erlaubt)."],
        .modeOfflineDesc: ["en": "Work from local files & cached data — automatic network fetches (prefetch, sync, auto-load) are paused.",
                           "de": "Arbeitet mit lokalen Dateien & zwischengespeicherten Daten — automatische Netzwerkabrufe (Vorladen, Sync, Auto-Laden) sind pausiert."],
        .modeHeaderHint: ["en": "Switch data mode (online / offline)", "de": "Datenmodus wechseln (online / offline)"],

        // Metadata validation result
        .mdValValid:        ["en": "Valid", "de": "Gültig"],
        .mdValInvalid:      ["en": "Invalid", "de": "Ungültig"],
        .mdValFilesScanned: ["en": "Files scanned", "de": "Dateien geprüft"],
        .mdValErrors:       ["en": "Errors", "de": "Fehler"],
        .mdValWarnings:     ["en": "Warnings", "de": "Warnungen"],
        .mdValIssues:       ["en": "Issues", "de": "Probleme"],
        .mdValNoIssues:     ["en": "No issues found.", "de": "Keine Probleme gefunden."],

        // Metadata source mode
        .mdSource:       ["en": "Source", "de": "Quelle"],
        .mdSourceOnline: ["en": "Online (ASC)", "de": "Online (ASC)"],
        .mdSourceLocal:  ["en": "Local folder", "de": "Lokaler Ordner"],
        .mdLocalTitle:   ["en": "Local metadata files", "de": "Lokale Metadaten-Dateien"],
        .mdLocalBody:    ["en": "Browse and edit the text files that `asc metadata pull` wrote into the folder. Save changes locally, then use Validate / Apply above to upload them.",
                          "de": "Durchsuche und bearbeite die Textdateien, die `asc metadata pull` in den Ordner geschrieben hat. Änderungen lokal sichern und oben mit „Prüfen“ / „Anwenden“ hochladen."],
        .mdLocalNoFolder: ["en": "Choose a folder above to browse local files.",
                           "de": "Wähle oben einen Ordner, um lokale Dateien anzuzeigen."],
        .mdLocalNoFiles: ["en": "No editable text files found in this folder.",
                          "de": "Keine bearbeitbaren Textdateien in diesem Ordner gefunden."],
        .mdLocalFiles:   ["en": "Files", "de": "Dateien"],
        .mdLocalSave:    ["en": "Save file", "de": "Datei sichern"],
        .mdLocalSaved:   ["en": "Saved.", "de": "Gesichert."],
        .mdLocalReload:  ["en": "Reload", "de": "Neu laden"],
        .mdLocalReadErr: ["en": "Could not read this file.", "de": "Datei konnte nicht gelesen werden."],

        // Metadata agent brief
        .mdAgentTitle:   ["en": "Agent brief", "de": "Agent-Briefing"],
        .mdAgentBody:    ["en": "Generate a brief an AI agent can follow to (re)write all localized metadata, respecting App Store Connect limits — ideal for first setup or a full rewrite. Writes AGENT_BRIEF.md and metadata.plan.json into the folder.",
                          "de": "Erzeuge ein Briefing, dem ein KI-Agent folgen kann, um alle lokalisierten Metadaten (neu) zu schreiben – unter Beachtung der App-Store-Connect-Limits. Ideal für die Ersteinrichtung oder eine komplette Überarbeitung. Schreibt AGENT_BRIEF.md und metadata.plan.json in den Ordner."],
        .mdAgentGoal:    ["en": "App goal / positioning", "de": "App-Ziel / Positionierung"],
        .mdAgentGoalHint: ["en": "What the app does and the value it delivers.",
                           "de": "Was die App macht und welchen Nutzen sie bietet."],
        .mdAgentAudience: ["en": "Target audience", "de": "Zielgruppe"],
        .mdAgentTone:    ["en": "Tone & voice", "de": "Tonalität & Stil"],
        .mdAgentPrinciples: ["en": "Principles / do's & don'ts", "de": "Grundsätze / Do's & Don'ts"],
        .mdAgentLocales: ["en": "Target locales (comma-separated; blank = current)",
                          "de": "Ziel-Sprachen (kommagetrennt; leer = aktuelle)"],
        .mdAgentInclCurrent: ["en": "Include current metadata snapshot",
                              "de": "Aktuellen Metadaten-Stand einschließen"],
        .mdAgentGenerate: ["en": "Generate brief", "de": "Briefing erzeugen"],
        .mdAgentGenerated: ["en": "Brief written to:", "de": "Briefing geschrieben nach:"],
        .mdAgentNeedsFolder: ["en": "Choose a metadata folder first.", "de": "Zuerst einen Metadaten-Ordner wählen."],
        .mdAgentShowFinder: ["en": "Show in Finder", "de": "Im Finder zeigen"],

        // Media
        .mediaTitle:       ["en": "Media", "de": "Medien"],
        .mediaScreenshots: ["en": "Screenshots", "de": "Screenshots"],
        .mediaPreviews:    ["en": "App Previews", "de": "App-Vorschauen"],
        .mediaDevice:      ["en": "Device type", "de": "Gerätetyp"],
        .mediaList:        ["en": "List", "de": "Auflisten"],
        .mediaSizes:       ["en": "Sizes", "de": "Größen"],
        .mediaUpload:      ["en": "Upload folder…", "de": "Ordner hochladen…"],
        .mediaDownload:    ["en": "Download to…", "de": "Herunterladen nach…"],

        // Discover
        .discoverTitle: ["en": "Discover", "de": "Entdecken"],
        .discoverBody:  ["en": "Search the asc command tree, inspect API endpoint schemas, and check capability coverage — all locally.",
                         "de": "Den asc-Befehlsbaum durchsuchen, API-Endpunkt-Schemas inspizieren und die Funktionsabdeckung prüfen — alles lokal."],
        .discSearch:        ["en": "Search", "de": "Suche"],
        .discSchema:        ["en": "Schema", "de": "Schema"],
        .discCapabilities:  ["en": "Capabilities", "de": "Funktionen"],
        .discSearchPlaceholder: ["en": "e.g. submit app for review", "de": "z. B. App zur Prüfung einreichen"],
        .discSchemaPlaceholder: ["en": "e.g. GET /v1/apps  (empty = list all)", "de": "z. B. GET /v1/apps  (leer = alle auflisten)"],
        .discLookup:        ["en": "Look up", "de": "Nachschlagen"],
        .discLoadCapabilities: ["en": "Load capability coverage", "de": "Funktionsabdeckung laden"],

        // Xcode Cloud
        .xcTitle:          ["en": "Xcode Cloud", "de": "Xcode Cloud"],
        .xcBody:           ["en": "Trigger Xcode Cloud workflows and monitor build runs without opening the web UI.",
                            "de": "Xcode-Cloud-Workflows auslösen und Build-Läufe überwachen, ohne die Web-Oberfläche zu öffnen."],
        .xcWorkflows:      ["en": "Workflows", "de": "Workflows"],
        .xcWorkflowName:   ["en": "Workflow name", "de": "Workflow-Name"],
        .xcBranch:         ["en": "Branch", "de": "Branch"],
        .xcWait:           ["en": "Wait for completion", "de": "Auf Abschluss warten"],
        .xcRun:            ["en": "Run workflow", "de": "Workflow starten"],
        .xcTrigger:        ["en": "Trigger a build", "de": "Build auslösen"],
        .xcRunId:          ["en": "Build run ID", "de": "Build-Lauf-ID"],
        .xcCheckStatus:    ["en": "Check status", "de": "Status prüfen"],
        .xcBuildRunStatus: ["en": "Build run status", "de": "Build-Lauf-Status"],

        // Signing tabs / bundle IDs / notarization
        .signCertsProfiles: ["en": "Certificates & Profiles", "de": "Zertifikate & Profile"],
        .biEmpty:           ["en": "No bundle IDs", "de": "Keine Bundle-IDs"],
        .biLoadHint:        ["en": "Bundle IDs registered for your team will appear here.",
                             "de": "Für dein Team registrierte Bundle-IDs erscheinen hier."],
        .biName:            ["en": "Name", "de": "Name"],
        .biIdentifier:      ["en": "Identifier", "de": "Bezeichner"],
        .notarizeBody:      ["en": "Submit a macOS .zip, .dmg or .pkg to the Apple notary service and track submissions.",
                             "de": "Eine macOS-.zip, -.dmg oder -.pkg an den Apple-Notardienst senden und Einreichungen verfolgen."],
        .notarizeFile:      ["en": "File to notarize", "de": "Zu notarisierende Datei"],
        .notarizeList:      ["en": "List submissions", "de": "Einreichungen auflisten"],
        .notarizeSubmit:    ["en": "Submit for notarization", "de": "Zur Notarisierung einreichen"],
        .notarizeSubmitting:["en": "Submitting…", "de": "Reiche ein…"],

        // Metadata compare
        .mdEdit:    ["en": "Edit", "de": "Bearbeiten"],
        .mdCompare: ["en": "Compare", "de": "Vergleichen"],
        .mdLangA:   ["en": "Language A", "de": "Sprache A"],
        .mdLangB:   ["en": "Language B", "de": "Sprache B"],
        .mdMissingTranslation: ["en": "missing in one language", "de": "in einer Sprache fehlend"],

        // Settings about
        .secAbout:      ["en": "About", "de": "Über"],
        .aboutVersion:  ["en": "Version", "de": "Version"],
        .aboutCreator:  ["en": "Creator", "de": "Ersteller"],
        .aboutLicense:  ["en": "License", "de": "Lizenz"],

        // New app
        .appsNewApp:  ["en": "New App", "de": "Neue App"],
        .newAppTitle: ["en": "Create a new app", "de": "Neue App erstellen"],
        .newAppIntro: ["en": "New apps are created in App Store Connect on the web, not from the API. First register a bundle ID on the Apple Developer site, then create the app in App Store Connect.",
                       "de": "Neue Apps werden im Web in App Store Connect erstellt, nicht über die API. Registriere zuerst eine Bundle-ID auf der Apple-Developer-Website und erstelle die App dann in App Store Connect."],
        .newAppStep1: ["en": "Register a Bundle ID at developer.apple.com → Certificates, Identifiers & Profiles → Identifiers.",
                       "de": "Registriere eine Bundle-ID unter developer.apple.com → Zertifikate, IDs & Profile → Identifiers."],
        .newAppStep2: ["en": "In App Store Connect → Apps, click the + button → New App, and pick that bundle ID, a name, primary language and SKU.",
                       "de": "Klicke in App Store Connect → Apps auf „+“ → Neue App und wähle diese Bundle-ID, einen Namen, die Hauptsprache und eine SKU."],
        .newAppStep3: ["en": "Back here, hit Refresh — the new app appears in the list.",
                       "de": "Klicke hier auf „Aktualisieren“ — die neue App erscheint in der Liste."],
        .newAppOpenBundleIds: ["en": "Register Bundle ID", "de": "Bundle-ID registrieren"],
        .newAppOpenASC:       ["en": "Open App Store Connect", "de": "App Store Connect öffnen"],
        .newAppApiNote: ["en": "Tip: register the Bundle ID in the Signing → Bundle IDs section once it exists.",
                         "de": "Tipp: Die Bundle-ID erscheint nach dem Anlegen im Bereich Signierung → Bundle-IDs."],

        // New sidebar sections / items
        .grpAds:          ["en": "Apple Ads", "de": "Apple Ads"],
        .secAds:          ["en": "Campaigns", "de": "Kampagnen"],
        .secWorkflows:    ["en": "Workflows", "de": "Workflows"],
        .secDistribution: ["en": "Distribution", "de": "Vertrieb"],

        // Apple Ads
        .adsBody:    ["en": "Apple Ads (Search Ads) uses separate OAuth credentials from your App Store Connect key. Sign in below, then set your organization ID.",
                      "de": "Apple Ads (Search Ads) nutzt eigene OAuth-Zugangsdaten, getrennt vom App-Store-Connect-Schlüssel. Melde dich unten an und lege dann deine Organisations-ID fest."],
        .adsOrg:     ["en": "Organization ID", "de": "Organisations-ID"],
        .adsOrgHint: ["en": "Your Apple Ads org ID (numbers). Saved for reuse across tabs.",
                      "de": "Deine Apple-Ads-Organisations-ID (Zahlen). Wird für alle Tabs gespeichert."],
        .adsNeedOrg: ["en": "Enter your organization ID to query Apple Ads.",
                      "de": "Gib deine Organisations-ID ein, um Apple Ads abzufragen."],
        .adsTabAuth:      ["en": "Auth", "de": "Anmeldung"],
        .adsTabCampaigns: ["en": "Campaigns", "de": "Kampagnen"],
        .adsTabAdGroups:  ["en": "Ad Groups", "de": "Anzeigengruppen"],
        .adsTabKeywords:  ["en": "Keywords", "de": "Schlüsselwörter"],
        .adsTabReports:   ["en": "Reports", "de": "Berichte"],
        .adsAuthBody:     ["en": "Register Apple Ads API credentials. The private key is an EC (.pem) key from your Apple Ads account.",
                           "de": "Apple-Ads-API-Zugangsdaten registrieren. Der private Schlüssel ist ein EC-(.pem)-Schlüssel aus deinem Apple-Ads-Konto."],
        .adsAuthStatusBtn:["en": "Auth status", "de": "Anmeldestatus"],
        .adsDiscover:     ["en": "Discover access", "de": "Zugriff ermitteln"],
        .adsViewMe:       ["en": "Current user", "de": "Aktueller Benutzer"],
        .adsLoginBtn:     ["en": "Sign in to Apple Ads", "de": "Bei Apple Ads anmelden"],
        .adsLoggingIn:    ["en": "Signing in…", "de": "Melde an…"],
        .adsName:         ["en": "Profile name", "de": "Profilname"],
        .adsClientId:     ["en": "Client ID", "de": "Client-ID"],
        .adsTeamId:       ["en": "Team ID", "de": "Team-ID"],
        .adsKeyId:        ["en": "Key ID", "de": "Schlüssel-ID"],
        .adsPrivateKey:   ["en": "Private key (.pem)", "de": "Privater Schlüssel (.pem)"],
        .adsPrivateKeyHint:["en": "EC private key downloaded from your Apple Ads account.",
                            "de": "EC-Schlüssel, der aus deinem Apple-Ads-Konto geladen wurde."],
        .adsCampaign:     ["en": "Campaign ID", "de": "Kampagnen-ID"],
        .adsAdGroup:      ["en": "Ad group ID", "de": "Anzeigengruppen-ID"],
        .adsListCampaigns:["en": "List campaigns", "de": "Kampagnen anzeigen"],
        .adsListAdGroups: ["en": "List ad groups", "de": "Anzeigengruppen anzeigen"],
        .adsListKeywords: ["en": "List targeting keywords", "de": "Targeting-Schlüsselwörter anzeigen"],
        .adsReportsBody:  ["en": "Run a campaign-level report from an Apple Ads JSON payload file.",
                           "de": "Einen Kampagnenbericht aus einer Apple-Ads-JSON-Datei ausführen."],
        .adsPayloadFile:  ["en": "Report payload (.json)", "de": "Bericht-Datei (.json)"],
        .adsRunReport:    ["en": "Run campaign report", "de": "Kampagnenbericht ausführen"],
        .adsNeedCampaign: ["en": "Enter a campaign ID.", "de": "Gib eine Kampagnen-ID ein."],
        .adsNeedAdGroup:  ["en": "Enter a campaign ID and an ad group ID.", "de": "Gib eine Kampagnen- und Anzeigengruppen-ID ein."],

        // Workflows
        .wfBody:         ["en": "Run repeatable, multi-step automations defined in a repo-local workflow file. Great for local runs and CI/CD.",
                          "de": "Wiederholbare, mehrstufige Automatisierungen aus einer Workflow-Datei im Repo ausführen. Ideal für lokale Läufe und CI/CD."],
        .wfSecurityNote: ["en": "Workflows execute arbitrary shell commands. Only run files you trust.",
                          "de": "Workflows führen beliebige Shell-Befehle aus. Führe nur vertrauenswürdige Dateien aus."],
        .wfFile:         ["en": "Workflow file", "de": "Workflow-Datei"],
        .wfList:         ["en": "List", "de": "Auflisten"],
        .wfValidate:     ["en": "Validate", "de": "Prüfen"],
        .wfName:         ["en": "Workflow name", "de": "Workflow-Name"],
        .wfParams:       ["en": "Parameters", "de": "Parameter"],
        .wfParamsHint:   ["en": "Space-separated KEY:VALUE pairs, e.g. VERSION:2.1.0 GROUP_ID:abc",
                          "de": "Durch Leerzeichen getrennte KEY:VALUE-Paare, z. B. VERSION:2.1.0 GROUP_ID:abc"],
        .wfDryRun:       ["en": "Dry run (preview steps only)", "de": "Probelauf (nur Vorschau)"],
        .wfResume:       ["en": "Resume run ID (optional)", "de": "Lauf-ID fortsetzen (optional)"],
        .wfResumeHint:   ["en": "Resume a prior run; saved params are reused.", "de": "Vorherigen Lauf fortsetzen; gespeicherte Parameter werden wiederverwendet."],
        .wfRun:          ["en": "Run workflow", "de": "Workflow ausführen"],
        .wfRunNow:       ["en": "Run", "de": "Ausführen"],
        .wfRunConfirmTitle: ["en": "Run this workflow?", "de": "Diesen Workflow ausführen?"],
        .wfRunConfirmMsg:   ["en": "Workflows run arbitrary shell commands defined in the file. Only continue if you trust this workflow file.",
                             "de": "Workflows führen beliebige in der Datei definierte Shell-Befehle aus. Fahre nur fort, wenn du dieser Datei vertraust."],
        .wfRunning:      ["en": "Running…", "de": "Läuft…"],

        // Distribution
        .distBody:        ["en": "Manage alternative distribution (marketplaces, domains, keys, packages) for supported regions.",
                           "de": "Alternativen Vertrieb (Marktplätze, Domains, Schlüssel, Pakete) für unterstützte Regionen verwalten."],
        .distAltDist:     ["en": "Alternative Distribution", "de": "Alternativer Vertrieb"],
        .distMarketplace: ["en": "Marketplace", "de": "Marktplatz"],
        .distDomains:     ["en": "List domains", "de": "Domains anzeigen"],
        .distKeys:        ["en": "List keys", "de": "Schlüssel anzeigen"],
        .distAppKey:      ["en": "App's distribution key", "de": "Vertriebsschlüssel der App"],
        .distPackageId:   ["en": "Package ID", "de": "Paket-ID"],
        .distViewPackage: ["en": "View package", "de": "Paket anzeigen"],
        .distWebhooks:    ["en": "List marketplace webhooks", "de": "Marktplatz-Webhooks anzeigen"],
        .distSearchDetails:["en": "App search details", "de": "App-Suchdetails"],
        .distAppNote:     ["en": "App-specific actions use the app selected in the toolbar.",
                           "de": "App-spezifische Aktionen verwenden die in der Symbolleiste gewählte App."],

        // TestFlight crashes
        .tfCrashes:        ["en": "Crashes", "de": "Abstürze"],
        .tfLoadFeedback:   ["en": "Load feedback", "de": "Feedback laden"],
        .tfLoadCrashes:    ["en": "Load crashes", "de": "Abstürze laden"],
        .tfSubmissionId:   ["en": "Submission ID", "de": "Einreichungs-ID"],
        .tfCrashLog:       ["en": "Fetch crash log", "de": "Absturzprotokoll abrufen"],
        .tfIncludeScreens: ["en": "Include screenshot URLs", "de": "Screenshot-URLs einschließen"],

        // Help: skills & CI
        .helpSkillsTitle:   ["en": "Agent skills & automation", "de": "Agent-Skills & Automatisierung"],
        .helpSkillsBody:    ["en": "Install the asc skill pack so AI agents (and editors) know how to drive App Store Connect workflows.",
                             "de": "Installiere das asc-Skill-Paket, damit KI-Agenten (und Editoren) App-Store-Connect-Workflows steuern können."],
        .helpInstallSkills: ["en": "Install asc skills", "de": "asc-Skills installieren"],
        .helpInstalling:    ["en": "Installing…", "de": "Installiere…"],
        .helpSkillsNpx:     ["en": "Or install directly:", "de": "Oder direkt installieren:"],
        .helpCITitle:       ["en": "CI integrations", "de": "CI-Integrationen"],
        .helpCIBody:        ["en": "Use the official setup action and CI components with secure ASC_* credentials in GitHub Actions, GitLab, Bitrise and CircleCI.",
                             "de": "Nutze die offizielle Setup-Action und CI-Komponenten mit sicheren ASC_*-Zugangsdaten in GitHub Actions, GitLab, Bitrise und CircleCI."],
        .helpOpenSetupAsc:  ["en": "Open setup-asc on GitHub", "de": "setup-asc auf GitHub öffnen"],

        // New groups / section titles
        .grpMonetization:  ["en": "Monetization", "de": "Monetarisierung"],
        .secPricing:       ["en": "Pricing", "de": "Preise"],
        .secReviews:       ["en": "Reviews", "de": "Bewertungen"],
        .secSubscriptions: ["en": "Subscriptions", "de": "Abos"],
        .secIAP:           ["en": "In-App Purchases", "de": "In-App-Käufe"],
        .secAppEvents:     ["en": "In-App Events", "de": "In-App-Events"],
        .secSubmission:    ["en": "Submission", "de": "Einreichung"],
        .secCompliance:    ["en": "Compliance", "de": "Konformität"],
        .secTeam:          ["en": "Team & Devices", "de": "Team & Geräte"],
        .secTools:         ["en": "Tools", "de": "Werkzeuge"],

        // Generic action verbs
        .actList:        ["en": "List", "de": "Auflisten"],
        .actView:        ["en": "View by ID", "de": "Nach ID anzeigen"],
        .actSummary:     ["en": "Pricing summary", "de": "Preisübersicht"],
        .actStatus:      ["en": "Status", "de": "Status"],
        .actCreate:      ["en": "Create", "de": "Erstellen"],
        .actSet:         ["en": "Set", "de": "Festlegen"],
        .actRegister:    ["en": "Register", "de": "Registrieren"],
        .actRespond:     ["en": "Respond", "de": "Antworten"],
        .actGenerate:    ["en": "Generate", "de": "Generieren"],
        .actPing:        ["en": "Ping", "de": "Ping"],
        .actDoctor:      ["en": "Run diagnostics", "de": "Diagnose ausführen"],
        .actDeliveries:  ["en": "Deliveries", "de": "Zustellungen"],
        .actInvite:      ["en": "Invite", "de": "Einladen"],

        // Pricing
        .prBody:         ["en": "Inspect the current price, territories, price points, schedule and availability for the selected app.",
                          "de": "Aktuellen Preis, Territorien, Preispunkte, Zeitplan und Verfügbarkeit der gewählten App ansehen."],
        .prCurrent:      ["en": "Current price", "de": "Aktueller Preis"],
        .prTerritories:  ["en": "Territories", "de": "Territorien"],
        .prPricePoints:  ["en": "Price points", "de": "Preispunkte"],
        .prSchedule:     ["en": "Schedule", "de": "Zeitplan"],
        .prAvailability: ["en": "Availability", "de": "Verfügbarkeit"],

        // Reviews
        .rvBody:           ["en": "Read customer reviews and ratings, and respond to feedback.",
                            "de": "Kundenbewertungen und Wertungen lesen und auf Feedback antworten."],
        .rvReviews:        ["en": "Reviews", "de": "Bewertungen"],
        .rvRatings:        ["en": "Ratings", "de": "Wertungen"],
        .rvRespond:        ["en": "Respond", "de": "Antworten"],
        .rvStars:          ["en": "Stars", "de": "Sterne"],
        .rvStarsAll:       ["en": "All", "de": "Alle"],
        .rvTerritory:      ["en": "Territory", "de": "Territorium"],
        .rvOnlyUnresponded:["en": "Only unresponded", "de": "Nur unbeantwortete"],
        .rvReviewId:       ["en": "Review ID", "de": "Bewertungs-ID"],
        .rvResponseText:   ["en": "Response text", "de": "Antworttext"],

        // Subscriptions
        .subBody:    ["en": "Manage subscription groups and subscriptions. List subscriptions by group ID.",
                      "de": "Abo-Gruppen und Abos verwalten. Abos nach Gruppen-ID auflisten."],
        .subGroups:  ["en": "Groups", "de": "Gruppen"],
        .subSubs:    ["en": "Subscriptions", "de": "Abos"],
        .subPricing: ["en": "Pricing", "de": "Preise"],
        .subGroupId: ["en": "Subscription group ID", "de": "Abo-Gruppen-ID"],

        // IAP
        .iapBody:     ["en": "List in-app purchases and inspect their pricing for the selected app.",
                       "de": "In-App-Käufe auflisten und deren Preise für die gewählte App ansehen."],
        .iapProducts: ["en": "Products", "de": "Produkte"],
        .iapPricing:  ["en": "Pricing", "de": "Preise"],
        .iapId:       ["en": "In-app purchase ID", "de": "In-App-Kauf-ID"],

        // App events
        .aeBody:     ["en": "List App Store in-app events and inspect them by ID.",
                      "de": "App-Store-In-App-Events auflisten und nach ID ansehen."],
        .aeEvents:   ["en": "Events", "de": "Events"],
        .aeEventId:  ["en": "Event ID", "de": "Event-ID"],

        // Submission lifecycle
        .smBody:            ["en": "Drive the App Review lifecycle: status, review details, submissions and release notes.",
                             "de": "Den App-Review-Ablauf steuern: Status, Review-Details, Einreichungen und Release-Notes."],
        .smTabStatus:       ["en": "Status", "de": "Status"],
        .smTabDetails:      ["en": "Review details", "de": "Review-Details"],
        .smTabSubmissions:  ["en": "Submissions", "de": "Einreichungen"],
        .smTabNotes:        ["en": "Release notes", "de": "Release-Notes"],
        .smVersionId:       ["en": "Version ID", "de": "Versions-ID"],
        .smBuildId:         ["en": "Build ID", "de": "Build-ID"],
        .smDetailId:        ["en": "Review detail ID", "de": "Review-Detail-ID"],
        .smSubmissionId:    ["en": "Submission ID", "de": "Einreichungs-ID"],
        .smPlatform:        ["en": "Platform", "de": "Plattform"],
        .smReviewStatus:    ["en": "Review status", "de": "Review-Status"],
        .smReviewDoctor:    ["en": "Why can't I submit?", "de": "Warum nicht einreichbar?"],
        .smDetailsForVersion:["en": "Details for version", "de": "Details zur Version"],
        .smAttachments:     ["en": "List attachments", "de": "Anhänge auflisten"],
        .smSubmissionsList: ["en": "List submissions", "de": "Einreichungen auflisten"],
        .smSubmissionsCreate:["en": "Create submission", "de": "Einreichung erstellen"],
        .smSubmit:          ["en": "Submit for review", "de": "Zur Prüfung einreichen"],
        .smSubmitStatus:    ["en": "Submission status", "de": "Einreichungsstatus"],
        .smSubmitCancel:    ["en": "Cancel submission", "de": "Einreichung abbrechen"],
        .smBuildNotes:      ["en": "Build release notes", "de": "Build-Release-Notes"],
        .smGenerateNotes:   ["en": "Generate from git", "de": "Aus Git generieren"],
        .smSinceTag:        ["en": "Since tag", "de": "Seit Tag"],

        // Compliance
        .cmBody:        ["en": "App Store configuration that gates submission: age rating, export compliance, categories, EULA and tags.",
                         "de": "App-Store-Konfiguration für die Einreichung: Altersfreigabe, Exportkonformität, Kategorien, EULA und Tags."],
        .cmAgeRating:   ["en": "Age rating", "de": "Altersfreigabe"],
        .cmEncryption:  ["en": "Encryption", "de": "Verschlüsselung"],
        .cmCategories:  ["en": "Categories", "de": "Kategorien"],
        .cmEula:        ["en": "EULA", "de": "EULA"],
        .cmAppTags:     ["en": "App tags", "de": "App-Tags"],
        .cmCatSet:      ["en": "Set categories", "de": "Kategorien festlegen"],
        .cmPrimary:     ["en": "Primary (e.g. GAMES)", "de": "Primär (z. B. GAMES)"],
        .cmSecondary:   ["en": "Secondary (optional)", "de": "Sekundär (optional)"],

        // Team
        .tmBody:       ["en": "Manage team members, registered devices and sandbox testers.",
                        "de": "Teammitglieder, registrierte Geräte und Sandbox-Tester verwalten."],
        .tmUsers:      ["en": "Users", "de": "Benutzer"],
        .tmDevices:    ["en": "Devices", "de": "Geräte"],
        .tmSandbox:    ["en": "Sandbox testers", "de": "Sandbox-Tester"],
        .tmInvite:     ["en": "Invite user", "de": "Benutzer einladen"],
        .tmEmail:      ["en": "Email", "de": "E-Mail"],
        .tmRoles:      ["en": "Roles (e.g. ADMIN)", "de": "Rollen (z. B. ADMIN)"],
        .tmAllApps:    ["en": "Access to all apps", "de": "Zugriff auf alle Apps"],
        .tmDeviceName: ["en": "Device name", "de": "Gerätename"],
        .tmUdid:       ["en": "UDID", "de": "UDID"],
        .tmLocalUdid:  ["en": "Get this Mac's UDID", "de": "UDID dieses Macs abrufen"],

        // Tools
        .tlBody:          ["en": "Account health, authentication diagnostics, webhooks and Fastlane migration.",
                           "de": "Account-Status, Authentifizierungs-Diagnose, Webhooks und Fastlane-Migration."],
        .tlAccount:       ["en": "Account & auth", "de": "Account & Anmeldung"],
        .tlWebhooks:      ["en": "Webhooks", "de": "Webhooks"],
        .tlFastlane:      ["en": "Fastlane", "de": "Fastlane"],
        .tlWebhookId:     ["en": "Webhook ID", "de": "Webhook-ID"],
        .tlMigrateImport: ["en": "Import from fastlane", "de": "Aus Fastlane importieren"],
        .tlMigrateExport: ["en": "Export to fastlane", "de": "Nach Fastlane exportieren"],
        .tlFastlaneDir:   ["en": "fastlane directory", "de": "Fastlane-Verzeichnis"],
        .tlVersionId:     ["en": "Version ID", "de": "Versions-ID"],

        // Analytics dashboard
        .secAnalytics:   ["en": "Analytics", "de": "Analyse"],
        .anTitle:        ["en": "Analytics", "de": "Analyse"],
        .anWeek:         ["en": "Week", "de": "Woche"],
        .anLoad:         ["en": "Load analytics", "de": "Analyse laden"],
        .anNeedVendorSales: ["en": "Set a vendor number in Reports to load revenue & subscription metrics.",
                             "de": "Hinterlege eine Anbieternummer unter „Berichte“, um Umsatz- und Abo-Kennzahlen zu laden."],
        .anInsufficient: ["en": "Not enough data", "de": "Daten nicht ausreichend"],
        .anWeekRangeFmt: ["en": "Week of %@ vs previous week", "de": "Woche ab %@ vs Vorwoche"],
        .anRaw:          ["en": "Raw data", "de": "Rohdaten"],
        .anWeekVsPrev:   ["en": "this week vs last week", "de": "diese Woche vs Vorwoche"],
        .an30dVsPrev:    ["en": "last 30 days vs previous 30 days", "de": "letzte 30 Tage vs vorherige 30 Tage"],
        .anAcquisition:  ["en": "Acquisition", "de": "Akquise"],
        .anRevenue:      ["en": "Revenue", "de": "Umsatz"],
        .anSubscriptions:["en": "Subscriptions", "de": "Abonnements"],
        .anUsage:        ["en": "App usage", "de": "App-Nutzung"],
        .anFirstDownloads:["en": "First-time downloads", "de": "Erstmalige Downloads"],
        .anRedownloads:  ["en": "Redownloads", "de": "Erneute Downloads"],
        .anConversion:   ["en": "Conversion rate", "de": "Konversionsrate"],
        .anImpressions:  ["en": "Impressions", "de": "Impressionen"],
        .anPageViews:    ["en": "Product page views", "de": "Produktseitenaufrufe"],
        .anUpdates:      ["en": "Updates", "de": "Aktualisierungen"],
        .anReturns:       ["en": "Returns", "de": "Rückgaben"],
        .anProceeds:     ["en": "Proceeds", "de": "Erlöse"],
        .anPayingUsers:  ["en": "Paying users", "de": "Zahlende Benutzer:innen"],
        .anIap:          ["en": "In-app purchases", "de": "In-App-Käufe"],
        .anActiveSubs:   ["en": "Active subscriptions", "de": "Aktive Abos"],
        .anPaidSubs:     ["en": "Paid subscriptions", "de": "Kostenpflichtige Abos"],
        .anMrr:          ["en": "Monthly recurring revenue", "de": "Monatlich wiederkehrende Einnahmen"],
        .anRetention:    ["en": "Average retention", "de": "Durchschnittliche Retention"],
        .anCrashes:      ["en": "Crashes", "de": "Abstürze"],
        .anChartAcq:     ["en": "Acquisition overview", "de": "Akquise-Überblick"],
        .anChartRev:     ["en": "Revenue overview", "de": "Umsatz-Überblick"],
        .anNoChartData:  ["en": "No chart data available", "de": "Keine Diagrammdaten verfügbar"],
        .an30dRevenue:   ["en": "30-day revenue (vs previous 30 days)", "de": "30-Tage-Umsatz (vs vorherige 30 Tage)"],
        .ovChooseApp:    ["en": "Current app", "de": "Aktuelle App"],
        .ovSwitchApp:    ["en": "Switch app", "de": "App wechseln"],
        .ovSwitchAppHelp: ["en": "Choose a different app in the Apps tab.",
                           "de": "Im Reiter „Apps“ eine andere App auswählen."],
        .secPrefetch:    ["en": "Preload data", "de": "Daten vorab laden"],
        .prefetchEnable: ["en": "Preload tabs when switching app", "de": "Reiter beim App-Wechsel vorab laden"],
        .prefetchEnableDesc: ["en": "When you pick an app, its data is fetched in the background so the tabs open instantly.",
                              "de": "Beim Auswählen einer App werden die Daten im Hintergrund geladen, damit die Reiter sofort öffnen."],
        .prefetchSectionsLabel: ["en": "Sections to preload", "de": "Abschnitte zum Vorladen"],
        .prefetchNote:   ["en": "More sections mean a longer initial load but faster navigation.",
                          "de": "Mehr Abschnitte bedeuten längeres Erstladen, aber schnelleres Navigieren."],

        // Marketing
        .secMarketing:   ["en": "Marketing", "de": "Marketing"],
        .mkBody:         ["en": "Custom product pages, page optimization experiments, pre-orders and featuring nominations.",
                          "de": "Custom Product Pages, Produktseiten-Experimente, Vorbestellungen und Featuring-Nominierungen."],
        .mkProductPages: ["en": "Product pages", "de": "Produktseiten"],
        .mkPreOrders:    ["en": "Pre-orders", "de": "Vorbestellungen"],
        .mkNominations:  ["en": "Nominations", "de": "Nominierungen"],
        .mkCustomPages:  ["en": "Custom pages", "de": "Custom Pages"],
        .mkExperiments:  ["en": "Experiments", "de": "Experimente"],
        .mkPageName:     ["en": "Page name", "de": "Seitenname"],
        .mkPageId:       ["en": "Custom page ID", "de": "Custom-Page-ID"],
        .mkTerritories:  ["en": "Territories (e.g. US,DE)", "de": "Länder (z. B. US,DE)"],
        .mkReleaseDate:  ["en": "Release date (YYYY-MM-DD)", "de": "Erscheinungsdatum (JJJJ-MM-TT)"],
        .mkTaId:         ["en": "Territory availability ID", "de": "Territory-Availability-ID"],
        .mkAppNote:      ["en": "Select an app in the toolbar to use app-scoped actions.",
                          "de": "Wähle oben eine App, um app-bezogene Aktionen zu nutzen."],
        .mkStatus:       ["en": "Status (e.g. DRAFT)", "de": "Status (z. B. DRAFT)"],
        .mkNomId:        ["en": "Nomination ID", "de": "Nominierungs-ID"],
        .mkNomName:      ["en": "Name", "de": "Name"],
        .mkNomType:      ["en": "Type (e.g. APP_LAUNCH)", "de": "Typ (z. B. APP_LAUNCH)"],
        .mkNomDesc:      ["en": "Description", "de": "Beschreibung"],
        .mkSubmitted:    ["en": "Submit immediately", "de": "Sofort einreichen"],
        .mkConfirmTitle: ["en": "Confirm action", "de": "Aktion bestätigen"],
        .mkConfirmMsg:   ["en": "This changes data in App Store Connect. Continue?",
                          "de": "Dies ändert Daten in App Store Connect. Fortfahren?"],
        .actDelete:      ["en": "Delete", "de": "Löschen"],
        .actEnable:      ["en": "Enable", "de": "Aktivieren"],
        .actDisable:     ["en": "Disable", "de": "Deaktivieren"],
        .outFormatted:   ["en": "Formatted", "de": "Formatiert"],
        .outRaw:         ["en": "Raw", "de": "Roh"],
        .outCountFmt:    ["en": "%d entries", "de": "%d Einträge"],
        .anAllMetrics:   ["en": "All metrics (raw)", "de": "Alle Kennzahlen (roh)"],
        .anStatusUnavailable: ["en": "unavailable", "de": "nicht verfügbar"],
        .anNeedRequest:  ["en": "App Analytics reports haven't been generated for this app yet. Request ongoing reports once — Apple then prepares them over roughly the next 1–2 days, after which metrics appear here.",
                          "de": "Für diese App wurden noch keine App-Analytics-Berichte erzeugt. Fordere die laufenden Berichte einmalig an — Apple bereitet sie dann über etwa 1–2 Tage auf, danach erscheinen die Kennzahlen hier."],
        .anReportTitle:  ["en": "App Store Analytics (API reports)", "de": "App-Store-Analytics (API-Berichte)"],
        .anReportBody:   ["en": "Downloads and parses Apple's official analytics report files (impressions, page views, downloads). Requires an API key with Admin/Account Holder role; after the first request Apple prepares the data over ~1–2 days.",
                          "de": "Lädt und parst Apples offizielle Analytics-Berichtsdateien (Impressionen, Seitenaufrufe, Downloads). Benötigt einen API-Key mit Rolle Admin/Account Holder; nach der ersten Anfrage bereitet Apple die Daten über ~1–2 Tage auf."],
        .anReportLoad:   ["en": "Load report data", "de": "Berichtsdaten laden"],
        .anReportCreate: ["en": "Create report requests (snapshot + ongoing)", "de": "Report-Anfragen erstellen (Snapshot + laufend)"],
        .anReportProcessing: ["en": "Reports were requested but Apple hasn't generated any instances yet. Check back in about a day.",
                              "de": "Berichte wurden angefordert, aber Apple hat noch keine Instanzen erzeugt. Schau in etwa einem Tag wieder vorbei."],
        .anReportForbidden: ["en": "This API key isn't allowed to create or read analytics report requests. Use a key with Admin or Account Holder role and App Analytics access.",
                             "de": "Dieser API-Key darf keine Analytics-Report-Anfragen erstellen oder lesen. Verwende einen Key mit Rolle Admin oder Account Holder und App-Analytics-Zugriff."],
        .anReportCreated: ["en": "Requested. Apple prepares the reports over roughly the next 1–2 days.",
                           "de": "Angefordert. Apple bereitet die Berichte über etwa 1–2 Tage auf."],
        .anReportLoadedFmt: ["en": "Loaded %d rows from report \"%@\".", "de": "%d Zeilen aus Bericht „%@“ geladen."],
        .anReportWeekFallbackFmt: ["en": "No instances for the selected week yet — showing the newest available report (%@).",
                                   "de": "Für die gewählte Woche gibt es noch keine Instanzen — angezeigt wird der neueste verfügbare Bericht (%@)."],
        .anAnalyticsRestricted: ["en": "This API key can't read App Analytics reports, so acquisition metrics (impressions, page views, conversion) are unavailable — this is an Apple API restriction, not a bug. Downloads, revenue and subscriptions come from the Sales reports: set a vendor number under Reports. For analytics access, use a key with Admin/Account Holder role and enabled App Analytics reporting.",
                                 "de": "Dieser API-Key darf keine App-Analytics-Berichte lesen, daher sind Akquise-Kennzahlen (Impressionen, Seitenaufrufe, Konversion) nicht verfügbar — das ist eine Apple-API-Beschränkung, kein Fehler. Downloads, Umsatz und Abos stammen aus den Sales-Berichten: hinterlege dazu eine Anbieternummer unter „Berichte“. Für Analytics-Zugriff brauchst du einen Key mit Rolle Admin/Account Holder und aktivierter App-Analytics-Berichterstattung."],
        .anAdminRequiredTitle: ["en": "Admin API key required for analytics",
                                "de": "Admin-API-Key für Analyse erforderlich"],
        .anAdminRequiredBody: ["en": "Creating and reading App Analytics report requests requires an API key with the Admin or Account Holder role. Add such a key under Settings → Profiles and assign it to the Analytics role — day-to-day operations can keep using your regular key.",
                               "de": "Das Erstellen und Lesen von App-Analytics-Berichtsanfragen erfordert einen API-Key mit der Rolle Admin oder Account Holder. Lege einen solchen Key unter Einstellungen → Profile an und ordne ihn der Rolle „Analyse“ zu — der Alltagsbetrieb kann weiter deinen normalen Key nutzen."],
        .anAnalyticsUsingProfileFmt: ["en": "Analytics currently uses profile: %@",
                                      "de": "Analyse nutzt aktuell Profil: %@"],
        .anOpenProfileSettings: ["en": "Open profile settings", "de": "Profileinstellungen öffnen"],

        // Local metrics store
        .msTitle:           ["en": "Sales history", "de": "Verkaufshistorie"],
        .msBody:            ["en": "Trends from imported Apple Sales Summary reports stored on disk.",
                             "de": "Trends aus importierten Apple-Verkaufsübersichten auf der Festplatte."],
        .msScanFolder:      ["en": "Scan reports folder", "de": "Berichtsordner scannen"],
        .msImportCountFmt:  ["en": "%d records · %d files imported", "de": "%d Datensätze · %d Dateien importiert"],
        .msNoData:          ["en": "Import daily sales reports from Reports to see trends here.",
                             "de": "Importiere tägliche Verkaufsberichte unter „Berichte“, um hier Trends zu sehen."],
        .msDownloads7d:     ["en": "Downloads (7d)", "de": "Downloads (7 T.)"],
        .msProceeds7d:      ["en": "Proceeds (7d)", "de": "Erlöse (7 T.)"],
        .msSubscriptions30d:["en": "Subscription events (30d)", "de": "Abo-Ereignisse (30 T.)"],
        .msNextPayout:      ["en": "Next payout", "de": "Nächste Auszahlung"],
        .msTrendTitle:      ["en": "14-day trend", "de": "14-Tage-Trend"],
        .msFromReports:     ["en": "From local sales reports", "de": "Aus lokalen Verkaufsberichten"],
        .msPortfolioTitle:  ["en": "Portfolio (7 days)", "de": "Portfolio (7 Tage)"],
        .ovMetricsTitle:    ["en": "Performance", "de": "Performance"],
        .ovFiscalTitle:     ["en": "Apple fiscal calendar", "de": "Apple-Geschäftskalender"],
        .ovFiscalPeriodFmt: ["en": "FY%d · Period %d", "de": "GJ%d · Periode %d"],
        .ovFiscalPaymentFmt:["en": "Payment on %@", "de": "Auszahlung am %@"],

        // Remote sync (CloudKit mirror)
        .secRemoteSync:  ["en": "Remote sync", "de": "Remote-Synchronisierung"],
        .syncEnable:     ["en": "Mirror to iCloud", "de": "In iCloud spiegeln"],
        .syncEnableDesc: ["en": "Periodically capture the selected app's data and upload it to your private iCloud database for a future companion iPhone app. Off by default.",
                          "de": "Erfasst regelmäßig die Daten der gewählten App und lädt sie in deine private iCloud-Datenbank für eine künftige iPhone-Begleit-App. Standardmäßig aus."],
        .syncIntervalLabel: ["en": "Interval", "de": "Intervall"],
        .syncSectionsLabel: ["en": "Sections to mirror", "de": "Zu spiegelnde Bereiche"],
        .syncNow:        ["en": "Sync now", "de": "Jetzt synchronisieren"],
        .syncNowRunning: ["en": "Syncing…", "de": "Synchronisiere…"],
        .syncNote:       ["en": "Mirroring uses your private CloudKit database (container iCloud.PySaasNow.ASC-CLI-UI). It never changes App Store Connect data.",
                          "de": "Die Spiegelung nutzt deine private CloudKit-Datenbank (Container iCloud.PySaasNow.ASC-CLI-UI). App-Store-Connect-Daten werden nie verändert."],
        .syncStatusLabel: ["en": "Last sync", "de": "Letzte Synchronisierung"],
        .syncNever:      ["en": "Never", "de": "Nie"],
        .syncLastSyncedFmt: ["en": "Last synced: %@", "de": "Zuletzt synchronisiert: %@"],
        .syncFailedFmt:  ["en": "Sync failed: %@", "de": "Synchronisierung fehlgeschlagen: %@"],
        .syncNeedApp:    ["en": "Select an app in the toolbar to mirror its data.",
                          "de": "Wähle oben eine App, um ihre Daten zu spiegeln."],
        .syncEvery15m:   ["en": "Every 15 minutes", "de": "Alle 15 Minuten"],
        .syncHourly:     ["en": "Hourly", "de": "Stündlich"],
        .syncEvery6h:    ["en": "Every 6 hours", "de": "Alle 6 Stunden"],
        .syncDaily:      ["en": "Daily", "de": "Täglich"],

        // iOS remote consumer (Phase 3b mirror reader)
        .rmAppsTitle:    ["en": "Mirrored Apps", "de": "Gespiegelte Apps"],
        .rmEmptyTitle:   ["en": "No mirrored data yet", "de": "Noch keine gespiegelten Daten"],
        .rmEmptyMessage: ["en": "Enable Remote sync on the Mac and provision CloudKit to see your apps here.",
                          "de": "Aktiviere die Remote-Synchronisierung auf dem Mac und richte CloudKit ein, um deine Apps hier zu sehen."],
        .rmLoadError:    ["en": "Couldn’t load from iCloud", "de": "Laden aus iCloud fehlgeschlagen"],
        .rmUpdatedFmt:   ["en": "Updated %@", "de": "Aktualisiert %@"],
        .rmAppFmt:       ["en": "App %@", "de": "App %@"],
        .rmSectionsTitle:["en": "Sections", "de": "Bereiche"],
        .rmOfflineBadge: ["en": "Offline — showing last known data",
                          "de": "Offline — zeige zuletzt bekannte Daten"],
        .rmSignInTitle:  ["en": "Sign in to iCloud", "de": "Bei iCloud anmelden"],
        .rmSignInMessage:["en": "Sign in to iCloud in Settings to read your mirrored App Store Connect data.",
                          "de": "Melde dich in den Einstellungen bei iCloud an, um deine gespiegelten App-Store-Connect-Daten zu lesen."],
        .rmDataSection:  ["en": "Data", "de": "Daten"],
        .rmMirroredCountFmt: ["en": "%d mirrored apps", "de": "%d gespiegelte Apps"],
        .rmLastSync:     ["en": "Last update", "de": "Letzte Aktualisierung"],
        .rmNever:        ["en": "Never", "de": "Nie"],
        .rmCompatMacApp: ["en": "Compatible Mac app", "de": "Kompatible Mac-App"],
        .rmSourceCode:   ["en": "Source code", "de": "Quellcode"],
        .rmImpressum:    ["en": "Legal notice", "de": "Impressum"],
        .rmImpressumBody:["en": "ASC Remote is a private, non-commercial companion to ASC Manager. It is not affiliated with or endorsed by Apple. It only reads data you mirror from your own Mac via your private iCloud database and never accesses App Store Connect directly.",
                          "de": "ASC Remote ist eine private, nicht-kommerzielle Begleit-App zu ASC Manager. Sie steht in keiner Verbindung zu Apple und wird nicht von Apple unterstützt. Sie liest ausschließlich Daten, die du von deinem eigenen Mac über deine private iCloud-Datenbank spiegelst, und greift nie direkt auf App Store Connect zu."],
        .rmAppInfoNote:  ["en": "Read-only mirror. No App Store Connect credentials are stored on this device.",
                          "de": "Schreibgeschützte Spiegelung. Auf diesem Gerät werden keine App-Store-Connect-Zugangsdaten gespeichert."],

        // Market (Milestone 2)
        .grpMarket:       ["en": "Market", "de": "Markt"],
        .secMarketCharts: ["en": "Top Charts", "de": "Top-Charts"],
        .secMarketSearch: ["en": "App Search", "de": "App-Suche"],
        .secMarketSDKs:   ["en": "SDK Radar", "de": "SDK-Radar"],
        .mktChartsBody:   ["en": "Public App Store charts from Apple Marketing Tools. No revenue estimates for third-party apps.",
                           "de": "Öffentliche App-Store-Charts von Apple Marketing Tools. Keine Umsatzschätzungen für fremde Apps."],
        .mktSearchBody:   ["en": "Search the public App Store via the iTunes Lookup API — metadata, ratings, and screenshots.",
                           "de": "Durchsuche den öffentlichen App Store über die iTunes-Lookup-API — Metadaten, Bewertungen und Screenshots."],
        .mktSDKsBody:     ["en": "Lightweight overview of well-known SDKs matched against current chart apps. Not Appfigures-level intelligence.",
                           "de": "Leichter Überblick über bekannte SDKs, abgeglichen mit aktuellen Chart-Apps. Kein Appfigures-Niveau."],
        .mktCountry:      ["en": "Country", "de": "Land"],
        .mktRefresh:      ["en": "Refresh", "de": "Aktualisieren"],
        .mktLoading:      ["en": "Loading…", "de": "Lade…"],
        .mktError:         ["en": "Could not load market data.", "de": "Marktdaten konnten nicht geladen werden."],
        .mktChartFree:     ["en": "Top Free", "de": "Top Kostenlos"],
        .mktChartPaid:     ["en": "Top Paid", "de": "Top Bezahlt"],
        .mktChartGrossing: ["en": "Top Grossing", "de": "Top Umsatz"],
        .mktChartApps:     ["en": "Apps", "de": "Apps"],
        .mktChartGames:    ["en": "Games", "de": "Spiele"],
        .mktBookmark:      ["en": "Bookmark", "de": "Lesezeichen"],
        .mktBookmarked:    ["en": "Bookmarked", "de": "Gespeichert"],
        .mktRankFmt:       ["en": "#%d", "de": "#%d"],
        .mktSearchPlaceholder: ["en": "App name or bundle ID", "de": "App-Name oder Bundle-ID"],
        .mktNoResults:     ["en": "No apps found", "de": "Keine Apps gefunden"],
        .mktScreenshots:   ["en": "Screenshots", "de": "Screenshots"],
        .mktDescription:   ["en": "Description", "de": "Beschreibung"],
        .mktRatingFmt:     ["en": "%.1f ★ (%d)", "de": "%.1f ★ (%d)"],
        .mktMarketIndexTitle: ["en": "Market momentum", "de": "Marktimpuls"],
        .mktMarketIndexUp:   ["en": "Market ↑", "de": "Markt ↑"],
        .mktMarketIndexDown: ["en": "Market ↓", "de": "Markt ↓"],
        .mktMarketIndexFlat: ["en": "Market →", "de": "Markt →"],
        .mktMarketIndexFmt:  ["en": "%@ vs. last snapshot (%d up, %d down, %d new)",
                              "de": "%@ vs. letzter Snapshot (%d ↑, %d ↓, %d neu)"],
        .mktRankDeltaFmt:    ["en": "Rank %+d", "de": "Rang %+d"],
        .mktSDKDisclaimer:   ["en": "Keyword heuristics only — not a full SDK intelligence scan.",
                              "de": "Nur Stichwort-Heuristik — kein vollständiger SDK-Scan."],
        .mktSDKMatches:      ["en": "Chart matches", "de": "Chart-Treffer"],
        .mktCompareOwnApps:  ["en": "Your apps in chart", "de": "Deine Apps im Chart"],
        .mktNotInChart:      ["en": "Not in current top 25", "de": "Nicht in den Top 25"],
        .mktOpenStore:       ["en": "Open in App Store", "de": "Im App Store öffnen"],

        .exportCSV:          ["en": "Export CSV", "de": "CSV exportieren"],
        .exportJSON:         ["en": "Export JSON", "de": "JSON exportieren"],
        .exportSavedFmt:     ["en": "Exported to %@", "de": "Exportiert nach %@"],

        .obReportsTitle:     ["en": "Import sales reports", "de": "Verkaufsberichte importieren"],
        .obReportsBody:      ["en": "Analytics works best with locally stored Sales Summary reports. Enter your vendor number in Settings → Reports, download daily reports, and ASC Manager will build exact download and revenue trends — no estimates.",
                              "de": "Analysen funktionieren am besten mit lokal gespeicherten Sales-Summary-Berichten. Trage deine Anbieternummer unter Einstellungen → Berichte ein, lade tägliche Berichte herunter, und ASC Manager erstellt exakte Download- und Umsatztrends — ohne Schätzungen."],
        .obReportsVendorHint:["en": "Vendor number: App Store Connect → Payments and Financial Reports",
                              "de": "Anbieternummer: App Store Connect → Zahlungen und Finanzberichte"],
        .obReportsFolderHint:["en": "Reports are saved to a folder you choose in Settings. The app scans it automatically.",
                              "de": "Berichte werden in einem von dir gewählten Ordner gespeichert. Die App scannt ihn automatisch."],

        .rvTable:            ["en": "Table", "de": "Tabelle"],
        .rvSearch:           ["en": "Search reviews", "de": "Bewertungen durchsuchen"],
        .rvDate:             ["en": "Date", "de": "Datum"],
        .rvTitle:            ["en": "Title", "de": "Titel"],
        .rvBodyCol:          ["en": "Review", "de": "Text"],
        .rvResponded:        ["en": "Responded", "de": "Beantwortet"],
        .rvNotResponded:     ["en": "Open", "de": "Offen"],
        .rvRatingsSummary:   ["en": "Ratings summary", "de": "Bewertungsübersicht"],
        .rvAvgRating:        ["en": "Average", "de": "Durchschnitt"],
        .rvTotalRatings:     ["en": "Total ratings", "de": "Bewertungen gesamt"],

        .secPayments:        ["en": "Payments", "de": "Zahlungen"],
        .payBody:            ["en": "Expected payouts from imported sales reports aligned with Apple's fiscal calendar. Incomplete periods may still be missing daily report files.",
                               "de": "Erwartete Auszahlungen aus importierten Verkaufsberichten nach Apple-Fiskalkalender. Unvollständige Perioden können noch fehlende Tagesberichte haben."],
        .payNoDataTitle:     ["en": "No sales data", "de": "Keine Verkaufsdaten"],
        .payNoDataBody:      ["en": "Import daily Sales Summary reports in Reports to track proceeds per payout period.",
                               "de": "Importiere tägliche Sales-Summary-Berichte unter Berichte, um Erlöse pro Auszahlungsperiode zu verfolgen."],
        .payFiscalCalendar:  ["en": "Fiscal calendar", "de": "Fiskalkalender"],
        .payCurrentPeriod:   ["en": "Current period", "de": "Aktuelle Periode"],
        .payHistory:         ["en": "Payout history", "de": "Auszahlungsverlauf"],
        .payPeriod:          ["en": "Period", "de": "Periode"],
        .payPaymentDate:     ["en": "Payment date", "de": "Zahlungsdatum"],
        .payProceeds:        ["en": "Proceeds", "de": "Erlöse"],
        .payStatus:          ["en": "Status", "de": "Status"],
        .payStatusUpcoming:  ["en": "Upcoming", "de": "Bevorstehend"],
        .payStatusPaid:      ["en": "Complete", "de": "Vollständig"],
        .payStatusIncomplete:["en": "Incomplete", "de": "Unvollständig"],
        .payIncompleteHint:  ["en": "Some periods are missing daily sales reports — proceeds may still change.",
                               "de": "Einige Perioden haben noch nicht alle Tagesberichte — Erlöse können sich noch ändern."],

        .tlExport:           ["en": "Export", "de": "Export"],
        .tlExportBody:       ["en": "Export stored metrics and chart history, or enable a local HTTP API for scripts.",
                               "de": "Gespeicherte Metriken und Chart-Verlauf exportieren oder lokale HTTP-API für Skripte aktivieren."],
        .tlExportMetricsCSV: ["en": "Metrics CSV", "de": "Metriken CSV"],
        .tlExportMetricsJSON:["en": "Metrics JSON", "de": "Metriken JSON"],
        .tlExportCharts:     ["en": "Chart history JSON", "de": "Chart-Verlauf JSON"],
        .tlLocalAPI:         ["en": "Local metrics API", "de": "Lokale Metriken-API"],
        .tlLocalAPIHint:     ["en": "http://localhost:%@/metrics — GET /health, /metrics, /metrics/{appId}",
                               "de": "http://localhost:%@/metrics — GET /health, /metrics, /metrics/{appId}"],
    ]
}
