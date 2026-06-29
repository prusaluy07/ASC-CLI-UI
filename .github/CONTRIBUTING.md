# Contributing to ASC Manager

Thanks for your interest in improving ASC Manager! This document covers how to get
set up and what to keep in mind when contributing.

## Prerequisites

- macOS 14 or later
- Xcode 16 or later
- The [`asc`](https://asccli.sh/) CLI installed (`brew install asc`) for running the app
  against real App Store Connect data

## Project layout

| Path | Purpose |
| --- | --- |
| `ASC-CLI-UI/` | macOS app (SwiftUI) |
| `ASC-CLI-UI-Remote/` | iPhone companion app (CloudKit mirror consumer) |
| `ASCShared/` | Shared Swift package: models, localization, snapshot/mirror, analytics parsing |
| `docs/` | Images and assets used by the README |

Most logic that can be unit-tested lives in the `ASCShared` package, so prefer putting
testable code there.

## Building & testing

Run the shared-package tests (these run in CI):

```bash
cd ASCShared
swift test
```

Build the macOS app:

```bash
xcodebuild -project ASC-CLI-UI.xcodeproj -scheme ASC-CLI-UI \
  -configuration Debug -destination 'platform=macOS' build
```

## Guidelines

- **Never commit credentials.** API keys (`.p8`), `config.json`, and `.env` files are
  git-ignored on purpose — keep it that way. The app reads credentials from the macOS
  keychain via `asc`; it never stores them itself.
- Keep new user-facing strings localized in both English and German
  (`ASCShared/Sources/ASCShared/Localization.swift`).
- Add or update tests in `ASCShared/Tests` when you change parsing or model logic.
- Follow the existing code style; avoid comments that merely restate the code.

## Pull requests

1. Fork and create a feature branch.
2. Make your change with tests where applicable.
3. Ensure `swift test` passes in `ASCShared`.
4. Open a PR describing the change and the motivation behind it.
