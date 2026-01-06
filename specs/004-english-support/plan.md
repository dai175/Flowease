# Implementation Plan: 英語対応

**Branch**: `004-english-support` | **Date**: 2026-01-06 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/004-english-support/spec.md`

## Summary

Floweaseアプリに英語ローカライゼーションを追加し、macOSの言語設定に応じて日本語または英語でUIを表示する。String Catalog（Localizable.xcstrings）を使用して、すべてのユーザー向けテキスト（メニュー、キャリブレーション画面、エラーメッセージ、ボタンラベル）を多言語対応にする。

## Technical Context

**Language/Version**: Swift 6.0
**Primary Dependencies**: SwiftUI, Foundation (Bundle.localizedString, String Catalog)
**Storage**: N/A（ローカライゼーションはバンドルリソース）
**Testing**: XCTest
**Target Platform**: macOS 14.6+
**Project Type**: Single macOS menu bar application
**Performance Goals**: N/A（ローカライゼーションはランタイムパフォーマンスに影響なし）
**Constraints**: 2言語対応（日本語・英語）、OSの言語設定に従う
**Scale/Scope**: 約30-40のローカライズ対象文字列

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. SwiftUI-First Architecture | ✅ PASS | View内の文字列をString(localized:)で置換。副作用なし |
| II. Type Safety & Memory Safety | ✅ PASS | String Catalogは型安全。Force unwrapなし |
| III. Test-Driven Development | ✅ PASS | ローカライゼーションキーの存在テストを追加 |
| IV. User Experience Excellence | ✅ PASS | システム言語設定を尊重。HIG準拠 |
| V. Observability & Debugging | ✅ PASS | ローカライゼーション欠落時のログ対応 |
| VI. Code Quality Gates | ✅ PASS | SwiftLint/SwiftFormat適用。行長制限内 |

**Gate Result**: PASS - 全原則に準拠。Phase 0 に進行可能。

## Project Structure

### Documentation (this feature)

```text
specs/004-english-support/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
Flowease/
├── Models/
│   ├── DisableReason.swift      # description, actionHint プロパティ
│   ├── PauseReason.swift        # description プロパティ
│   └── CalibrationFailure.swift # userMessage プロパティ
├── ViewModels/
│   └── CalibrationViewModel.swift # qualityWarningMessage, statusText 等
├── Views/
│   ├── StatusMenuView.swift       # UIテキスト
│   ├── CalibrationView.swift      # UIテキスト
│   └── CameraPermissionView.swift # UIテキスト
└── Localizable.xcstrings          # NEW: String Catalog（日本語・英語）

FloweaseTests/
└── LocalizationTests.swift        # NEW: ローカライゼーションキーテスト
```

**Structure Decision**: 既存のMVVMアーキテクチャを維持。新規ファイルは `Localizable.xcstrings`（String Catalog）と `LocalizationTests.swift`（テスト）のみ。

## Complexity Tracking

> Constitution Checkに違反なし。複雑さの追加正当化は不要。
