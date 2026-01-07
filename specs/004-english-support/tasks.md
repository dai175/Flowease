# Tasks: 英語対応

**Input**: Design documents from `/specs/004-english-support/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: 本プロジェクトは TDD を採用しているため（Constitution III）、テストタスクを含む

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which phase/story this task belongs to (Setup, Shared, US1-US4, Polish)
- Include exact file paths in descriptions

## Path Conventions

- **App Source**: `Flowease/` (Models, Views, ViewModels, Services)
- **Tests**: `FloweaseTests/`
- **String Catalog**: `Flowease/Localizable.xcstrings`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and localization infrastructure setup

- [X] T001 [Setup] Create String Catalog file at Flowease/Localizable.xcstrings
- [X] T002 [Setup] Configure Xcode project in Flowease.xcodeproj/project.pbxproj: Set Development Language to English
- [X] T003 [Setup] Configure Xcode project in Flowease.xcodeproj/project.pbxproj: Add Japanese to Localizations

**Checkpoint**: String Catalog created, project configured for multi-language support

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Create localization test infrastructure that ALL user stories depend on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T004 [Shared] Create test file FloweaseTests/LocalizationTests.swift with basic test structure

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 1 - メインメニューの英語表示 (Priority: P1) 🎯 MVP

**Goal**: メニューバーポップオーバー内のテキストを英語に変更し、日本語翻訳を追加

**Independent Test**: 英語設定のmacOSでアプリを起動し、メニューバーのポップオーバー内のすべてのテキストが英語で表示されることを確認

### Tests for User Story 1 ⚠️

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [ ] T005 [US1] Add test for StatusMenuView localized strings in FloweaseTests/LocalizationTests.swift

### Implementation for User Story 1

- [ ] T006 [US1] Update Flowease/Views/StatusMenuView.swift: Change "姿勢モニタリング中" to "Monitoring Posture"
- [ ] T007 [US1] Update Flowease/Views/StatusMenuView.swift: Change "キャリブレーション:" to "Calibration:"
- [ ] T008 [US1] Update Flowease/Views/StatusMenuView.swift: Change button labels ("リセット" → "Reset", "再設定" → "Reconfigure", "設定" → "Configure")
- [ ] T009 [US1] Add Japanese translations to Flowease/Localizable.xcstrings for StatusMenuView strings (5 strings)
- [ ] T010 [US1] Run `make build` and verify StatusMenuView strings are extracted to Flowease/Localizable.xcstrings

**Checkpoint**: User Story 1 complete - メインメニューが英語表示可能

---

## Phase 4: User Story 2 - キャリブレーション画面の英語表示 (Priority: P2)

**Goal**: キャリブレーション画面のすべてのテキストを英語に変更し、日本語翻訳を追加

**Independent Test**: 英語設定でキャリブレーション画面を開き、すべての説明・ボタン・状態メッセージが英語で表示されることを確認

### Tests for User Story 2 ⚠️

- [ ] T011 [US2] Add test for CalibrationView localized strings in FloweaseTests/LocalizationTests.swift

### Implementation for User Story 2

- [ ] T012 [US2] Update Flowease/Views/CalibrationView.swift: Change title "姿勢キャリブレーション" to "Posture Calibration"
- [ ] T013 [US2] Update Flowease/Views/CalibrationView.swift: Change instruction texts to English (notCalibratedView section)
- [ ] T014 [US2] Update Flowease/Views/CalibrationView.swift: Change progress text "そのままの姿勢を維持..." to "Maintain your posture..."
- [ ] T015 [US2] Update Flowease/Views/CalibrationView.swift: Change completion messages to English (completedView section)
- [ ] T016 [US2] Update Flowease/Views/CalibrationView.swift: Change failure title "キャリブレーション失敗" to "Calibration Failed"
- [ ] T017 [US2] Update Flowease/Views/CalibrationView.swift: Change button labels ("キャンセル" → "Cancel", "開始" → "Start", "閉じる" → "Close")
- [ ] T018 [US2] Update Flowease/ViewModels/CalibrationViewModel.swift: Change qualityWarningMessage strings to English using String(localized:)
- [ ] T019 [US2] Update Flowease/ViewModels/CalibrationViewModel.swift: Change statusText, recommendationMessage, statusSummary strings to English using String(localized:)
- [ ] T020 [US2] Update Flowease/ViewModels/CalibrationViewModel.swift: Change errorMessage "予期しないエラーが発生しました" to "An unexpected error occurred"
- [ ] T021 [US2] Update Flowease/Models/CalibrationFailure.swift: Change userMessage strings to English using String(localized:)
- [ ] T022 [US2] Add Japanese translations to Flowease/Localizable.xcstrings for CalibrationView strings (10 strings)
- [ ] T023 [US2] Add Japanese translations to Flowease/Localizable.xcstrings for CalibrationViewModel strings (10 strings)
- [ ] T024 [US2] Add Japanese translations to Flowease/Localizable.xcstrings for CalibrationFailure strings (3 strings)

**Checkpoint**: User Story 2 complete - キャリブレーション画面が英語表示可能

---

## Phase 5: User Story 3 - エラーメッセージの英語表示 (Priority: P2)

**Goal**: カメラ権限エラーや顔検出失敗などのエラーメッセージを英語に変更し、日本語翻訳を追加

**Independent Test**: 英語設定でカメラ権限を拒否した状態でアプリを起動し、エラーメッセージと対処法が英語で表示されることを確認

### Tests for User Story 3 ⚠️

- [ ] T025 [US3] Add test for DisableReason and PauseReason descriptions in FloweaseTests/LocalizationTests.swift

### Implementation for User Story 3

- [ ] T026 [US3] Update Flowease/Models/DisableReason.swift: Change description strings to English using String(localized:)
- [ ] T027 [US3] Update Flowease/Models/DisableReason.swift: Change actionHint strings to English using String(localized:)
- [ ] T028 [P] [US3] Update Flowease/Models/PauseReason.swift: Change description strings to English using String(localized:)
- [ ] T029 [P] [US3] Update Flowease/Views/CameraPermissionView.swift: Change "システム設定を開く" to "Open System Settings"
- [ ] T030 [US3] Add Japanese translations to Flowease/Localizable.xcstrings for DisableReason strings (6 strings)
- [ ] T031 [US3] Add Japanese translations to Flowease/Localizable.xcstrings for PauseReason strings (4 strings)
- [ ] T032 [US3] Add Japanese translation to Flowease/Localizable.xcstrings for CameraPermissionView (1 string)

**Checkpoint**: User Story 3 complete - エラーメッセージが英語表示可能

---

## Phase 6: User Story 4 - 日付・時刻の地域フォーマット対応 (Priority: P3)

**Goal**: キャリブレーション完了日時などの日付・時刻をユーザーのロケール設定に従って表示

**Independent Test**: 英語設定でキャリブレーションを完了し、完了日時が英語圏のフォーマット（例：1/6/26, 10:30 AM）で表示されることを確認

### Implementation for User Story 4

- [ ] T033 [US4] Update Flowease/ViewModels/CalibrationViewModel.swift: Remove hardcoded Locale(identifier: "ja_JP") from DateFormatter

**Checkpoint**: User Story 4 complete - 日付・時刻がロケールに従って表示

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [ ] T034 [Polish] Run `make build` to verify all strings are extracted to Flowease/Localizable.xcstrings
- [ ] T035 [Polish] Run `make test` to verify all localization tests pass in FloweaseTests/LocalizationTests.swift
- [ ] T036 [Polish] Run `make lint` and `make format` via ./Makefile to ensure code quality
- [ ] T037 [Polish] Manual verification per specs/004-english-support/spec.md: Test in English environment (SC-001)
- [ ] T038 [Polish] Manual verification per specs/004-english-support/spec.md: Test in Japanese environment for regression (SC-002)
- [ ] T039 [Polish] Manual verification per specs/004-english-support/spec.md: Test in unsupported language environment for English fallback (SC-004)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion
- **User Story 1 (Phase 3)**: Depends on Foundational completion
- **User Story 2 (Phase 4)**: Depends on Foundational completion
- **User Story 3 (Phase 5)**: Depends on Foundational completion
- **User Story 4 (Phase 6)**: Depends on Foundational completion, **must be sequential with US2** (same file: CalibrationViewModel.swift)
- **Polish (Phase 7)**: Depends on all user stories being complete

**Note**: US1/US2/US3 all edit shared files (LocalizationTests.swift, Localizable.xcstrings), so full parallel execution is not possible. See "Parallel Opportunities" for details.

### User Story Dependencies

- **User Story 1 (P1)**: No dependencies on other stories - MVP target
- **User Story 2 (P2)**: No dependencies on other stories - independently testable
- **User Story 3 (P2)**: No dependencies on other stories - independently testable
- **User Story 4 (P3)**: **Must run after US2** (both edit CalibrationViewModel.swift)

### Within Each User Story

- Tests MUST be written and FAIL before implementation
- Tasks modifying the same file must be executed sequentially
- String Catalog updates after code changes
- Build to verify string extraction

### Parallel Opportunities

- **Source code edits only**: Implementation tasks editing different source files can run in parallel:
  - US1: StatusMenuView.swift
  - US2: CalibrationView.swift, CalibrationViewModel.swift, CalibrationFailure.swift
  - US3: DisableReason.swift, PauseReason.swift, CameraPermissionView.swift
- **Shared file constraints**: The following must be sequential across stories:
  - FloweaseTests/LocalizationTests.swift (T005, T011, T025)
  - Flowease/Localizable.xcstrings (T009, T022-024, T030-032)
- **US4 constraint**: Must run after US2 (both edit CalibrationViewModel.swift)
- **Within US3**: T028 (PauseReason.swift) and T029 (CameraPermissionView.swift) can run in parallel

---

## Parallel Example: Source Code Edits

```bash
# Source code implementation tasks can run in parallel (different files):
# Developer A works on US1 source: StatusMenuView.swift (T006-T008)
# Developer B works on US3 source: DisableReason.swift, PauseReason.swift, CameraPermissionView.swift (T026-T029)

# However, test and String Catalog tasks must be coordinated:
# - LocalizationTests.swift edits (T005, T011, T025) → sequential
# - Localizable.xcstrings edits (T009, T022-024, T030-032) → sequential

# Within US3, different source files can be updated in parallel:
Task: "Update Flowease/Models/PauseReason.swift" (T028)
Task: "Update Flowease/Views/CameraPermissionView.swift" (T029)
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T003)
2. Complete Phase 2: Foundational (T004)
3. Complete Phase 3: User Story 1 (T005-T010)
4. **STOP and VALIDATE**: Test User Story 1 independently
5. Deploy/demo if ready - basic menu is now localized

### Incremental Delivery

1. Setup + Foundational → Foundation ready
2. User Story 1 → メインメニュー英語化 (MVP!)
3. User Story 2 → キャリブレーション画面英語化
4. User Story 3 → エラーメッセージ英語化
5. User Story 4 → 日付フォーマット対応
6. Polish → 最終検証

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together
2. Once Foundational is done, source code edits can be parallelized:
   - Developer A: US1 source (T006-T008), US2 source (T012-T021), US4 (T033 after US2)
   - Developer B: US3 source (T026-T029)
3. Shared file edits must be coordinated (one developer at a time):
   - LocalizationTests.swift: T005 → T011 → T025
   - Localizable.xcstrings: T009 → T022-024 → T030-032

---

## Summary

| Phase | User Story | Task Count | Description |
|-------|-----------|------------|-------------|
| Phase 1 | Setup | 3 | Project configuration |
| Phase 2 | Foundational | 1 | Test infrastructure |
| Phase 3 | US1 (P1) 🎯 | 6 | メインメニュー英語化 |
| Phase 4 | US2 (P2) | 14 | キャリブレーション画面英語化 |
| Phase 5 | US3 (P2) | 8 | エラーメッセージ英語化 |
| Phase 6 | US4 (P3) | 1 | 日付フォーマット対応 |
| Phase 7 | Polish | 6 | 最終検証 |
| **Total** | | **39** | |

---

## Notes

- [P] tasks = different files, no dependencies (same file edits must be sequential)
- [Story] label maps task to specific phase/story (Setup, Shared, US1-US4, Polish) for traceability
- Each user story should be independently completable and testable
- Verify tests fail before implementing
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
