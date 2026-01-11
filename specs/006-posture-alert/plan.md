# Implementation Plan: 姿勢アラート通知機能

**Branch**: `006-posture-alert` | **Date**: 2026-01-11 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/006-posture-alert/spec.md`

## Summary

姿勢スコアの時系列データを監視し、悪い姿勢が一定期間続いた場合にmacOS通知でユーザーに気づきを与える機能を実装する。既存のPostureAnalyzerからスコアを受け取り、累積ベースの評価とスマートな再通知制御を提供する。

## Technical Context

**Language/Version**: Swift 6.0
**Primary Dependencies**: SwiftUI, UserNotifications, OSLog
**Storage**: UserDefaults（既存のCalibrationStorageパターンを踏襲）
**Testing**: XCTest
**Target Platform**: macOS 14.6+
**Project Type**: Single (macOS menu bar app)
**Performance Goals**: スコア更新時の判定処理 < 10ms
**Constraints**: メモリ使用量を最小限に（評価期間分のスコアのみ保持）
**Scale/Scope**: 単一ユーザー、最大10分間のスコア履歴

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. SwiftUI-First Architecture | ✅ Pass | 設定UIはSwiftUIで構築、状態は@Observableで管理 |
| II. Type Safety & Memory Safety | ✅ Pass | Force unwrap禁止、Sendable準拠 |
| III. Test-Driven Development | ✅ Pass | ビジネスロジック（判定ロジック）のユニットテスト作成 |
| IV. User Experience Excellence | ✅ Pass | macOS標準通知、HIG準拠 |
| V. Observability & Debugging | ✅ Pass | Logger使用、通知イベントのログ記録 |
| VI. Code Quality Gates | ✅ Pass | SwiftLint/SwiftFormat適用 |

## Project Structure

### Documentation (this feature)

```text
specs/006-posture-alert/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
Flowease/
├── Models/
│   ├── AlertSettings.swift      # 通知設定モデル (NEW)
│   └── AlertState.swift         # 通知状態モデル (NEW)
├── Services/
│   ├── ScoreHistory.swift       # スコア履歴管理 (NEW)
│   ├── PostureAlertService.swift # 通知判定ロジック (NEW)
│   ├── NotificationManager.swift # macOS通知送信 (NEW)
│   └── AlertSettingsStorage.swift # 設定永続化 (NEW)
├── ViewModels/
│   └── AppState.swift           # 既存に通知機能を統合 (MODIFY)
├── Views/
│   └── AlertSettingsView.swift  # 通知設定UI (NEW)
└── Localizable.xcstrings        # 通知テキスト追加 (MODIFY)

FloweaseTests/
├── ScoreHistoryTests.swift      # (NEW)
├── PostureAlertServiceTests.swift # (NEW)
└── AlertSettingsTests.swift     # (NEW)
```

**Structure Decision**: 既存のMVVMアーキテクチャを踏襲し、Services/に新規サービスを追加。Models/に設定・状態モデルを追加。

## Complexity Tracking

> No violations. Design follows existing patterns.
