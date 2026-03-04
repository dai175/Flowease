# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Flowease is a macOS menu bar application built with SwiftUI. Target: macOS 14.6+, Swift 6.0.

## Prerequisites

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

## Code Style Rules

- Use `Logger` or `os_log` instead of `print()` (enforced by SwiftLint custom rule)
- Avoid force unwrapping (`!`) - use optional binding or guard
- Avoid implicitly unwrapped optionals (`String!`)
- Line length: 120 (warning), 150 (error)
- Function body: max 50 lines (warning), 100 (error)
- See `.swiftlint.yml` for full configuration

## Architecture

SwiftUI App with MVVM architecture for macOS menu bar:

- **Entry point**: `FloweaseApp.swift` (`@main`), `AppState.swift` (shared state)
- `Models/` - Data models (posture scores, face positions, calibration state, alert settings, camera devices)
- `ViewModels/` - View models (`PostureViewModel`, `CalibrationViewModel`)
- `Views/` - SwiftUI views (status menu, calibration flow, camera selection, alert settings, score display)
- `Services/` - Business logic (camera capture, face detection, posture analysis, score calculation, calibration, alerts, notifications, persistence)
- `Utilities/` - Helpers (color gradients, logger extensions, menu bar icon rendering, lock extensions)

## Testing

- Tests in `FloweaseTests/` — one test file per source file (e.g., `FaceDetectorTests.swift`)
- Run: `make test`
- Tests are excluded from SwiftLint analysis

## Language

- Code: English
- Comments/Documentation: Japanese acceptable
- Respond in Japanese

## Technologies

- **UI**: Swift 6.0 + SwiftUI
- **Camera**: AVFoundation (video capture, CMSampleBuffer)
- **Face Detection**: Vision framework (VNDetectFaceRectanglesRequest, VNDetectFaceCaptureQualityRequest)
- **Notifications**: UserNotifications framework (macOS system notifications)
- **Persistence**: UserDefaults (calibration data, alert settings)

## Features

- Posture scoring (camera → face analysis → 0–100 score)
- Posture calibration (register personal baseline posture)
- Posture alerts (customizable threshold, evaluation period, notification interval)
- Menu bar resident (hidden from Dock)
- Score-based color gradient (green=good, red=needs improvement, gray=undetected)
- Camera selection (auto-handles disconnect/reconnect)
- VoiceOver accessibility (English and Japanese)

## Localization

- UI strings: Localized via String Catalog (`Localizable.xcstrings`)
- Supported languages: English (base), Japanese
- Logger messages: English only (not localized)

**Important**: When adding new UI strings (Button labels, Text, etc.), always add localizations to `Localizable.xcstrings` for both `en` and `ja`. Empty entries will cause raw key names to display in non-English locales.
