# Implementation Plan: 顔検出ベースの姿勢検知

**Branch**: `003-face-detection` | **Date**: 2026-01-02 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/003-face-detection/spec.md`

## Summary

現在の体検出（VNDetectHumanBodyPoseRequest）を顔検出（VNDetectFaceRectanglesRequest + VNDetectFaceCaptureQualityRequest）に置き換え、デスクトップ環境での検出安定性を向上させる。顔の位置・サイズ・傾き（roll角）から姿勢スコアを算出し、既存のキャリブレーション・スコア表示機能との互換性を維持する。

## Technical Context

**Language/Version**: Swift 6.0
**Primary Dependencies**: Vision Framework (VNDetectFaceRectanglesRequest, VNDetectFaceCaptureQualityRequest), AVFoundation, SwiftUI
**Storage**: UserDefaults (既存のCalibrationStorage経由)
**Testing**: XCTest
**Target Platform**: macOS 14.6+
**Project Type**: Single macOS menu bar application
**Performance Goals**: 30FPSカメラ入力に対し2フレームに1回処理（15FPS）でスコア更新
**Constraints**: 検出成功率95%以上、2秒以内のスコア反映
**Scale/Scope**: 単一ユーザー、単一カメラ

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. SwiftUI-First Architecture | ✅ Pass | UI変更なし、既存View構造を維持 |
| II. Type Safety & Memory Safety | ✅ Pass | 新規エンティティはnon-optional設計、VNFaceObservationのプロパティは適切にunwrap |
| III. Test-Driven Development | ✅ Pass | 新規ScoreCalculator/PostureAnalyzerロジックにユニットテスト追加 |
| IV. User Experience Excellence | ✅ Pass | 既存UXを維持、検出失敗時のフィードバック改善 |
| V. Observability & Debugging | ✅ Pass | 既存Loggerパターンを継続使用 |
| VI. Code Quality Gates | ✅ Pass | SwiftLint/SwiftFormat準拠 |

**Gate Result**: PASS - 設計フェーズに進行可能

## Project Structure

### Documentation (this feature)

```text
specs/003-face-detection/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (N/A - no API contracts)
└── tasks.md             # Phase 2 output
```

### Source Code (repository root)

```text
Flowease/
├── Models/
│   ├── FacePosition.swift         # NEW: 顔位置データ
│   ├── FaceBaselineMetrics.swift  # NEW: 顔ベース基準値
│   ├── FaceReferencePosture.swift # NEW: 顔ベースキャリブレーションデータ
│   ├── ScoreBreakdown.swift       # MODIFY: 3項目評価に変更
│   ├── PauseReason.swift          # MODIFY: メッセージ変更
│   ├── ReferencePosture.swift     # DELETE: FaceReferencePostureで置き換え
│   ├── BaselineMetrics.swift      # DELETE: FaceBaselineMetricsで置き換え
│   └── ... (その他は変更なし)
├── Services/
│   ├── FaceDetector.swift         # NEW: 顔検出サービス
│   ├── FaceScoreCalculator.swift  # NEW: 顔ベーススコア計算
│   ├── PostureAnalyzer.swift      # MODIFY: 顔検出に切り替え
│   ├── CalibrationService.swift   # MODIFY: 顔ベースキャリブレーション
│   ├── CalibrationStorage.swift   # MODIFY: データ形式判定・クリア
│   └── ... (既存サービス)
├── ViewModels/
│   └── PostureViewModel.swift     # MODIFY: 顔検出結果処理
└── Views/
    └── ... (変更なし)

FloweaseTests/
├── FacePositionTests.swift           # NEW
├── FaceBaselineMetricsTests.swift    # NEW
├── FaceReferencePostureTests.swift   # NEW
├── FaceDetectorTests.swift           # NEW
├── FaceScoreCalculatorTests.swift    # NEW
├── CalibrationServiceTests.swift     # MODIFY: 顔ベースケース追加
├── CalibrationStorageTests.swift     # MODIFY: 形式判定テスト追加
└── ... (既存テスト)
```

**Structure Decision**: 既存のMVVM構造を維持。顔検出関連は新規ファイルとして追加し、既存ファイルは最小限の変更で対応。

## Complexity Tracking

> 違反なし - Constitution Checkに合格
