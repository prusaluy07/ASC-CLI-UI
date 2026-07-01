# AGENTS.md

## Cursor Cloud specific instructions

### Platform reality: this is a macOS/iOS-only project

ASC Manager is a native **SwiftUI** app for macOS (with an iOS companion, `ASC-CLI-UI-Remote`),
built with Xcode. It **cannot be built, run, or fully tested on the Linux Cloud Agent VM.**

- Requirements (see `README.md` / `.github/CONTRIBUTING.md`): macOS 15.6+, Xcode 26, and the
  `asc` CLI. CI runs on `macos-15` (`.github/workflows/ci.yml`).
- The app targets are `ASC-CLI-UI` (macOS) and `ASC-CLI-UI-Remote` (iOS); building them requires
  `xcodebuild` on macOS. Neither `xcodebuild` nor the Apple SDKs exist on Linux.
- Even the "testable" shared package `ASCShared` does **not** compile on Linux: `swift test`
  fails because `ASCShared/Sources/ASCShared/Localization.swift` and `Output.swift` import
  `SwiftUI` (and `Combine`), which are Apple-only frameworks with no Linux implementation.
  The open-source Linux Swift toolchain reports `error: no such module 'SwiftUI'`. Do not modify
  the package layout to work around this — the split is intentional for the macOS/iOS targets.

### What this means for a Linux Cloud Agent

- There is **no** app to run and **no** dev server here. Do not attempt `xcodebuild` or expect
  `swift test` to pass on Linux.
- The only meaningful verification on macOS is `cd ASCShared && swift test` (runs in CI) and the
  `xcodebuild ... -scheme ASC-CLI-UI` build documented in `.github/CONTRIBUTING.md`. Run those on
  a macOS machine or CI, not here.
- There are **no external Swift package dependencies** (`ASCShared/Package.swift` declares none),
  so there is nothing for an update script to install for this repo on Linux.

### Optional: type-checking Foundation-only Swift on Linux

Most logic (`Models`, `Analytics`, `Snapshot`, `MetadataValidation`, `MirrorConsumer`, etc.) is
Foundation-only. If you need to sanity-check the syntax of an individual Foundation-only file, you
can install the Linux Swift toolchain manually and use `swiftc -parse <file>.swift`. This is an
optional, on-demand step (a ~750 MB download) and is deliberately **not** part of the startup
update script to keep startup robust. Note that whole-package `swift build`/`swift test` will still
fail on Linux due to the `SwiftUI` imports above.
