# Tasks: 姿勢スコア表示機能

**Input**: Design documents from `/specs/001-posture-score/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, quickstart.md ✅

**Tests**: テストは Constitution (原則 III: Test-Driven Development) に基づき含めています。

**Organization**: タスクはユーザーストーリーごとにグループ化され、各ストーリーを独立して実装・テスト可能です。

## Format: `[ID] [P?] [Story] Description`

- **[P]**: 並列実行可能（異なるファイル、依存関係なし）
- **[Story]**: 所属するユーザーストーリー (US1, US2, US3, US4)
- ファイルパスは説明に含む

## Path Conventions

本プロジェクトは macOS シングルプロジェクト構成:

- **アプリ**: `Flowease/` 配下
- **テスト**: `FloweaseTests/`, `FloweaseUITests/` 配下

---

## Phase 1: Setup (共有インフラストラクチャ)

**Purpose**: プロジェクト初期化と基本構造

- [X] T001 Info.plist に NSCameraUsageDescription と LSUIElement を設定 in Flowease/Info.plist
- [X] T002 [P] Models ディレクトリを作成 in Flowease/Models/
- [X] T003 [P] Services ディレクトリを作成 in Flowease/Services/
- [X] T004 [P] ViewModels ディレクトリを作成 in Flowease/ViewModels/
- [X] T005 [P] Views ディレクトリを作成 in Flowease/Views/
- [X] T006 [P] Utilities ディレクトリを作成 in Flowease/Utilities/

---

## Phase 2: Foundational (ブロッキング前提条件)

**Purpose**: 全ユーザーストーリーの実装前に完了が必須のコアインフラ

**⚠️ CRITICAL**: このフェーズが完了するまで、ユーザーストーリーの作業は開始不可

### モデル定義（全ストーリー共通）

- [X] T007 [P] JointPosition 構造体を作成 in Flowease/Models/JointPosition.swift
- [X] T008 [P] BodyPose 構造体を作成 in Flowease/Models/BodyPose.swift
- [X] T009 [P] ScoreBreakdown 構造体を作成 in Flowease/Models/ScoreBreakdown.swift
- [X] T010 [P] PostureScore 構造体を作成 in Flowease/Models/PostureScore.swift
- [X] T011 [P] PauseReason 列挙型を作成 in Flowease/Models/PauseReason.swift
- [X] T012 [P] DisableReason 列挙型を作成 in Flowease/Models/DisableReason.swift
- [X] T013 [P] MonitoringState 列挙型を作成 in Flowease/Models/MonitoringState.swift

### ユーティリティ

- [X] T015 ColorGradient ヘルパーを作成（スコア→SwiftUI Color 変換） in Flowease/Utilities/ColorGradient.swift

**Checkpoint**: Foundation ready - ユーザーストーリーの実装を開始可能

---

## Phase 3: User Story 2 - アプリの起動と常駐 (Priority: P1) 🎯 MVP

**Goal**: メニューバーに常駐し、Dock に表示されない基本的なアプリ構造

**Independent Test**: アプリを起動し、メニューバーにアイコンが表示され、Dock に表示されないことを確認

### Implementation for User Story 2

- [X] T016 [US2] FloweaseApp を MenuBarExtra ベースに更新 in Flowease/FloweaseApp.swift
- [X] T017 [US2] StatusMenuView を作成（メニュー内容表示） in Flowease/Views/StatusMenuView.swift
- [X] T018 [US2] MenuBarView を作成（アイコン＆メニュー） in Flowease/Views/MenuBarView.swift

**Checkpoint**: User Story 2 完了 - アプリがメニューバーに常駐し、基本メニューが表示される

---

## Phase 4: User Story 3 - カメラアクセス許可の管理 (Priority: P1)

**Goal**: カメラ権限の要求、許可/拒否の状態管理、システム設定への誘導

**Independent Test**: 初回起動時の許可ダイアログと、許可/拒否それぞれのケースでの動作を確認

### Tests for User Story 3 ⚠️

> **NOTE: テストを先に書き、実装前に FAIL することを確認**

- [X] T019 [P] [US3] MonitoringState の状態遷移テストを作成 in FloweaseTests/MonitoringStateTests.swift

### Implementation for User Story 3

- [X] T020 [US3] CameraService プロトコルと実装を作成（権限チェック・要求） in Flowease/Services/CameraService.swift
- [X] T021 [US3] CameraPermissionView を作成（権限拒否時のメッセージと設定誘導） in Flowease/Views/CameraPermissionView.swift
- [ ] T022 [US3] PostureViewModel を作成（監視状態管理） in Flowease/ViewModels/PostureViewModel.swift
- [ ] T023 [US3] StatusMenuView にカメラ状態表示を統合 in Flowease/Views/StatusMenuView.swift

**Checkpoint**: User Story 3 完了 - カメラ権限フローが動作し、許可/拒否で適切な UI が表示される

---

## Phase 5: User Story 1 - リアルタイム姿勢フィードバック (Priority: P1)

**Goal**: カメラ映像から姿勢を分析し、スコアに応じてメニューバーアイコンの色を変化させる

**Independent Test**: カメラを有効にしてアプリを起動し、姿勢を変えながらアイコン色の変化を確認

### Tests for User Story 1 ⚠️

> **NOTE: テストを先に書き、実装前に FAIL することを確認**

- [ ] T024 [P] [US1] ScoreCalculator のユニットテストを作成 in FloweaseTests/ScoreCalculatorTests.swift
- [ ] T025 [P] [US1] PostureAnalyzer のモックテストを作成 in FloweaseTests/PostureAnalyzerTests.swift

### Implementation for User Story 1

- [ ] T026 [US1] CameraService にフレームキャプチャ機能を追加 in Flowease/Services/CameraService.swift
- [ ] T027 [US1] PostureAnalyzer を作成（Vision framework 姿勢分析） in Flowease/Services/PostureAnalyzer.swift
- [ ] T028 [US1] ScoreCalculator を作成（姿勢→スコア変換ロジック） in Flowease/Services/ScoreCalculator.swift
- [ ] T029 [US1] PostureViewModel にスコア更新・アイコン色管理を追加 in Flowease/ViewModels/PostureViewModel.swift
- [ ] T030 [US1] MenuBarView にスコア連動アイコン色表示を実装 in Flowease/Views/MenuBarView.swift
- [ ] T031 [US1] StatusMenuView に現在スコア表示を追加 in Flowease/Views/StatusMenuView.swift

**Checkpoint**: User Story 1 完了 - リアルタイムで姿勢スコアが計算され、アイコン色が変化する

---

## Phase 6: User Story 4 - アプリの終了 (Priority: P2)

**Goal**: メニューからアプリを終了し、カメラを適切に解放する

**Independent Test**: メニューから終了を選択し、プロセスが終了することを確認

### Implementation for User Story 4

- [ ] T032 [US4] StatusMenuView に「終了」メニュー項目を追加 in Flowease/Views/StatusMenuView.swift
- [ ] T033 [US4] CameraService にクリーンアップ処理を追加 in Flowease/Services/CameraService.swift
- [ ] T034 [US4] PostureViewModel に終了処理を追加 in Flowease/ViewModels/PostureViewModel.swift

**Checkpoint**: User Story 4 完了 - アプリが適切に終了し、リソースが解放される

---

## Phase 7: Edge Cases & エラーハンドリング

**Purpose**: エッジケース対応（spec.md の Edge Cases より）

- [ ] T035 [P] カメラ利用不可時のグレーアイコン表示を実装 in Flowease/ViewModels/PostureViewModel.swift
- [ ] T036 [P] 人物未検出時のグレーアイコン表示を実装 in Flowease/ViewModels/PostureViewModel.swift
- [ ] T037 他のアプリがカメラ使用中の検出と待機状態表示を実装 in Flowease/Services/CameraService.swift
- [ ] T038 照明条件不良時の検出と表示を実装 in Flowease/Services/PostureAnalyzer.swift

**Checkpoint**: 全エッジケースがハンドリングされ、適切な UI フィードバックが表示される

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: 複数ユーザーストーリーにまたがる改善

- [ ] T039 [P] Logger (OSLog) を全 Service/ViewModel に追加 in Flowease/Services/, Flowease/ViewModels/
- [ ] T040 [P] スコアスムージング（移動平均）を実装 in Flowease/Services/ScoreCalculator.swift
- [ ] T041 フレームスキップによるパフォーマンス最適化を実装 in Flowease/Services/CameraService.swift
- [ ] T042 メモリ管理の確認（Autorelease pool） in Flowease/Services/CameraService.swift
- [ ] T043 quickstart.md の検証を実行

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: 依存なし - 即時開始可能
- **Foundational (Phase 2)**: Setup 完了後 - 全ユーザーストーリーをブロック
- **User Story 2 (Phase 3)**: Foundational 完了後 - 基本アプリ構造
- **User Story 3 (Phase 4)**: User Story 2 完了後 - カメラ権限フロー
- **User Story 1 (Phase 5)**: User Story 3 完了後 - 姿勢分析コア機能
- **User Story 4 (Phase 6)**: User Story 1 完了後 - 終了処理
- **Edge Cases (Phase 7)**: User Story 1 完了後
- **Polish (Phase 8)**: 全ユーザーストーリー完了後

### User Story Dependencies

```
Phase 1: Setup
    │
    ▼
Phase 2: Foundational (モデル定義)
    │
    ▼
Phase 3: US2 - アプリの起動と常駐 (P1) 🎯 MVP
    │
    ▼
Phase 4: US3 - カメラアクセス許可の管理 (P1)
    │
    ▼
Phase 5: US1 - リアルタイム姿勢フィードバック (P1)
    │
    ├──────────────────┐
    ▼                  ▼
Phase 6: US4       Phase 7: Edge Cases
    │                  │
    └────────┬─────────┘
             ▼
      Phase 8: Polish
```

### Within Each User Story

- テストは実装前に書き、FAIL を確認
- モデル → サービス → ビュー の順序
- ストーリー完了後に次の優先度へ

### Parallel Opportunities

- Phase 1: 全 [P] タスク (T002-T006) を並列実行可能
- Phase 2: 全モデル定義 [P] タスク (T007-T014) を並列実行可能
- Phase 5: テストタスク (T024-T025) を並列実行可能
- Phase 7: エッジケースタスク (T035-T036) を並列実行可能
- Phase 8: ロギングとスムージング (T039-T040) を並列実行可能

---

## Parallel Example: Phase 2 (Foundational)

```bash
# 全モデルを並列で作成:
Task: "JointPosition 構造体を作成 in Flowease/Models/JointPosition.swift"
Task: "BodyPose 構造体を作成 in Flowease/Models/BodyPose.swift"
Task: "ScoreBreakdown 構造体を作成 in Flowease/Models/ScoreBreakdown.swift"
Task: "PostureScore 構造体を作成 in Flowease/Models/PostureScore.swift"
Task: "PauseReason 列挙型を作成 in Flowease/Models/PauseReason.swift"
Task: "DisableReason 列挙型を作成 in Flowease/Models/DisableReason.swift"
Task: "MonitoringState 列挙型を作成 in Flowease/Models/MonitoringState.swift"
Task: "IconColor 構造体を作成 in Flowease/Models/IconColor.swift"
```

---

## Implementation Strategy

### MVP First (User Story 2 のみ)

1. Phase 1: Setup を完了
2. Phase 2: Foundational を完了（CRITICAL - 全ストーリーをブロック）
3. Phase 3: User Story 2 を完了
4. **STOP and VALIDATE**: メニューバー常駐を独立テスト
5. デプロイ/デモ可能

### Full MVP (User Stories 1-3)

1. Setup + Foundational → Foundation ready
2. User Story 2 → テスト → 基本アプリ動作
3. User Story 3 → テスト → カメラ権限フロー
4. User Story 1 → テスト → 姿勢スコア機能 (Full MVP!)
5. User Story 4 + Edge Cases → 完全な機能セット

### Incremental Delivery

1. Phase 3 完了 → メニューバーアプリとして動作（最小 MVP）
2. Phase 4 完了 → カメラ権限フローが動作
3. Phase 5 完了 → 姿勢スコアがリアルタイム表示（コア MVP）
4. Phase 6-8 完了 → 完全な機能と品質

---

## Notes

- [P] タスク = 異なるファイル、依存関係なし
- [Story] ラベルはトレーサビリティのために各タスクをストーリーにマッピング
- 各ユーザーストーリーは独立して完了・テスト可能
- テストは実装前に FAIL を確認
- 各タスクまたは論理グループ後にコミット
- 任意のチェックポイントで停止してストーリーを独立検証可能
- 避けるべき: 曖昧なタスク、同一ファイル競合、独立性を損なうストーリー間依存
