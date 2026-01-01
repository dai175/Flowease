# Implementation Plan: 姿勢キャリブレーション機能

**Branch**: `002-posture-calibration` | **Date**: 2026-01-01 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/002-posture-calibration/spec.md`

## Summary

ユーザー個人の「良い姿勢」を基準として記録し、その基準からの逸脱度に基づいて姿勢スコアを算出するキャリブレーション機能を実装する。現在の固定しきい値による評価を、ユーザーごとにパーソナライズされた評価に置き換える。

技術アプローチ:
- 3秒間（約90フレーム）の複数フレームを平均化して基準姿勢を記録
- 既存の4項目（頭傾き、肩バランス、前傾、対称性）を基準姿勢からの逸脱度で再計算
- UserDefaultsで基準姿勢を永続化（状態はreferencePostureの有無から導出）
- SwiftUIでキャリブレーション画面とプログレス表示を実装

## Technical Context

**Language/Version**: Swift 6.0
**Primary Dependencies**: SwiftUI, AVFoundation, Vision (VNDetectHumanBodyPoseRequest)
**Storage**: UserDefaults（キャリブレーションデータの永続化）
**Testing**: XCTest
**Target Platform**: macOS 14.6+
**Project Type**: single (macOS menu bar app)
**Performance Goals**: リアルタイム姿勢検知（カメラフレームレートに追従）、UI操作100ms以内のレスポンス
**Constraints**: メニューバー常駐アプリ、低リソース消費、Dock非表示
**Scale/Scope**: 単一ユーザー、単一デバイス

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. SwiftUI-First Architecture | ✅ PASS | キャリブレーション画面はSwiftUIで実装。ViewはStateから派生。 |
| II. Type Safety & Memory Safety | ✅ PASS | ReferencePostureはCodable構造体。Optional適切に使用。force unwrap禁止。 |
| III. Test-Driven Development | ✅ PASS | CalibrationService, 逸脱度計算のユニットテストを先行実装。 |
| IV. User Experience Excellence | ✅ PASS | プログレス表示、エラーメッセージ、状態表示でHIG準拠。 |
| V. Observability & Debugging | ✅ PASS | Logger使用。キャリブレーション成功/失敗をログ出力。 |
| VI. Code Quality Gates | ✅ PASS | SwiftLint/SwiftFormat適用。既存ルール準拠。 |

**Gate Result**: ✅ ALL PASS - Phase 0に進行可能

## Project Structure

### Documentation (this feature)

```text
specs/002-posture-calibration/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (internal service contracts)
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
Flowease/
├── Models/
│   ├── BodyPose.swift              # 既存: 姿勢データ
│   ├── PostureScore.swift          # 既存: スコアデータ
│   ├── ScoreBreakdown.swift        # 既存: スコア内訳
│   ├── ReferencePosture.swift      # 新規: 基準姿勢データ
│   └── CalibrationState.swift      # 新規: キャリブレーション状態
├── Services/
│   ├── PostureAnalyzer.swift       # 既存: 姿勢分析
│   ├── ScoreCalculator.swift       # 変更: 基準姿勢からの逸脱度計算
│   ├── CameraService.swift         # 既存: カメラ制御
│   ├── CalibrationService.swift    # 新規: キャリブレーション制御
│   └── CalibrationStorage.swift    # 新規: 永続化
├── ViewModels/
│   ├── PostureMonitorViewModel.swift  # 変更: キャリブレーション状態連携
│   └── CalibrationViewModel.swift     # 新規: キャリブレーション画面VM
├── Views/
│   ├── StatusMenuView.swift        # 変更: キャリブレーションメニュー追加
│   ├── CalibrationView.swift       # 新規: キャリブレーション画面
│   └── CalibrationProgressView.swift  # 新規: プログレス表示
└── Utilities/
    └── ColorGradient.swift         # 既存: 色計算

FloweaseTests/
├── CalibrationServiceTests.swift   # 新規
├── CalibrationStorageTests.swift   # 新規
├── ScoreCalculatorTests.swift      # 変更: 逸脱度計算テスト追加
└── ReferencePostureTests.swift     # 新規
```

**Structure Decision**: 既存のMVVMアーキテクチャを踏襲。新規ファイルはModels/Services/ViewModels/Viewsの適切な層に配置。

## Complexity Tracking

> No Constitution violations requiring justification.

該当なし - すべてのConstitution原則に準拠。
