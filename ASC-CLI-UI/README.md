# ASC Manager — Native macOS UI for the `asc` CLI

A SwiftUI macOS app that wraps the [`asc`](https://asccli.sh/) App Store Connect CLI
with a native interface, so you can manage apps, versions, builds, TestFlight and
signing without living in the terminal.

## How it works

The app shells out to the `asc` binary using `Process`, reads its JSON output, and
renders it natively. `asc` returns App Store Connect's JSON:API documents
(`{ "data": [ { "id", "type", "attributes": { … } } ] }`), which the app decodes
through a small generic envelope (`ASCListResponse<T>`).

Authentication reuses `asc`'s own credential store: API keys live in the system
keychain as named **profiles**. The app reads them via `asc auth status` and lets you
pick the active profile (passed to every command as `--profile`). You can also add a
new key from Settings, which runs `asc auth login`.

```
ASCService (@MainActor ObservableObject)
  ├── run(_:json:)              spawns `asc <args> [--profile P] [--output json]`
  ├── refreshAuthStatus()       parses `asc auth status`
  ├── login(...)                runs `asc auth login`
  └── loadApps / loadVersions / loadBuilds / loadCertificates / loadProfiles
        decode JSON:API → typed models (ASCApp, ASCVersion, ASCBuild, …)
```

## Onboarding & localization

First launch shows a 4-step setup guide (welcome + language → install `asc` →
connect/add an API key → finish), gated by the `asc.hasOnboarded` preference. You can
replay it any time from **Settings → Getting Started**.

The UI ships in **English and German**, switchable live at runtime via a custom
`LocalizationManager` (no app restart needed). The default follows the system language
and falls back to English. Add a language by extending `AppLanguage` and the `Strings`
table in `Localization.swift`.

## Project layout

Source is grouped into folders (an Xcode *file-system-synchronized* group, so the
on-disk structure is the project structure — no `.pbxproj` edits needed to add files):

```
ASC-CLI-UI/
  App/         ASCManagerApp.swift, ContentView.swift
  Core/        ASCService.swift, Localization.swift
  Shared/      SharedUI.swift
  Onboarding/  OnboardingView.swift
  Settings/    SettingsView.swift
  Features/    OverviewView, AppsView, VersionsView, MetadataView, MediaView,
               PricingReviewsViews, MonetizationViews, BuildsView,
               FeatureViews (TestFlight/Signing/Terminal), ReleaseView,
               SubmissionComplianceViews, ReportsView, WorkflowsView, AdsView,
               DistributionView, TeamToolsViews, DiscoverView, XcodeCloudView, HelpView
  Assets.xcassets
```

| File | Purpose |
|------|---------|
| `App/ASCManagerApp.swift` | App entry point; injects services; refreshes auth on launch |
| `App/ContentView.swift` | NavigationSplitView, grouped sidebar, shared app picker, routing |
| `Core/ASCService.swift` | Core service: runs `asc`, JSON:API models, auth/profiles, loaders |
| `Core/Localization.swift` | `LocalizationManager`, `AppLanguage`, and the en/de string table |
| `Shared/SharedUI.swift` | Reusable output panel, file/folder pickers, app info, device types |
| `Onboarding/OnboardingView.swift` | First-run setup guide (language, install check, connect, finish) |
| `Settings/SettingsView.swift` | Language, profiles, binary path, connection test, add key, replay guide, About |
| `Features/OverviewView.swift` | Dashboard with stat cards and the current app |
| `Features/AppsView.swift` | App list with search + "New App" guidance |
| `Features/VersionsView.swift` | App Store versions table + shared UI helpers (dates, headers) |
| `Features/MetadataView.swift` | Edit version localizations, file pull/apply/validate, side-by-side compare |
| `Features/MediaView.swift` | Screenshots & app preview videos (list/upload/download) |
| `Features/PricingReviewsViews.swift` | App pricing/availability; customer reviews + ratings + respond |
| `Features/MonetizationViews.swift` | Subscriptions, in-app purchases, in-app events |
| `Features/BuildsView.swift` | Build table with status badges + IPA/PKG upload |
| `Features/FeatureViews.swift` | TestFlight (groups/testers/feedback/crashes), Signing, Terminal |
| `Features/ReleaseView.swift` | Release dashboard, validate, publish flow, developer release |
| `Features/SubmissionComplianceViews.swift` | App Review lifecycle (status/details/submissions/notes); age rating, encryption, categories, EULA, tags |
| `Features/TeamToolsViews.swift` | Users, devices, sandbox testers; account/auth diagnostics, webhooks, Fastlane migrate |
| `Features/ReportsView.swift` | Analytics & sales reports, finance reports, save folder |
| `Features/WorkflowsView.swift` | Repo-local workflow automation (list/validate/run `.asc/workflow.json`) |
| `Features/AdsView.swift` | Apple Ads: auth, campaigns, ad groups, keywords, reports (separate OAuth) |
| `Features/DistributionView.swift` | Marketplace & alternative distribution (domains/keys/packages/webhooks) |
| `Features/DiscoverView.swift` | Command search, API schema, capability coverage |
| `Features/XcodeCloudView.swift` | Trigger workflows, check build-run status |
| `Features/HelpView.swift` | In-app manual: API-key walkthrough, create-app, install guide, FAQ |

## Feature sections

- **Overview** – dashboard stat cards and the active app.
- **Apps** – searchable app list; sets the active app for app-scoped sections.
- **Versions** – App Store versions table.
- **Metadata** – edit a version's localized metadata per language and save back to App Store Connect (confirmation required).
- **Builds** – builds with processing-state badges.
- **TestFlight** – parsed beta-group and tester tables, feedback, and a guarded "notify testers of latest build".
- **Release** – release pipeline status (`asc status`), a readiness check (`asc validate`), an "Open in App Store Connect" link, and a guarded developer-release for versions pending release.
- **Reports** – create/list analytics requests, download sales summaries, and pull finance reports (needs your vendor number). Pick a **save folder**, optionally **decompress** the `.tsv.gz` to plain `.tsv`, and jump straight to the file with **Show in Finder**.
- **Signing** – certificates and provisioning profiles.
- **Terminal** – run arbitrary `asc` commands.
- **Help** – built-in manual (always available, even before setup): step-by-step API-key creation with a link to the App Store Connect Keys page, install guide, and troubleshooting FAQ.

> Mutating actions (release, metadata save, tester notifications) always ask for confirmation first.

## Requirements

- macOS 15.6+ and Xcode 26+
- The `asc` CLI: `brew install asc`
- An App Store Connect API key (Key ID, Issuer ID, `.p8` file)

## Setup

1. Open `ASC-CLI-UI.xcodeproj` in Xcode and run the `ASC-CLI-UI` scheme.
2. If you already use `asc` in the terminal, your existing profiles appear
   automatically — just pick one in Settings and hit **Test Connection**.
3. Otherwise open Settings → **Add API Key**, fill in the Key ID, Issuer ID and the
   path to your `.p8` file. The key is stored in your keychain by `asc`.

> **App Sandbox is disabled.** The app needs to launch the `asc` binary and read its
> keychain-backed credentials, which the sandbox would block. This is a local
> developer tool, not a Mac App Store submission.

## Extending

Adding a new section:

1. Add a case to `SidebarItem` in `ContentView.swift` (set `requiresApp` if it needs a selected app).
2. Create a new View file and wire it into the `detail` switch.
3. Add a loader to `ASCService` that calls `run([...])` and decodes via `decodeList(_:as:)`.

The `run()` method appends the active `--profile` and `--output json` automatically, so
loaders only pass the subcommand arguments. Build new attribute models by decoding the
JSON:API `id` + `attributes` (see `ASCApp` for the pattern).

## License

Released under the [MIT License](../LICENSE) — free for anyone to use, modify, and
distribute.

## Notes for an open-source release

This repo is intended to become public. A few things to know before publishing:

- **No secrets are committed.** API keys and `.p8` files live in your macOS keychain
  (managed by `asc`), never in the project. Settings (vendor number, save folder,
  selected profile) are stored in `UserDefaults`, not in the repo.
- **Signing is account-specific.** `DEVELOPMENT_TEAM` and `PRODUCT_BUNDLE_IDENTIFIER`
  in the Xcode project point at the original author's Apple account. Contributors should
  set their own Team and bundle identifier in *Signing & Capabilities* to build locally.
- Build artifacts (`DerivedData/`, `.build-dd/`, `*.xcuserstate`) are already gitignored.
