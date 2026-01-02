# Tasks: 姿勢キャリブレーション機能

**Input**: Design documents from `/specs/002-posture-calibration/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/

**Tests**: テストタスクを含む（plan.mdでTDD指定のため）

**Organization**: タスクはユーザーストーリーごとにグループ化し、各ストーリーを独立して実装・テスト可能にする。

## Format: `[ID] [P?] [Story] Description`

- **[P]**: 並列実行可能（異なるファイル、依存関係なし）
- **[Story]**: タスクが属するユーザーストーリー（US1, US2, US3）
- 説明には正確なファイルパスを含める

## Path Conventions

```text
Flowease/
├── Models/           # データモデル
├── Services/         # ビジネスロジック
├── ViewModels/       # ビューモデル
├── Views/            # SwiftUI Views
└── Utilities/        # ヘルパー

FloweaseTests/        # テスト
```

---

## Phase 1: Setup（プロジェクト準備）

**Purpose**: 新規ファイルの作成と基本構造の準備

- [X] T001 ブランチ`002-posture-calibration`がアクティブであることを確認

---

## Phase 2: Foundational（基盤モデル）

**Purpose**: 全ユーザーストーリーで使用される共通のデータモデルを作成

**⚠️ CRITICAL**: このフェーズが完了するまでユーザーストーリーの実装は開始不可

### Models（全ストーリー共通）

- [X] T002 [P] ReferenceJointPosition構造体を作成 in Flowease/Models/ReferenceJointPosition.swift
- [X] T003 [P] BaselineMetrics構造体を作成 in Flowease/Models/BaselineMetrics.swift
- [X] T004 [P] CalibrationProgress構造体を作成 in Flowease/Models/CalibrationProgress.swift
- [X] T005 [P] CalibrationFailure列挙型を作成 in Flowease/Models/CalibrationFailure.swift
- [X] T006 CalibrationState列挙型を作成（CalibrationProgress/Failureに依存） in Flowease/Models/CalibrationState.swift
- [X] T007 ReferencePosture構造体を作成（ReferenceJointPosition/BaselineMetricsに依存） in Flowease/Models/ReferencePosture.swift

### Storage

- [X] T008 CalibrationStorageProtocolとCalibrationStorageを作成 in Flowease/Services/CalibrationStorage.swift

### Tests for Foundational Models

- [X] T009 [P] ReferencePostureのCodableテストを作成 in FloweaseTests/ReferencePostureTests.swift
- [X] T010 [P] CalibrationStorageのテストを作成 in FloweaseTests/CalibrationStorageTests.swift

**Checkpoint**: 基盤モデル完了 - ユーザーストーリーの実装開始可能

---

## Phase 3: User Story 1 - 良い姿勢のキャリブレーション (Priority: P1) 🎯 MVP

**Goal**: ユーザーが自分の「良い姿勢」を基準として登録し、その基準に基づいて姿勢を評価

**Independent Test**: キャリブレーション実行後、姿勢スコアが個人の基準に基づいて計算されることを確認

### Tests for User Story 1 ⚠️

> **NOTE: テストを先に書き、実装前に失敗することを確認**

- [X] T011 [P] [US1] CalibrationServiceのテストを作成 in FloweaseTests/CalibrationServiceTests.swift
- [X] T012 [P] [US1] ScoreCalculatorのキャリブレーション対応テストを追加 in FloweaseTests/ScoreCalculatorTests.swift

### Services for User Story 1

- [X] T013 [US1] CalibrationServiceProtocolとCalibrationServiceを作成 in Flowease/Services/CalibrationService.swift
- [X] T014 [US1] CalibrationErrorを作成 in Flowease/Services/CalibrationService.swift
- [X] T015 [US1] ScoreCalculatorにreferencePostureプロパティを追加 in Flowease/Services/ScoreCalculator.swift
- [X] T016 [US1] ScoreCalculatorのcalculateメソッドを基準姿勢からの逸脱度計算に対応 in Flowease/Services/ScoreCalculator.swift

### ViewModels for User Story 1

- [X] T017 [US1] CalibrationViewModelを作成 in Flowease/ViewModels/CalibrationViewModel.swift
- [X] T018 [US1] PostureViewModelにキャリブレーション状態を連携 in Flowease/ViewModels/PostureViewModel.swift

### Views for User Story 1

- [X] T019 [P] [US1] CalibrationProgressViewを作成（プログレス表示コンポーネント） in Flowease/Views/CalibrationProgressView.swift
- [X] T020 [US1] CalibrationViewを作成（キャリブレーション画面） in Flowease/Views/CalibrationView.swift
- [X] T021 [US1] StatusMenuViewにキャリブレーションメニュー項目を追加 in Flowease/Views/StatusMenuView.swift

### Integration for User Story 1

- [X] T022 [US1] アプリ起動時にCalibrationStorageから基準姿勢を読み込み in Flowease/FloweaseApp.swift
- [X] T023 [US1] キャリブレーション完了後にスコア計算が基準姿勢を使用することを確認

**Checkpoint**: User Story 1完了 - キャリブレーション→スコア評価のフローが動作

---

## Phase 4: User Story 2 - キャリブレーションのリセット (Priority: P2)

**Goal**: ユーザーが座り方を変えた場合や、より良い姿勢を見つけた場合に基準姿勢を再設定

**Independent Test**: キャリブレーションをリセットし、新しい基準姿勢で評価が行われることを確認

### Tests for User Story 2 ⚠️

- [X] T024 [P] [US2] CalibrationServiceのリセット機能テストを追加 in FloweaseTests/CalibrationServiceTests.swift

### Implementation for User Story 2

- [X] T025 [US2] CalibrationServiceにresetCalibration()を実装 in Flowease/Services/CalibrationService.swift
- [X] T026 [US2] CalibrationViewModelにリセット機能を追加 in Flowease/ViewModels/CalibrationViewModel.swift
- [X] T027 [US2] StatusMenuViewにリセットメニュー項目を追加 in Flowease/Views/StatusMenuView.swift
- [X] T028 [US2] リセット後のフォールバック動作を確認（固定しきい値モード）

**Checkpoint**: User Story 2完了 - リセット→再キャリブレーションのフローが動作

---

## Phase 5: User Story 3 - キャリブレーション状態の視覚的表示 (Priority: P3)

**Goal**: ユーザーがキャリブレーションが完了しているかどうかを一目で確認

**Independent Test**: メニュー内でキャリブレーション状態が確認できることをテスト

### Implementation for User Story 3

- [X] T029 [US3] CalibrationViewModelに状態表示用のプロパティを追加 in Flowease/ViewModels/CalibrationViewModel.swift
- [X] T030 [US3] StatusMenuViewにキャリブレーション状態ラベルを追加 in Flowease/Views/StatusMenuView.swift
- [X] T031 [US3] 未キャリブレーション時の推奨メッセージを表示 in Flowease/Views/StatusMenuView.swift

**Checkpoint**: User Story 3完了 - 状態表示が動作

---

## Phase 6: Edge Cases & Error Handling

**Purpose**: エッジケースとエラーハンドリングの実装

- [X] T032 [P] 人物未検出時のエラーハンドリングを実装 in Flowease/Services/CalibrationService.swift
- [X] T033 [P] 低信頼度連続1秒での失敗判定を実装 in Flowease/Services/CalibrationService.swift
- [X] T034 [P] CalibrationViewにエラーメッセージ表示を追加 in Flowease/Views/CalibrationView.swift
- [X] T035 エッジケースのテストを追加 in FloweaseTests/CalibrationServiceTests.swift

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: 複数のユーザーストーリーに影響する改善

- [ ] T036 [P] Loggerを使用したキャリブレーションイベントのログ出力 in Flowease/Services/CalibrationService.swift
- [ ] T037 [P] SwiftLint/SwiftFormatの適用確認 via Makefile
- [ ] T038 [P] 検出品質フィードバックの追加（信頼度に応じた警告） in Flowease/Views/CalibrationView.swift
- [ ] T039 make buildでビルド成功を確認 via Makefile
- [ ] T040 make testで全テスト成功を確認 via Makefile
- [ ] T041 quickstart.mdの手順で動作確認 per specs/002-posture-calibration/quickstart.md

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: 依存なし - すぐに開始可能
- **Foundational (Phase 2)**: Setup完了後 - **全ユーザーストーリーをブロック**
- **User Stories (Phase 3-5)**: Foundational完了後に開始可能
  - P1 → P2 → P3 の順で実装（または並列実装可能）
- **Edge Cases (Phase 6)**: User Story 1完了後に開始可能
- **Polish (Phase 7)**: 全ユーザーストーリー完了後

### User Story Dependencies

- **User Story 1 (P1)**: Foundational完了後に開始可能 - 他ストーリーへの依存なし
- **User Story 2 (P2)**: Foundational完了後に開始可能 - US1と並列実装可能だが、リセットはキャリブレーション存在が前提
- **User Story 3 (P3)**: Foundational完了後に開始可能 - 状態表示のみなので独立

### Within Each User Story

- テストを先に書き、失敗を確認
- Models → Services → ViewModels → Views の順
- 各ストーリー完了後にチェックポイントで検証

### Parallel Opportunities

Phase 2の並列タスク:
```bash
# 以下のモデルを並列作成可能:
T002: ReferenceJointPosition.swift
T003: BaselineMetrics.swift
T004: CalibrationProgress.swift
T005: CalibrationFailure.swift
```

Phase 3の並列タスク:
```bash
# テストを並列作成可能:
T011: CalibrationServiceTests.swift
T012: ScoreCalculatorTests.swift

# Viewを並列作成可能:
T019: CalibrationProgressView.swift
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1: Setup完了
2. Phase 2: Foundational完了（**CRITICAL - 全ストーリーをブロック**）
3. Phase 3: User Story 1完了
4. **STOP and VALIDATE**: キャリブレーション→スコア評価フローを独立テスト
5. デプロイ/デモ可能

### Incremental Delivery

1. Setup + Foundational → 基盤完了
2. User Story 1 → 独立テスト → デプロイ/デモ (MVP!)
3. User Story 2 → 独立テスト → デプロイ/デモ
4. User Story 3 → 独立テスト → デプロイ/デモ
5. Edge Cases + Polish → 完成

---

## Notes

- [P] タスク = 異なるファイル、依存関係なし
- [Story] ラベルでタスクとユーザーストーリーの対応を追跡
- 各ユーザーストーリーは独立して完了・テスト可能
- テストは実装前に失敗することを確認
- 各タスクまたは論理グループ完了後にコミット
- 任意のチェックポイントで停止してストーリーを独立検証可能
