# Tasks: カメラ選択機能

**Input**: Design documents from `/specs/005-camera-selection/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: Constitution に TDD が含まれているため、テストタスクを含めます。

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

Based on plan.md structure:
- **Source**: `Flowease/` (macOS app source)
- **Tests**: `FloweaseTests/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: 新規ファイルの作成と基本構造のセットアップ

- [x] T001 [P] Create CameraDevice model in Flowease/Models/CameraDevice.swift
- [x] T002 [P] Create CameraDeviceManager internal service in Flowease/Services/CameraDeviceManager.swift
- [x] T003 [P] Create CameraSelectionView component in Flowease/Views/CameraSelectionView.swift

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: すべてのUser Storyが依存する基盤機能

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T004 Extend CameraServiceProtocol with availableCameras, selectedCameraID, selectCamera(_:) in Flowease/Services/CameraService.swift
- [ ] T005 Add PauseReason.selectedCameraDisconnected case in Flowease/Models/PauseReason.swift
- [ ] T006 Implement CameraDeviceManager skeleton with DiscoverySession initialization (structure only, no enumeration logic yet) in Flowease/Services/CameraDeviceManager.swift
- [ ] T007 Integrate CameraDeviceManager into CameraService in Flowease/Services/CameraService.swift

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 1 - カメラの選択 (Priority: P1) 🎯 MVP

**Goal**: ユーザーが複数のカメラから使用するカメラを選択でき、選択が永続化される

**Independent Test**: カメラ選択メニューからカメラを選択し、選択したカメラで姿勢モニタリングが動作することを確認

**Acceptance Criteria**:
- FR-001: すべてのビデオキャプチャデバイスを一覧表示
- FR-002: 一覧からカメラを選択可能
- FR-003: 選択を永続化（UserDefaults）
- FR-008: アプリのメニューからアクセス可能
- FR-009: デバイス名で識別可能
- FR-010: 選択中のカメラを視覚的に区別

### Tests for User Story 1

- [ ] T008 [P] [US1] Test CameraDevice model equality and Sendable conformance in FloweaseTests/CameraDeviceTests.swift
- [ ] T009 [P] [US1] Test CameraService.selectCamera() and persistence in FloweaseTests/CameraServiceTests.swift
- [ ] T010 [P] [US1] Test camera fallback logic (selected camera unavailable → system default) in FloweaseTests/CameraServiceTests.swift

### Implementation for User Story 1

- [ ] T011 [US1] Implement CameraDevice model with id, name, isConnected, isDefault in Flowease/Models/CameraDevice.swift
- [ ] T012 [US1] Implement camera enumeration logic (populate availableCameras from DiscoverySession.devices) in Flowease/Services/CameraDeviceManager.swift
- [ ] T013 [US1] Implement selectCamera(_:) with UserDefaults persistence in Flowease/Services/CameraService.swift
- [ ] T014 [US1] Implement camera fallback logic (resolveCamera with didFallback flag) in Flowease/Services/CameraService.swift
- [ ] T015 [US1] Implement CameraSelectionView with Picker and visual selection indicator in Flowease/Views/CameraSelectionView.swift
- [ ] T016 [US1] Integrate CameraSelectionView into StatusMenuView (authorized only) in Flowease/Views/StatusMenuView.swift
- [ ] T017 [US1] Add logging for camera selection events in Flowease/Services/CameraService.swift

**Checkpoint**: User Story 1 should be fully functional - カメラ選択と永続化が動作

---

## Phase 4: User Story 2 - カメラの切断・再接続 (Priority: P2)

**Goal**: カメラ切断時に適切なフィードバックを表示し、再接続時に自動復帰する

**Independent Test**: 外部カメラを抜き差しして、切断時にモニタリングが一時停止し、再接続時に再開されることを確認

**Acceptance Criteria**:
- FR-004: カメラ利用不可時にメニュー内ステータス表示で通知
- FR-005: カメラの接続・切断をリアルタイムで検知
- FR-006: 選択カメラ切断時にモニタリング一時停止
- FR-007: 再接続時に自動再開

### Tests for User Story 2

- [ ] T018 [P] [US2] Test device disconnection detection in CameraDeviceManager in FloweaseTests/CameraDeviceManagerTests.swift
- [ ] T019 [P] [US2] Test auto-resume on reconnection in CameraService in FloweaseTests/CameraServiceTests.swift
- [ ] T020 [P] [US2] Test PauseReason.selectedCameraDisconnected handling in FloweaseTests/MonitoringStateTests.swift

### Implementation for User Story 2

- [ ] T021 [US2] Implement KVO observation for device list changes (detect connect/disconnect events, notify CameraService) in Flowease/Services/CameraDeviceManager.swift
- [ ] T022 [US2] Implement device disconnection detection and notification in Flowease/Services/CameraService.swift
- [ ] T023 [US2] Implement MonitoringState transition to .paused(.selectedCameraDisconnected) in Flowease/Services/CameraService.swift
- [ ] T024 [US2] Implement auto-resume on selected camera reconnection in Flowease/Services/CameraService.swift
- [ ] T025 [US2] Update StatusMenuView to show disconnection feedback and fallback notification (FR-004) in Flowease/Views/StatusMenuView.swift
- [ ] T026 [US2] Update CameraSelectionView to show real-time device list updates in Flowease/Views/CameraSelectionView.swift
- [ ] T027 [US2] Add logging for disconnect/reconnect events in Flowease/Services/CameraService.swift

**Checkpoint**: User Stories 1 AND 2 should both work independently

---

## Phase 5: User Story 3 - シングルカメラ環境 (Priority: P3)

**Goal**: カメラが1台のみでも一貫した動作を保証する

**Independent Test**: カメラが1台のみの環境で、カメラ選択メニューに1つのカメラのみ表示され、正常に動作することを確認

**Acceptance Criteria**:
- カメラが1台のみでもUIが正常に表示される
- 自動的にそのカメラが使用される

### Tests for User Story 3

- [ ] T028 [P] [US3] Test single camera scenario in CameraDeviceManager in FloweaseTests/CameraDeviceManagerTests.swift
- [ ] T029 [P] [US3] Test CameraSelectionView with single camera in FloweaseTests/CameraSelectionViewTests.swift

### Implementation for User Story 3

- [ ] T030 [US3] Handle single camera case in CameraDeviceManager in Flowease/Services/CameraDeviceManager.swift
- [ ] T031 [US3] Update CameraSelectionView to display single camera gracefully in Flowease/Views/CameraSelectionView.swift
- [ ] T032 [US3] Ensure auto-selection of single available camera on app launch in Flowease/Services/CameraService.swift

**Checkpoint**: All user stories should now be independently functional

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: エッジケース対応、品質改善、ローカライズ

- [ ] T033 [P] Handle duplicate camera names (append number suffix) in Flowease/Services/CameraDeviceManager.swift
- [ ] T034 [P] Handle zero cameras case (existing noCameraAvailable state) in Flowease/Services/CameraService.swift
- [ ] T035 [P] Add localized strings for camera selection UI in Flowease/Localizable.xcstrings
- [ ] T036 [P] Add Preview providers for CameraSelectionView in Flowease/Views/CameraSelectionView.swift
- [ ] T037 Run SwiftLint and SwiftFormat on all modified files
- [ ] T038 Validate against quickstart.md success criteria verification

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately, all tasks parallel
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-5)**: All depend on Foundational phase completion
  - User stories can proceed in priority order (P1 → P2 → P3)
  - Or in parallel if team capacity allows
- **Polish (Phase 6)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - No dependencies on other stories
- **User Story 2 (P2)**: Can start after Foundational (Phase 2) - Builds on US1 infrastructure but independently testable
- **User Story 3 (P3)**: Can start after Foundational (Phase 2) - Validates edge case, independently testable

### Within Each User Story

- Tests MUST be written and FAIL before implementation
- Models before services (CameraDevice → CameraService)
- Services before views (CameraService → CameraSelectionView)
- Core implementation before integration
- Story complete before moving to next priority

### Parallel Opportunities

**Phase 1 (all parallel)**:
- T001, T002, T003 can all run in parallel

**Phase 2 (sequential)**:
- T004 → T005 → T006 → T007 (dependencies within phase)

**Phase 3 - US1 Tests (parallel)**:
- T008, T009, T010 can all run in parallel

**Phase 3 - US1 Implementation**:
- T011 → T012 → T013, T014 → T015 → T016 → T017

**Phase 4 - US2 Tests (parallel)**:
- T018, T019, T020 can all run in parallel

**Phase 6 (parallel)**:
- T033, T034, T035, T036 can all run in parallel

---

## Parallel Example: User Story 1 Tests

```bash
# Launch all tests for User Story 1 together:
Task: "Test CameraDevice model equality in FloweaseTests/CameraDeviceTests.swift"
Task: "Test CameraService.selectCamera() in FloweaseTests/CameraServiceTests.swift"
Task: "Test camera fallback logic in FloweaseTests/CameraServiceTests.swift"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T003)
2. Complete Phase 2: Foundational (T004-T007)
3. Complete Phase 3: User Story 1 (T008-T017)
4. **STOP and VALIDATE**: Test カメラ選択と永続化 independently
5. Deploy/demo if ready - MVP is complete!

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Test independently → **MVP!** (カメラ選択可能)
3. Add User Story 2 → Test independently → **Enhanced** (切断・再接続対応)
4. Add User Story 3 → Test independently → **Complete** (シングルカメラ対応)
5. Polish → **Production Ready**

---

## Success Criteria Verification

| Criteria | Task | Verification |
|----------|------|--------------|
| SC-001: 3クリック以内 | T016 | メニュー → カメラ選択 → 選択 |
| SC-002: 1秒以内切り替え | T013, T014 | Manual timing test |
| SC-003: 2秒以内通知 | T022, T023 | Manual disconnect test |
| SC-004: 3秒以内再開 | T024 | Manual reconnect test |
| SC-005: 再起動後復元 | T013 | App restart test |

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Verify tests fail before implementing (TDD per Constitution)
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- CameraDeviceManager is internal to CameraService - View accesses via CameraServiceProtocol
