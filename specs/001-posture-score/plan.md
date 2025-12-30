# Implementation Plan: 姿勢スコア表示機能

**Branch**: `001-posture-score` | **Date**: 2025-12-30 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-posture-score/spec.md`

## Summary

macOSメニューバーに常駐するアプリケーションで、カメラから取得した映像を使用してユーザーの上半身の姿勢をリアルタイムで分析し、0〜100のスコアとして算出する。スコアに応じてメニューバーアイコンの色がグラデーションで変化（緑=良好〜赤=注意）し、ユーザーに視覚的なフィードバックを提供する。姿勢検出にはApple Vision frameworkを使用し、ローカル処理のみでプライバシーを保護する。

## Technical Context

**Language/Version**: Swift 6.0
**Primary Dependencies**: SwiftUI, AVFoundation (カメラキャプチャ), Vision (姿勢検出/ボディポーズ推定)
**Storage**: N/A（永続化不要、インメモリ状態管理のみ）
**Testing**: XCTest (ユニットテスト, UIテスト)
**Target Platform**: macOS 14.6+
**Project Type**: single (macOSメニューバーアプリ)
**Performance Goals**:
- フレーム処理: 10〜15 fps での姿勢分析
- スコア更新: 姿勢変化から2秒以内にアイコン色更新 (SC-001)
- 起動時間: 5秒以内に姿勢監視開始 (SC-004)
**Constraints**:
- メモリ: 長時間稼働（8時間）でメモリリークなし (SC-005)
- CPU: バックグラウンド動作のため低CPU使用率を維持
- プライバシー: カメラ映像の保存・送信禁止 (FR-010)
**Scale/Scope**: シングルユーザー、ローカル実行のみ

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. SwiftUI-First Architecture | ✅ PASS | メニューバーUI、設定画面はSwiftUIで実装。状態は@Observableで管理 |
| II. Type Safety & Memory Safety | ✅ PASS | Force unwrap禁止、Result/async throwsでエラーハンドリング |
| III. Test-Driven Development | ✅ PASS | スコア算出ロジック、状態遷移のユニットテストを先行実装 |
| IV. User Experience Excellence | ✅ PASS | メニューバーアプリとしてHIG準拠、Dockアイコン非表示 |
| V. Observability & Debugging | ✅ PASS | Logger (OSLog) でカメラ状態・スコア変化をログ出力 |
| VI. Code Quality Gates | ✅ PASS | SwiftLint/SwiftFormat、pre-commit hooks適用済み |

**Gate Result**: ✅ PASS - 全原則に準拠。Phase 0 研究を開始可能。

## Project Structure

### Documentation (this feature)

```text
specs/001-posture-score/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (N/A - ネットワークAPI不要)
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
Flowease/
├── FloweaseApp.swift            # App entry point - メニューバーアプリ設定
├── ContentView.swift            # メインビュー（メニュー表示用）
├── Models/
│   ├── PostureScore.swift       # 姿勢スコアモデル (0-100)
│   └── MonitoringState.swift    # 監視状態 (active/paused/disabled)
├── Services/
│   ├── CameraService.swift      # AVFoundationカメラキャプチャ
│   ├── PostureAnalyzer.swift    # Vision framework姿勢分析
│   └── ScoreCalculator.swift    # 姿勢→スコア変換ロジック
├── ViewModels/
│   └── PostureViewModel.swift   # @Observable状態管理
├── Views/
│   ├── MenuBarView.swift        # メニューバーアイコン＆メニュー
│   └── StatusMenuView.swift     # クリック時のメニュー内容
└── Utilities/
    └── ColorGradient.swift      # スコア→色変換

FloweaseTests/
├── ScoreCalculatorTests.swift   # スコア算出ロジックテスト
├── PostureAnalyzerTests.swift   # 姿勢分析モックテスト
└── MonitoringStateTests.swift   # 状態遷移テスト

FloweaseUITests/
└── MenuBarUITests.swift         # メニューバー操作テスト
```

**Structure Decision**: シングルプロジェクト構成。macOSメニューバーアプリとして、Models/Services/ViewModels/Viewsの標準的なMVVM構造を採用。SwiftUI-First原則に基づき、ViewModelは@Observableマクロを使用。

## Complexity Tracking

> **Gate Status**: ✅ 全原則に準拠 - 正当化不要

N/A - Constitution違反なし

---

## Constitution Check (Post-Design)

*Re-evaluation after Phase 1 design completion.*

| Principle | Status | Post-Design Notes |
|-----------|--------|-------------------|
| I. SwiftUI-First Architecture | ✅ PASS | MenuBarExtra + @Observable で実装。View は描画のみ、ロジックは Service/ViewModel に分離 |
| II. Type Safety & Memory Safety | ✅ PASS | 全モデルが Sendable 準拠、Optional の安全な取り扱い、confidence チェックで品質保証 |
| III. Test-Driven Development | ✅ PASS | ScoreCalculator, MonitoringState のユニットテストを設計。モック可能なプロトコル設計 |
| IV. User Experience Excellence | ✅ PASS | HSB グラデーションで直感的な色表示、権限フローでシステム設定誘導を設計 |
| V. Observability & Debugging | ✅ PASS | Logger (OSLog) をカメラ・分析・スコアの各レイヤーで使用する設計 |
| VI. Code Quality Gates | ✅ PASS | 既存の SwiftLint/SwiftFormat 設定を継続使用 |

**Post-Design Gate Result**: ✅ PASS - Phase 1 設計が全原則に準拠していることを確認。

---

## Generated Artifacts

| Artifact | Path | Status |
|----------|------|--------|
| Implementation Plan | `specs/001-posture-score/plan.md` | ✅ Complete |
| Research | `specs/001-posture-score/research.md` | ✅ Complete |
| Data Model | `specs/001-posture-score/data-model.md` | ✅ Complete |
| Quickstart | `specs/001-posture-score/quickstart.md` | ✅ Complete |
| Contracts | N/A (ネットワークAPI不要) | ⏭️ Skipped |
| Tasks | `specs/001-posture-score/tasks.md` | ⏳ Pending (/speckit.tasks) |
