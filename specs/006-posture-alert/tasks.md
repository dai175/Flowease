# Tasks: 姿勢アラート通知機能

**Input**: Design documents from `/specs/006-posture-alert/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: TDD approach per Constitution (Test-Driven Development principle)

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Models**: `Flowease/Models/`
- **Services**: `Flowease/Services/`
- **Views**: `Flowease/Views/`
- **ViewModels**: `Flowease/ViewModels/`
- **Tests**: `FloweaseTests/`
- **Localization**: `Flowease/Localizable.xcstrings`

---

## Phase 1: Setup

**Purpose**: Project structure verification (existing project)

- [X] T001 Verify project builds successfully with `make build`
- [X] T002 Verify tests pass with `make test`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core models, storage, and services that ALL user stories depend on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

### Tests for Foundational

- [X] T003 [P] Create ScoreHistoryTests in FloweaseTests/ScoreHistoryTests.swift
- [X] T004 [P] Create AlertSettingsTests in FloweaseTests/AlertSettingsTests.swift

### Models

- [X] T005 [P] Create ScoreRecord struct in Flowease/Models/ScoreRecord.swift
- [X] T006 [P] Create AlertSettings struct with validation in Flowease/Models/AlertSettings.swift
- [X] T007 [P] Create AlertState struct in Flowease/Models/AlertState.swift

### Storage

- [X] T008 Create AlertSettingsStorage in Flowease/Services/AlertSettingsStorage.swift (depends on T006)

### Core Services

- [X] T009 Create ScoreHistory class in Flowease/Services/ScoreHistory.swift (depends on T005)
- [X] T010 Create NotificationManager in Flowease/Services/NotificationManager.swift

### Localization

- [X] T011 Add alert notification strings to Flowease/Localizable.xcstrings (en/ja)

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 1 - 悪い姿勢の通知を受け取る (Priority: P1) 🎯 MVP

**Goal**: 悪い姿勢が一定期間続いた場合にmacOS通知でユーザーに気づきを与える

**Independent Test**: 姿勢スコアを意図的に60以下にして5分間維持し、通知が届くことを確認する

### Tests for User Story 1

- [X] T012 [P] [US1] Create PostureAlertServiceTests in FloweaseTests/PostureAlertServiceTests.swift
  - Test: 平均スコアが閾値以下で通知がトリガーされる
  - Test: 姿勢改善後に通知状態がリセットされる
  - Test: 最短通知間隔内は再通知されない
  - Test: データ充足率50%未満では通知判定をスキップ

### Implementation for User Story 1

- [X] T013 [US1] Create PostureAlertService in Flowease/Services/PostureAlertService.swift
  - Implement evaluate() method with notification logic
  - Implement state management (AlertState)
  - Implement data completeness check
  - Add Logger for debugging

- [X] T014 [US1] Integrate PostureAlertService into AppState in Flowease/ViewModels/AppState.swift
  - Add ScoreHistory instance
  - Add PostureAlertService instance
  - Call scoreHistory.add() when score updates
  - Call alertService.evaluate() after adding score

- [X] T015 [US1] Request notification permission at appropriate time
  - Check authorization status in NotificationManager
  - Request permission when alert is enabled and not yet authorized

- [X] T016 [US1] Verify tests pass and notification flow works end-to-end

**Checkpoint**: User Story 1 complete - core notification functionality works independently

---

## Phase 4: User Story 2 & 3 - 通知設定のカスタマイズとオン/オフ (Priority: P2)

**Goal**: ユーザーが閾値、評価期間、通知間隔を設定でき、通知機能をオン/オフできる

**Independent Test**: 設定画面で閾値を変更し、変更後の閾値で通知が発火することを確認する

### Tests for User Story 2 & 3

- [ ] T017 [P] [US2] Add settings persistence tests to FloweaseTests/AlertSettingsTests.swift
  - Test: 設定値が保存・読み込みされる
  - Test: 範囲外の値がバリデーションされる

### Implementation for User Story 2 & 3

- [ ] T018 [US2] Create AlertSettingsView in Flowease/Views/AlertSettingsView.swift
  - Toggle for enabling/disabling alerts (US3)
  - Slider for threshold (20-80)
  - Picker for evaluation period (1-10 minutes)
  - Picker for minimum interval (5-60 minutes)

- [ ] T019 [US2] Add alert settings strings to Flowease/Localizable.xcstrings (en/ja)
  - "Alert Settings" / "通知設定"
  - "Enable Alerts" / "通知を有効化"
  - "Score Threshold" / "閾値スコア"
  - "Evaluation Period" / "評価期間"
  - "Minimum Interval" / "最短通知間隔"

- [ ] T020 [US2] Integrate AlertSettingsView into StatusMenuView
  - Add navigation or section to existing menu
  - Connect to AlertSettingsStorage

- [ ] T021 [US2] Connect settings changes to PostureAlertService
  - Settings changes should immediately affect evaluation logic
  - Enable/disable should start/stop notification checks

- [ ] T022 [US2] Verify tests pass and settings UI works correctly

**Checkpoint**: User Stories 2 & 3 complete - users can customize all alert settings

---

## Phase 5: Polish & Cross-Cutting Concerns

**Purpose**: Final validation and cleanup

- [ ] T023 Run full test suite with `make test`
- [ ] T024 Run linter and formatter with `make fix`
- [ ] T025 Verify all acceptance scenarios from spec.md manually
- [ ] T026 Test edge cases:
  - App startup with no score history
  - Camera disconnection during monitoring
  - Notification permission denied
  - Settings at boundary values (20, 80, 1min, 10min, etc.)
- [ ] T027 Review and update documentation if needed

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies - verify existing project
- **Phase 2 (Foundational)**: Depends on Phase 1 - BLOCKS all user stories
- **Phase 3 (US1)**: Depends on Phase 2 completion
- **Phase 4 (US2+US3)**: Depends on Phase 2, can run parallel to Phase 3 if needed
- **Phase 5 (Polish)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Depends only on Foundational phase - no dependencies on other stories
- **User Story 2+3 (P2)**: Depends on Foundational phase - can integrate with US1 components but independently testable

### Within Each Phase

- Tests should be written FIRST (TDD per Constitution)
- Models before services
- Services before integration
- Integration before UI

### Parallel Opportunities

Within Phase 2 (Foundational):
```
Parallel group 1: T003, T004 (tests)
Parallel group 2: T005, T006, T007 (models)
Sequential: T008, T009, T010 (services depending on models)
```

Within Phase 3 (US1):
```
T012 (tests) → T013 (service) → T014 (integration) → T015, T016
```

Within Phase 4 (US2+US3):
```
T017 (tests) → T018, T019 (parallel: view, strings) → T020, T021 → T022
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup verification
2. Complete Phase 2: Foundational (models, storage, core services)
3. Complete Phase 3: User Story 1 (core notification)
4. **STOP and VALIDATE**: Test notification flow end-to-end
5. Deploy/demo if ready - basic alert functionality works with default settings

### Incremental Delivery

1. Setup + Foundational → Core infrastructure ready
2. Add User Story 1 → **MVP: Notifications work with defaults**
3. Add User Story 2+3 → **Full feature: Customizable settings**
4. Polish phase → Production ready

---

## Summary

| Phase | Tasks | Description |
|-------|-------|-------------|
| Phase 1 | 2 | Setup verification |
| Phase 2 | 9 | Foundational (models, storage, services) |
| Phase 3 | 5 | User Story 1 - Core notification (MVP) |
| Phase 4 | 6 | User Story 2+3 - Settings UI |
| Phase 5 | 5 | Polish & validation |
| **Total** | **27** | |

### Task Count by User Story

- Foundational (shared): 9 tasks
- US1 (P1 - MVP): 5 tasks
- US2+US3 (P2): 6 tasks
- Polish: 5 tasks

### MVP Scope

**Minimum Viable Product = Phase 1 + Phase 2 + Phase 3 (16 tasks)**

Users can receive posture alerts with default settings. Settings customization (Phase 4) can be added later.

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- TDD approach: Write tests first, ensure they fail, then implement
- Commit after each task or logical group
- Stop at any checkpoint to validate independently
- All new files should follow existing patterns (Logger, Sendable, etc.)
