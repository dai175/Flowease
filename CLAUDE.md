# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Flowease is a macOS menu bar application built with SwiftUI.

## Prerequisites

Required:
- macOS 14.6+
- Xcode 16.0+

Required tools (install via Homebrew):
```bash
brew install swiftlint swiftformat xcbeautify pre-commit
```

## Development Commands

```bash
make build          # Build the project
make run            # Build and run the app
make test           # Run all tests (uses xcbeautify for readable output)
make lint           # Run SwiftLint (--strict mode)
make format         # Run SwiftFormat
make fix            # Format + lint
make clean          # Remove build artifacts
make setup          # Install pre-commit hooks
make hooks-run      # Run hooks on all files
make help           # Show all available commands
```

## Code Style

Enforced by SwiftLint (`.swiftlint.yml`) and SwiftFormat (`.swiftformat`). Run `make fix` before committing.

## Architecture

SwiftUI App with MVVM architecture for macOS menu bar:

- **Entry point**: `FloweaseApp.swift` (`@main`), `AppState.swift` (shared state)
- `Models/` - Data models (posture scores, face positions, calibration state, alert settings, camera devices)
- `ViewModels/` - View models (`PostureViewModel`, `CalibrationViewModel`)
- `Views/` - SwiftUI views (status menu, calibration flow, camera selection, alert settings, score display)
- `Services/` - Business logic (camera capture, face detection, posture analysis, score calculation, calibration, alerts, notifications, persistence)
- `Utilities/` - Helpers (color gradients, logger extensions, menu bar icon rendering, lock extensions)

Feature specs are stored in `specs/NNN-feature-name/` (numbered, spec-driven workflow).

## Concurrency

Swift 6 strict concurrency. Conventions:
- UI / ViewModels / Services: `@MainActor`
- Data models: `Sendable` value types
- `@unchecked Sendable` classes use `NSLock` (e.g., `ScoreHistory`, `CalibrationStorage`)
- `CameraService.frameCounter`: `OSAllocatedUnfairLock`
- `PostureAnalyzer.analyze()`: `nonisolated` + `sending` (called from AVCapture callback)
- `FaceDetector`: `Sendable`, runs Vision in `Task.detached`

## Testing

- Tests in `FloweaseTests/` — one test file per source file (e.g., `FaceDetectorTests.swift`)
- **New tests use Swift Testing** (`import Testing`, `@Test`, `#expect`)
- Legacy `FloweaseTests.swift` still uses XCTest — do not add new XCTest-based tests
- Run: `make test`
- Tests are excluded from SwiftLint analysis

## Language

- Comments/Documentation: Japanese acceptable
- Commit messages: English, Conventional Commits format (feat:, fix:, docs:, refactor:, chore:, etc.)
- PR titles: English, Conventional Commits format
- PR body: Japanese (section headings like ## Summary, ## Test plan in English)
- Respond in Japanese

## Localization

- UI strings: Localized via String Catalog (`Localizable.xcstrings`)
- Supported languages: English (base), Japanese
- Logger messages: English only (not localized)

**Important**: When adding new UI strings (Button labels, Text, etc.), always add localizations to `Localizable.xcstrings` for both `en` and `ja`. Empty entries will cause raw key names to display in non-English locales.
