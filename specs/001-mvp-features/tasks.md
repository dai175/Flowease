# Tasks: Flowease MVP機能

**Input**: Design documents from `/specs/001-mvp-features/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, contracts/ ✅, quickstart.md ✅

**Tests**: テストはオプションとして記載していますが、TDDアプローチを推奨します

**Organization**: タスクはユーザーストーリーごとにグループ化され、各ストーリーを独立して実装・テスト可能です

## Format: `[ID] [P?] [Story] Description`

- **[P]**: 並列実行可能（異なるファイル、依存関係なし）
- **[Story]**: どのユーザーストーリーに属するか（US1, US2, US3, US4）
- 説明には正確なファイルパスを含む

## Path Conventions

```
Flowease/
├── App/                  # アプリエントリーポイント
├── Models/               # データモデル
├── Services/             # ビジネスロジック
├── Views/                # SwiftUI ビュー
├── Resources/            # アセット、Info.plist
└── Utilities/            # ヘルパー
FloweaseTests/            # ユニットテスト
FloweaseUITests/          # UIテスト
```

---

## Phase 1: Setup (プロジェクト初期設定)

**Purpose**: プロジェクト構造の作成と基本設定

- [x] T001 Flowease/Utilities/Constants.swift に定数定義ファイルを作成
- [x] T002 [P] Flowease/Resources/Info.plist にカメラ使用理由とLSUIElementを設定
- [x] T003 [P] Flowease/Resources/Assets.xcassets/StatusBarIcon/ にメニューバーアイコン（緑/黄/赤）を追加

---

## Phase 2: Foundational (基盤インフラ)

**Purpose**: 全てのユーザーストーリーが依存するコアインフラストラクチャ

**⚠️ CRITICAL**: このフェーズが完了するまでユーザーストーリーの実装は開始できません

### Models (全ストーリー共通)

- [x] T004 [P] Flowease/Models/PostureState.swift に PostureLevel enum と PostureState struct を作成
- [x] T005 [P] Flowease/Models/BreakReminder.swift に BreakReminder struct を作成
- [x] T006 [P] Flowease/Models/Stretch.swift に StretchCategory enum と Stretch struct を作成
- [x] T007 [P] Flowease/Models/UserSettings.swift に UserSettings struct を作成
- [x] T008 [P] Flowease/Models/CameraDevice.swift に CameraDevice struct を作成
- [x] T009 [P] Flowease/Models/StretchSession.swift に StretchSession struct を作成

### Error Definitions

- [x] T010 [P] Flowease/Services/Errors/PostureDetectionError.swift にエラー定義を作成
- [x] T011 [P] Flowease/Services/Errors/CameraError.swift にエラー定義を作成
- [x] T012 [P] Flowease/Services/Errors/NotificationError.swift にエラー定義を作成

### Service Protocols

- [x] T013 [P] Flowease/Services/Protocols/PostureDetectionServiceProtocol.swift にプロトコルを作成
- [x] T014 [P] Flowease/Services/Protocols/CameraServiceProtocol.swift にプロトコルを作成
- [x] T015 [P] Flowease/Services/Protocols/NotificationServiceProtocol.swift にプロトコルを作成
- [x] T016 [P] Flowease/Services/Protocols/SettingsServiceProtocol.swift にプロトコルを作成
- [x] T017 [P] Flowease/Services/Protocols/BreakReminderServiceProtocol.swift にプロトコルを作成
- [x] T018 [P] Flowease/Services/Protocols/StretchServiceProtocol.swift にプロトコルを作成

### Core Services (全ストーリー共通)

- [x] T019 Flowease/Services/SettingsService.swift に UserDefaults 連携の設定サービスを実装
- [x] T020 Flowease/Services/ServiceContainer.swift に依存性注入コンテナを作成

**Checkpoint**: 基盤完了 - ユーザーストーリーの実装を開始可能

---

## Phase 3: User Story 4 - メニューバー常駐UI (Priority: P4) 🏗️ UI基盤

**Goal**: 作業の邪魔にならない形でアプリの状態を確認できるメニューバーUIを提供

**Independent Test**: アプリを起動し、メニューバーにアイコンが表示されること、クリックでポップオーバーが表示されることを確認

**Note**: UI基盤として他のストーリーより先に実装が必要

### Implementation for User Story 4

- [ ] T021 [US4] Flowease/App/AppDelegate.swift に NSStatusBar/NSPopover 管理を実装
- [ ] T022 [US4] Flowease/App/FloweaseApp.swift に @main エントリーポイントを実装（Settings Scene含む）
- [ ] T023 [P] [US4] Flowease/Views/MenuBar/StatusBarView.swift にステータスバーアイコン管理を実装
- [ ] T024 [US4] Flowease/Views/MenuBar/PopoverView.swift にポップオーバーUIを実装（姿勢スコア、次の休憩時間、ストレッチボタン、設定ボタン）
- [ ] T025 [US4] Flowease/Views/Settings/SettingsView.swift に設定画面を実装（カメラ選択、休憩間隔、姿勢感度）

**Checkpoint**: メニューバーUI完成 - アイコンクリックでポップオーバー表示可能

---

## Phase 4: User Story 1 - 姿勢検知と警告 (Priority: P1) 🎯 MVP

**Goal**: 姿勢が悪くなった時に通知を受け、早めに修正できる

**Independent Test**: カメラを有効にした状態で意図的に前かがみになり、姿勢警告通知が表示されることを確認

### Tests for User Story 1 (Optional) ⚠️

- [ ] T026 [P] [US1] FloweaseTests/Services/PostureDetectionServiceTests.swift に姿勢検知テストを作成
- [ ] T027 [P] [US1] FloweaseTests/Models/PostureStateTests.swift に姿勢状態モデルテストを作成

### Implementation for User Story 1

- [ ] T028 [US1] Flowease/Services/CameraService.swift に AVFoundation カメラ連携を実装
- [ ] T029 [US1] Flowease/Services/PostureDetectionService.swift に Vision Framework 姿勢検知を実装
- [ ] T030 [US1] Flowease/Services/NotificationService.swift に姿勢警告通知を実装
- [ ] T031 [US1] AppDelegate.swift にカメラ権限リクエストと姿勢検知開始を統合
- [ ] T032 [US1] PopoverView.swift に姿勢スコアのリアルタイム表示を統合
- [ ] T033 [US1] StatusBarView.swift にアイコン色変更（緑/黄/赤）を統合

**Checkpoint**: 姿勢検知MVP完成 - 悪い姿勢で通知が表示される

---

## Phase 5: User Story 2 - 休憩リマインダー (Priority: P2)

**Goal**: 一定時間作業したら休憩を促す通知を受け、長時間連続作業による体への負担を軽減

**Independent Test**: アプリを起動し設定した時間（例：30分）経過後に休憩通知が表示されることを確認

### Tests for User Story 2 (Optional) ⚠️

- [ ] T034 [P] [US2] FloweaseTests/Services/BreakReminderServiceTests.swift に休憩リマインダーテストを作成

### Implementation for User Story 2

- [ ] T035 [US2] Flowease/Services/BreakReminderService.swift に休憩タイマーとスヌーズ機能を実装
- [ ] T036 [US2] Flowease/Services/NotificationService.swift に休憩リマインダー通知（アクション付き）を追加
- [ ] T037 [US2] Flowease/Views/PopoverView.swift に次の休憩までの残り時間表示を追加
- [ ] T038 [US2] Flowease/Views/SettingsView.swift に休憩間隔設定（30-60分）を追加

**Checkpoint**: 休憩リマインダー完成 - 設定時間後に休憩通知が表示される

---

## Phase 6: User Story 3 - ストレッチガイド (Priority: P3)

**Goal**: 休憩時に適切なストレッチを教えてもらい、効果的に体をほぐす

**Independent Test**: メニューバーから「今すぐストレッチ」を選択し、ストレッチガイドのアニメーションとタイマーが正しく表示・動作することを確認

### Implementation for User Story 3

- [ ] T039 [P] [US3] Flowease/Services/StretchService.swift にストレッチセッション管理を実装
- [ ] T040 [P] [US3] Flowease/Views/Stretch/StretchGuideView.swift にストレッチガイドUIを実装
- [ ] T041 [US3] Flowease/Views/Stretch/StretchAnimationView.swift にストレッチアニメーションを実装
- [ ] T042 [US3] Flowease/Views/PopoverView.swift に「今すぐストレッチ」ボタンを追加
- [ ] T043 [US3] 休憩通知のアクションからストレッチガイドを開始する連携を実装

**Checkpoint**: ストレッチガイド完成 - ストレッチセッションが正常に動作

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: 全ストーリーに影響する改善

- [ ] T044 [P] 全サービスにエラーハンドリングとロギングを追加
- [ ] T045 [P] FloweaseUITests/MenuBarUITests.swift にUIテストを作成
- [ ] T046 顔が映っていない場合のメニューバーアイコングレー表示を実装
- [ ] T047 Macスリープ復帰時のアプリ動作再開を実装
- [ ] T048 quickstart.md に従って全機能の動作確認を実施

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: 依存関係なし - すぐに開始可能
- **Foundational (Phase 2)**: Setup完了後 - 全ユーザーストーリーをブロック
- **User Story 4 (Phase 3)**: Foundational完了後 - UI基盤として他より先に必要
- **User Story 1 (Phase 4)**: Phase 3完了後 - MVPのコア機能
- **User Story 2 (Phase 5)**: Phase 4と並行可能だが、Phase 3に依存
- **User Story 3 (Phase 6)**: Phase 5と連携するが独立してテスト可能
- **Polish (Phase 7)**: 全ユーザーストーリー完了後

### User Story Dependencies

```
[Phase 1: Setup]
       ↓
[Phase 2: Foundational] ← 全ストーリーの前提条件
       ↓
[Phase 3: US4 - MenuBar UI] ← UI基盤
       ↓
[Phase 4: US1 - 姿勢検知] ← MVP Core
       ↓
[Phase 5: US2 - 休憩リマインダー]
       ↓
[Phase 6: US3 - ストレッチガイド]
       ↓
[Phase 7: Polish]
```

### Within Each User Story

- テスト（含まれる場合）は実装前に作成し、FAILを確認
- モデル → サービス → UI統合 の順
- ストーリー完了後、次の優先度へ移動

### Parallel Opportunities

- Phase 1: T002, T003 は並列実行可能
- Phase 2: T004-T018 は全て並列実行可能（異なるファイル）
- 各ストーリー内で [P] マークのタスクは並列実行可能

---

## Parallel Example: Phase 2 (Foundational)

```bash
# 全モデルを並列で作成:
Task: "T004 Flowease/Models/PostureState.swift"
Task: "T005 Flowease/Models/BreakReminder.swift"
Task: "T006 Flowease/Models/Stretch.swift"
Task: "T007 Flowease/Models/UserSettings.swift"
Task: "T008 Flowease/Models/CameraDevice.swift"
Task: "T009 Flowease/Models/StretchSession.swift"

# 全プロトコルを並列で作成:
Task: "T013 Flowease/Services/Protocols/PostureDetectionServiceProtocol.swift"
Task: "T014 Flowease/Services/Protocols/CameraServiceProtocol.swift"
...
```

---

## Implementation Strategy

### MVP First (User Story 1 のみ)

1. Phase 1: Setup を完了
2. Phase 2: Foundational を完了（CRITICAL - 全ストーリーをブロック）
3. Phase 3: User Story 4 (MenuBar UI) を完了
4. Phase 4: User Story 1 (姿勢検知) を完了
5. **STOP and VALIDATE**: 姿勢検知を独立してテスト
6. 準備ができたらデプロイ/デモ

### Incremental Delivery

1. Setup + Foundational + US4 完了 → UI基盤完成
2. US1 追加 → 独立テスト → デプロイ/デモ (MVP!)
3. US2 追加 → 独立テスト → デプロイ/デモ
4. US3 追加 → 独立テスト → デプロイ/デモ
5. 各ストーリーは前のストーリーを壊さずに価値を追加

---

## Notes

- [P] タスク = 異なるファイル、依存関係なし
- [Story] ラベルはタスクを特定のユーザーストーリーにマッピング
- 各ユーザーストーリーは独立して完了・テスト可能であるべき
- 実装前にテストがFAILすることを確認
- 各タスクまたは論理グループ後にコミット
- 任意のチェックポイントで停止してストーリーを独立して検証可能
- 避けるべき: 曖昧なタスク、同一ファイルの競合、独立性を損なうクロスストーリー依存
