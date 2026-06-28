# Mobile Remote Mirror (iCloud / CloudKit)

This document describes the **Phase 2** CloudKit "producer" that was added to the macOS
app (`ASC-CLI-UI`), and the manual Apple Developer portal / Xcode steps required to turn
it on. The eventual **Phase 3** iPhone "consumer" app is **not** built yet.

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

## Phase 3 (not in scope here)

Still **pending** — to be built later:

- An **iOS app target** (consumer/reader) that subscribes to the `ASCMirror` zone.
- Reading `ASCSnapshot` records, decoding `Snapshot` / `payloadJSON`, and rendering them.
- Push-driven refresh (`CKDatabaseSubscription` + remote notifications) on iOS.

Phase 2 intentionally ships **no** iOS target, consumer UI, or push-receiving code.
