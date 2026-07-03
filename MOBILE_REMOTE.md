# Mobile Remote Mirror (iCloud / CloudKit)

This document describes the **Phase 2** CloudKit "producer" in the macOS app (`ASC-CLI-UI`)
and the **Phase 3b** read-only iPhone "consumer" (`ASC-CLI-UI-Remote`), plus the manual
Apple Developer portal / Xcode steps required to turn each on. The iOS consumer is built
(see [Phase 3b](#phase-3b--ios-mirror-consumer-asc-cli-ui-remote) below).

## What Phase 2 added

The macOS app can now mirror a selected app's App Store Connect data into the user's
**private iCloud (CloudKit) database**, so a future companion iPhone app can read it.

- **Off by default.** Nothing changes unless the user enables it in
  **Settings → Remote sync**.
- It never mutates App Store Connect, the `asc` CLI invocation, or credentials. It only
  reads the same JSON the app already fetches and uploads a copy.

### Code

| File | Role |
| --- | --- |
| `ASCShared/Sources/ASCShared/RemoteMirror.swift` | Pure, testable logic: `MirrorSection`, `SyncInterval`, CloudKit naming/threshold constants, and `RemoteMirror.summarize(...)`. |
| `ASCShared/Sources/ASCShared/Snapshot.swift` | (Existing) `Snapshot` model that is uploaded. |
| `ASC-CLI-UI/Core/CloudKitSync.swift` | CloudKit uploader (private DB, custom zone, upsert, asset fallback). |
| `ASC-CLI-UI/Core/SnapshotEngine.swift` | Captures sections via `asc`, wraps them in `Snapshot`s, drives periodic + on-demand sync. |
| `ASC-CLI-UI/Settings/SettingsView.swift` | "Remote sync" settings section (toggle, interval, sections, Sync now, status). |
| `ASC-CLI-UI/ASC-CLI-UI.entitlements` | iCloud/CloudKit + Push entitlements — **present but not yet wired** (see below). |

### Mirrored sections

The engine runs these read-only `asc` commands and stores one snapshot per section:

| Section | `asc` command |
| --- | --- |
| `status` | `asc status --app <id> --include app,builds,testflight,appstore,submission,review,phased-release,links` |
| `versions` | `asc versions list --app <id> --limit 50` |
| `builds` | `asc builds list --app <id> --limit 50` |
| `betaGroups` | `asc testflight groups list --app <id> --limit 200` |
| `reviews` | `asc reviews ratings --app <id>` |
| `pricing` | `asc pricing current --app <id>` |
| `subscriptions` | `asc subscriptions groups list --app <id>` |

Default selection: `status`, `versions`, `builds`.

## CloudKit design

- **Container:** `iCloud.PySaasNow.ASC-CLI-UI`
- **Database:** private
- **Zone:** one custom zone named `ASCMirror` (created if missing)
- **Record type:** `ASCSnapshot`
- **Record name:** stable, `"<appId>:<section>"` (one record per app+section, upserted
  last-writer-wins with save policy `.allKeys`)
- **Fields:** `appId` (String), `section` (String), `schemaVersion` (Int),
  `capturedAt` (Date), `summary` (String, JSON of the headline values),
  `payloadIsAsset` (Int 0/1), and the payload as **either**:
  - `payloadJSON` (String) when ≤ ~900 KB, **or**
  - `payloadAsset` (CKAsset, a temp file) when > ~900 KB.

All CloudKit calls are wrapped so failures surface in the UI (`Settings → Remote sync →
Last sync`) but never crash the app.

## Manual steps to enable CloudKit (required before sync works at runtime)

CloudKit code compiles and ships today, but uploads will fail until the container is
provisioned and the entitlement is enabled. The entitlement is **deliberately not wired
into the build** (`CODE_SIGN_ENTITLEMENTS` is unset) because enabling an unprovisioned
iCloud container breaks automatic code signing in CI / headless builds.

1. **Apple Developer portal — App ID capabilities**
   - Go to <https://developer.apple.com/account/resources/identifiers/list>.
   - Select the App ID for `PySaasNow.ASC-CLI-UI`.
   - Enable **iCloud** (with CloudKit support) and **Push Notifications**.
2. **Create the iCloud container**
   - In **Certificates, Identifiers & Profiles → Identifiers → iCloud Containers**,
     create container **`iCloud.PySaasNow.ASC-CLI-UI`** and assign it to the App ID.
3. **Xcode — add capabilities**
   - Open `ASC-CLI-UI.xcodeproj`, select the **ASC-CLI-UI** target →
     **Signing & Capabilities**.
   - Click **+ Capability → iCloud**; check **CloudKit**; add the container
     `iCloud.PySaasNow.ASC-CLI-UI`.
   - Click **+ Capability → Push Notifications**.
   - Xcode will create/point `CODE_SIGN_ENTITLEMENTS` at an entitlements file. You can
     either let Xcode manage it or set it to the provided
     `ASC-CLI-UI/ASC-CLI-UI.entitlements`.
4. **Build & run**, open **Settings → Remote sync**, enable the toggle, pick an app in the
   toolbar, and press **Sync now**.

## Verify in CloudKit Dashboard

1. Go to <https://icloud.developer.apple.com/dashboard/> and select container
   `iCloud.PySaasNow.ASC-CLI-UI`.
2. **Private Database → Zones**: confirm the `ASCMirror` zone exists.
3. **Records**: query record type `ASCSnapshot`; you should see records named
   `<appId>:status`, `<appId>:versions`, etc., with `payloadJSON`/`payloadAsset`,
   `summary`, and `capturedAt` populated.
4. If you query in development, ensure you are looking at the **Development** environment
   matching your build, and that you are signed in to iCloud on the test Mac.

## Phase 3b — iOS mirror consumer (`ASC-CLI-UI-Remote`)

The iOS target is now a **read-only mirror consumer**. It reads the same private CloudKit
records the macOS app uploads, caches them for offline use, renders them with the shared
`OutputView`, and refreshes on a CloudKit push. It performs **no** App Store Connect
access and runs **no** `asc` commands.

### Code

| File | Role |
| --- | --- |
| `ASCShared/Sources/ASCShared/MirrorConsumer.swift` | Pure, testable consumer logic: `SnapshotFields`, `MirrorAppGroup`, and `RemoteMirror.makeSnapshot(...)` / `decodeSummary(...)` / `group(...)` / `latest(...)`. No CloudKit import. |
| `ASC-CLI-UI-Remote/CloudKitMirrorReader.swift` | `@MainActor` observable store. Fetches `ASCSnapshot` records from the private DB zone `ASCMirror`, handles String **and** `CKAsset` payloads, exposes `[MirrorAppGroup]` (grouped by `appId`), surfaces errors/empty state, never crashes. Manual `refresh()`. |
| `ASC-CLI-UI-Remote/SnapshotCache.swift` | Offline cache: atomic Codable-to-file (`mirror-cache.json` in Application Support). |
| `ASC-CLI-UI-Remote/RemotePush.swift` | `CKDatabaseSubscription` registration + `AppDelegate` for remote-notification delivery → posts `.mirrorRemoteChange` → triggers a refresh. |
| `ASC-CLI-UI-Remote/RootView.swift` | Lists mirrored apps; pull-to-refresh; localized empty/error states. |
| `ASC-CLI-UI-Remote/AppSectionsView.swift` | Per-app section list with summary headline + "last updated" stamp. |
| `ASC-CLI-UI-Remote/SectionDetailView.swift` | Renders a real `Snapshot.payloadJSON` via the shared `OutputView`. |
| `ASC-CLI-UI-Remote/ASC-CLI-UI-Remote.entitlements` | iCloud/CloudKit + Push entitlements — **present but not yet wired** (see below). |

The consumer reuses the producer's shared constants directly — `RemoteMirror.containerID`,
`RemoteMirror.zoneName`, `RemoteMirror.recordType`, and the field layout — so producer and
consumer can never drift apart.

### Offline cache

The latest fetched snapshots are written as a single atomic JSON file. On launch the app
loads the cache first (instant / offline last-known data), then refreshes from CloudKit.
A flat replace-on-refresh array has no relationships or partial updates, so a plain Codable
file is simpler and more failure-tolerant than SwiftData (it degrades to "no cache" rather
than throwing store/migration errors).

### Push

Implemented in code (`RemotePush` + `AppDelegate`): a private-database `CKDatabaseSubscription`
with `shouldSendContentAvailable` (silent push) is created after the device registers for
remote notifications; an incoming CloudKit notification triggers `refresh()`. **Silent pushes
only arrive on a real device with the capabilities enabled** (below) — until then the code is
inert and the UI relies on manual pull-to-refresh.

## Manual steps to enable the iOS consumer (required before live data / push)

Like the macOS side, the iOS CloudKit + push **code compiles and ships today**, but the
entitlement is deliberately **not** wired into `CODE_SIGN_ENTITLEMENTS` (enabling an
unprovisioned iCloud container breaks automatic / headless code signing).

1. **Provision CloudKit** (shared with macOS) — already done if Phase 2 is enabled:
   the App ID has iCloud + Push, and the container `iCloud.PySaasNow.ASC-CLI-UI` exists.
2. **Xcode — add capabilities to `ASC-CLI-UI-Remote`**
   - Select the **ASC-CLI-UI-Remote** target → **Signing & Capabilities**.
   - **+ Capability → iCloud**; check **CloudKit**; add container `iCloud.PySaasNow.ASC-CLI-UI`.
   - **+ Capability → Push Notifications**.
   - **+ Capability → Background Modes**; check **Remote notifications**.
   - Xcode points `CODE_SIGN_ENTITLEMENTS` at the provided
     `ASC-CLI-UI-Remote/ASC-CLI-UI-Remote.entitlements` (or generates one) and adds the
     `UIBackgroundModes = remote-notification` Info.plist entry.
3. **Run on a real device** (push notifications do not work in the Simulator). Sign in to the
   **same iCloud account** as the Mac that uploads the mirror.

## Confirm data flows Mac → CloudKit → iPhone

1. On the Mac: **Settings → Remote sync**, enable, pick an app, **Sync now**.
2. In the **CloudKit Dashboard** (private DB, zone `ASCMirror`): confirm `ASCSnapshot`
   records named `<appId>:<section>` exist (see the Phase 2 verification above).
3. On the iPhone: launch `ASC-CLI-UI-Remote`. It loads any cached data, then refreshes. The
   app appears in **Mirrored Apps**; tap it to see each mirrored section with a "last
   updated" stamp; tap a section to render its data.
4. Push test: change data on the Mac and **Sync now** again. With capabilities enabled and a
   real device, the phone receives a silent push and refreshes automatically; otherwise pull
   down to refresh manually.

> Note: the consumer fetches the whole zone via `CKFetchRecordZoneChangesOperation`, so it
> needs **no** queryable indexes — only that the `ASCMirror` zone exists (created by the
> producer's first sync).

## Phase 3c — iOS dashboard (overview, charts, typed sections)

The consumer renders more than raw JSON now:

- **Per-app overview** (top of the sections list): stat tiles assembled from the
  producer's snapshot summaries — release health (+ next action), latest version and
  build with state, average rating, public chart rank (with rank delta), and 7-day
  downloads/proceeds when `storedMetrics` is mirrored.
- **14-day trend chart** (Swift Charts) from the `storedMetrics` payload; downloads
  and proceeds are separate single-axis series behind a segmented picker.
- **Week-over-week metrics** from the mirrored `analytics` (insights weekly) payload,
  as a stat list with delta chips (mixed units, deliberately not a shared-axis chart).
- **Typed section details** for `versions`, `builds` and `betaGroups` (native cards
  with state badges via the shared `ASCJSONList` decoder), plus dedicated views for
  `storedMetrics`, `marketRank`, `reviews` and `analytics`. Any payload that fails to
  parse falls back to the schema-agnostic `OutputView` as before.

Typed payload models (`StoredMetricsPayload`, `MarketRankPayload`) live in
`ASCShared/Sources/ASCShared/MirrorInsights.swift` and are covered by
`MirrorInsightsTests`.
