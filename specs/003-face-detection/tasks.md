# Tasks: 顔検出ベースの姿勢検知

**Input**: Design documents from `/specs/003-face-detection/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: ユニットテストをTDD形式で実装（plan.mdのConstitution Check: "III. Test-Driven Development"に従う）

**TDD方針**:
- Phase 1/2: 基本構造のみ作成（スタブ/プロトコル定義）、TDD対象外
- Phase 3以降: 各ユーザーストーリー内でテスト→実装の順序を厳守

**Organization**: タスクはユーザーストーリーごとにグループ化し、独立した実装・テストを可能にする

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: 並列実行可能（異なるファイル、依存なし）
- **[Story]**: タスクが属するユーザーストーリー（US1, US2, US3）
  - Phase 1 (Setup) / Phase 2 (Foundational): [Story]ラベル不要
  - Phase 3以降 (User Stories): [Story]ラベル必須
- 説明には正確なファイルパスを含む

## Path Conventions

- **Models**: `Flowease/Models/`
- **Services**: `Flowease/Services/`
- **ViewModels**: `Flowease/ViewModels/`
- **Tests**: `FloweaseTests/`

---

## Phase 1: Setup（基盤準備）

**Purpose**: 新規モデルの基本構造作成（スタブ）

**Note**: TDD対象外。プロパティ定義とCodable/Sendable準拠のみ。詳細ロジックはUS1/US2で実装。

- [X] T001 [P] Create FacePosition struct stub (properties only) in Flowease/Models/FacePosition.swift
- [X] T002 [P] Create FaceBaselineMetrics struct stub (properties only) in Flowease/Models/FaceBaselineMetrics.swift
- [X] T003 [P] Create FaceReferencePosture struct stub (properties only) in Flowease/Models/FaceReferencePosture.swift

---

## Phase 2: Foundational（ブロッキング前提条件）

**Purpose**: すべてのユーザーストーリーが依存するコアインフラストラクチャ

**⚠️ CRITICAL**: このフェーズが完了するまでユーザーストーリーの作業は開始不可

**Note**: TDD対象外。既存ファイル修正とサービス基本構造のみ。詳細ロジックはUS1で実装。T004/T005完了後は `make test` で既存テストの回帰確認を行うこと。

- [X] T004 Modify ScoreBreakdown to 3-item evaluation (verticalPosition, sizeChange, tilt) in Flowease/Models/ScoreBreakdown.swift
- [X] T005 Modify PauseReason to rename noPersonDetected to noFaceDetected and update messages in Flowease/Models/PauseReason.swift
- [X] T006 Create FaceDetector service stub (method signatures only) in Flowease/Services/FaceDetector.swift
- [X] T007 Create FaceScoreCalculator service stub (method signatures only) in Flowease/Services/FaceScoreCalculator.swift

**Checkpoint**: 基盤準備完了 - ユーザーストーリーの実装を開始可能

---

## Phase 3: User Story 1 - 安定した姿勢検知 (Priority: P1) 🎯 MVP

**Goal**: 顔が映っている限り姿勢検知が途切れず、リアルタイムでスコアが算出される

**Independent Test**: カメラの前で様々な姿勢を取りながら、検出が途切れないことを確認

### Tests for User Story 1 ⚠️

> **NOTE: これらのテストを先に書き、実装前にFAILすることを確認**

- [X] T008 [P] [US1] Create FacePositionTests for model validation in FloweaseTests/FacePositionTests.swift
- [X] T009 [P] [US1] Create FaceDetectorTests for face detection logic in FloweaseTests/FaceDetectorTests.swift
- [X] T010 [P] [US1] Create FaceScoreCalculatorTests for score calculation in FloweaseTests/FaceScoreCalculatorTests.swift

### Implementation for User Story 1

- [X] T011 [US1] Implement FacePosition validation (centerX/Y bounds, area bounds, roll range) in Flowease/Models/FacePosition.swift
- [X] T012 [US1] Implement FaceDetector.detect() with VNDetectFaceRectanglesRequest in Flowease/Services/FaceDetector.swift
- [X] T013 [US1] Implement FaceDetector.findMatchingQuality() with VNDetectFaceCaptureQualityRequest in Flowease/Services/FaceDetector.swift
- [X] T014 [US1] Implement FaceDetector.selectLargestFace() for multiple face handling in Flowease/Services/FaceDetector.swift
- [X] T015 [US1] Implement FaceScoreCalculator vertical position score (Y coordinate deviation) in Flowease/Services/FaceScoreCalculator.swift
- [X] T016 [US1] Implement FaceScoreCalculator size change score (area ratio) in Flowease/Services/FaceScoreCalculator.swift
- [X] T017 [US1] Implement FaceScoreCalculator tilt score with roll wrap-around in Flowease/Services/FaceScoreCalculator.swift
- [X] T018 [US1] Modify PostureAnalyzer to use FaceDetector instead of body pose detection in Flowease/Services/PostureAnalyzer.swift
- [X] T019 [US1] Modify PostureViewModel to handle FacePosition and face-based scoring in Flowease/ViewModels/PostureViewModel.swift
- [X] T020 [US1] Implement pause state transition for noFaceDetected with score history clear (moving average buffer reset) in Flowease/ViewModels/PostureViewModel.swift
- [X] T021 [US1] Implement pause state transition for lowDetectionQuality (captureQuality < 0.3) with score history clear in Flowease/ViewModels/PostureViewModel.swift

**Checkpoint**: User Story 1完了 - 顔検出によるリアルタイムスコア算出が動作

---

## Phase 4: User Story 2 - 顔ベースの姿勢キャリブレーション (Priority: P1)

**Goal**: 顔の位置・大きさ・傾きを基準として記録し、その基準からの逸脱で評価

**Independent Test**: キャリブレーション実行後、前かがみになった際にスコアが下がることを確認

### Tests for User Story 2 ⚠️

- [X] T022 [P] [US2] Create FaceBaselineMetricsTests for baseline validation in FloweaseTests/FaceBaselineMetricsTests.swift
- [X] T023 [P] [US2] Create FaceReferencePostureTests for posture validation in FloweaseTests/FaceReferencePostureTests.swift
- [X] T024 [P] [US2] Extend CalibrationServiceTests for face-based calibration in FloweaseTests/CalibrationServiceTests.swift

### Implementation for User Story 2

- [X] T025 [US2] Implement FaceBaselineMetrics with NaN/Infinite sanitization in Flowease/Models/FaceBaselineMetrics.swift
- [X] T026 [US2] Implement FaceReferencePosture.isValid validation in Flowease/Models/FaceReferencePosture.swift
- [X] T027 [US2] Modify CalibrationService to accumulate FacePosition frames in Flowease/Services/CalibrationService.swift
- [X] T028 [US2] Modify CalibrationService to calculate FaceBaselineMetrics from accumulated frames in Flowease/Services/CalibrationService.swift
- [X] T029 [US2] Modify CalibrationService to create FaceReferencePosture on calibration complete in Flowease/Services/CalibrationService.swift
- [X] T030 [US2] Integrate FaceScoreCalculator with FaceBaselineMetrics for deviation calculation in Flowease/Services/FaceScoreCalculator.swift

**Checkpoint**: User Story 2完了 - 顔ベースキャリブレーションが動作

---

## Phase 5: User Story 3 - 既存機能との互換性維持 (Priority: P2)

**Goal**: 既存のUX（メニューバー、色変化、データ永続化）を維持

**Independent Test**: アプリ再起動後もキャリブレーションデータが保持されることを確認

### Tests for User Story 3 ⚠️

- [X] T031 [P] [US3] Extend CalibrationStorageTests for data format detection in FloweaseTests/CalibrationStorageTests.swift

### Implementation for User Story 3

- [X] T032 [US3] Modify CalibrationStorage.load() to detect and clear old format data in Flowease/Services/CalibrationStorage.swift
- [X] T033 [US3] Modify CalibrationStorage.save() to encode FaceReferencePosture in Flowease/Services/CalibrationStorage.swift
- [X] T034 [US3] Verify menu bar icon color gradient works with face-based scores in Flowease/ViewModels/PostureViewModel.swift
- [X] T035 [US3] Verify tooltip message displays correctly for face detection states in Flowease/ViewModels/PostureViewModel.swift

**Checkpoint**: User Story 3完了 - 既存UXとの互換性確認

---

## Phase 6: Cleanup & Polish

**Purpose**: 不要コードの削除と最終整備

**⚠️ 削除前提条件**: T036-T040の削除タスクは、US1/US2/US3がすべて動作確認済みであることが前提。削除前に `make test` が全件PASSすることを確認すること。

- [ ] T036 Delete ReferencePosture.swift after verifying no references in Flowease/Models/ReferencePosture.swift
- [ ] T037 Delete BaselineMetrics.swift after verifying no references in Flowease/Models/BaselineMetrics.swift
- [ ] T038 Delete ReferenceJointPosition.swift after verifying no references in Flowease/Models/ReferenceJointPosition.swift
- [ ] T039 Review and delete BodyPose.swift if unused after migration in Flowease/Models/BodyPose.swift
- [ ] T040 Review and delete JointPosition.swift if unused after migration in Flowease/Models/JointPosition.swift
- [ ] T041 Run `make lint` and fix any SwiftLint warnings
- [ ] T042 Run `make format` and commit formatting changes
- [ ] T043 Run `make test` and verify all tests pass
- [ ] T044 Manual validation per quickstart.md Testing Checklist

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: 依存なし - 即時開始可能
- **Foundational (Phase 2)**: Setup完了後 - すべてのユーザーストーリーをブロック
- **User Stories (Phase 3-5)**: Foundational完了後
  - US1とUS2は並列実行可能（両方P1）
  - US3はUS1/US2完了後（P2）
- **Cleanup (Phase 6)**: すべてのユーザーストーリー完了後

### User Story Dependencies

- **User Story 1 (P1)**: Phase 2完了後に開始可能 - 他のストーリーに依存なし
- **User Story 2 (P1)**: Phase 2完了後に開始可能 - US1と並列実行可能
- **User Story 3 (P2)**: Phase 2完了後に開始可能 - US1/US2の統合テストを含むため、それらの完了後を推奨

### Within Each User Story

- テストは実装前に書き、FAILすることを確認
- モデル → サービス → ビューモデルの順序で実装
- ストーリー完了後に次の優先度へ移行

### Parallel Opportunities

- Phase 1: T001, T002, T003 は並列実行可能
- Phase 3: T008, T009, T010 は並列実行可能
- Phase 4: T022, T023, T024 は並列実行可能
- Phase 5: T031 は単独
- US1とUS2は異なる開発者で並列実行可能

---

## Parallel Example: Phase 1 Setup

```bash
# 全モデルを並列で作成:
Task: "Create FacePosition model in Flowease/Models/FacePosition.swift"
Task: "Create FaceBaselineMetrics model in Flowease/Models/FaceBaselineMetrics.swift"
Task: "Create FaceReferencePosture model in Flowease/Models/FaceReferencePosture.swift"
```

## Parallel Example: User Story 1 Tests

```bash
# US1のテストを並列で作成:
Task: "Create FacePositionTests in FloweaseTests/FacePositionTests.swift"
Task: "Create FaceDetectorTests in FloweaseTests/FaceDetectorTests.swift"
Task: "Create FaceScoreCalculatorTests in FloweaseTests/FaceScoreCalculatorTests.swift"
```

---

## Implementation Strategy

### MVP First (User Story 1のみ)

1. Phase 1: Setup完了
2. Phase 2: Foundational完了（CRITICAL - 全ストーリーをブロック）
3. Phase 3: User Story 1完了
4. **STOP and VALIDATE**: US1を独立テスト
5. 顔検出による基本的な姿勢監視が動作

### Incremental Delivery

1. Setup + Foundational → 基盤準備完了
2. User Story 1追加 → 独立テスト → MVP完成（顔検出スコア）
3. User Story 2追加 → 独立テスト → キャリブレーション機能追加
4. User Story 3追加 → 独立テスト → 既存UX互換性確認
5. Cleanup → 旧コード削除 → リリース準備完了

### Parallel Team Strategy

複数開発者がいる場合:

1. チームでSetup + Foundational完了
2. Foundational完了後:
   - Developer A: User Story 1（顔検出・スコア算出）
   - Developer B: User Story 2（キャリブレーション）
3. US1/US2完了後: User Story 3（互換性確認）
4. 全員: Cleanup

---

## Notes

- [P]タスク = 異なるファイル、依存なし
- [Story]ラベルはタスクを特定のユーザーストーリーにマッピング
- 各ユーザーストーリーは独立して完了・テスト可能であること
- テストがFAILすることを確認してから実装
- タスクまたは論理グループごとにコミット
- チェックポイントで停止してストーリーを独立検証可能
- 回避: 曖昧なタスク、同一ファイルの競合、独立性を損なうストーリー間依存
