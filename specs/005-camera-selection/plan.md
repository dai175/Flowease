# Implementation Plan: カメラ選択機能

**Branch**: `005-camera-selection` | **Date**: 2026-01-08 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/005-camera-selection/spec.md`

## Summary

ユーザーが複数のカメラデバイスから使用するカメラを選択できる機能を実装する。既存の `CameraService` を拡張し、`AVCaptureDevice.DiscoverySession` を使用してカメラデバイスを列挙・監視する。選択されたカメラは `UserDefaults` で永続化し、カメラの接続・切断イベントに対応する。

## Technical Context

**Language/Version**: Swift 6.0
**Primary Dependencies**: AVFoundation, SwiftUI, OSLog
**Storage**: UserDefaults（カメラ選択の永続化）
**Testing**: XCTest
**Target Platform**: macOS 14.6+
**Project Type**: single（メニューバーアプリ）
**Performance Goals**: カメラ切り替え1秒以内、切断通知2秒以内、再接続後モニタリング再開3秒以内
**Constraints**: 既存の CameraServiceProtocol との互換性維持
**Scale/Scope**: シングルユーザー、同時使用カメラ1台

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Pre-Design Check (Phase 0)

| Principle | Status | Notes |
|-----------|--------|-------|
| I. SwiftUI-First Architecture | ✅ Pass | カメラ選択UIはSwiftUIで宣言的に構築、状態は@Observable ViewModelで管理 |
| II. Type Safety & Memory Safety | ✅ Pass | Force unwrap禁止、AVCaptureDevice.uniqueIDはStringで型安全 |
| III. Test-Driven Development | ✅ Pass | CameraServiceProtocolによりモック可能、ユニットテスト作成 |
| IV. User Experience Excellence | ✅ Pass | メニューバー統合、3クリック以内の操作、即座のフィードバック |
| V. Observability & Debugging | ✅ Pass | Logger(OSLog)でカメラ選択・切断イベントをログ |
| VI. Code Quality Gates | ✅ Pass | SwiftLint/SwiftFormat準拠、50行以下の関数 |

### Post-Design Check (Phase 1)

| Principle | Status | Notes |
|-----------|--------|-------|
| I. SwiftUI-First Architecture | ✅ Pass | `CameraSelectionView` はPicker使用、`CameraDeviceManager` は@Observable |
| II. Type Safety & Memory Safety | ✅ Pass | `CameraDevice` はSendable準拠、オプショナルは適切にハンドリング |
| III. Test-Driven Development | ✅ Pass | data-model.md でテスト戦略定義、モック可能な設計 |
| IV. User Experience Excellence | ✅ Pass | 切断時のフィードバック、自動復帰、3クリック操作を設計に反映 |
| V. Observability & Debugging | ✅ Pass | 選択・切断・再接続イベントのログ設計完了 |
| VI. Code Quality Gates | ✅ Pass | 小さな関数に分割、既存パターンに準拠 |

## Project Structure

### Documentation (this feature)

```text
specs/005-camera-selection/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (N/A - no external API)
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
Flowease/
├── Models/
│   ├── CameraDevice.swift           # NEW: カメラデバイスモデル
│   └── PauseReason.swift            # MODIFY: カメラ切断理由追加
├── Services/
│   ├── CameraService.swift          # MODIFY: カメラ選択機能追加、CameraDeviceManager を内包
│   └── CameraDeviceManager.swift    # NEW: デバイス監視（CameraService の内部実装）
├── ViewModels/
│   └── PostureViewModel.swift       # MODIFY: カメラ選択状態の反映
└── Views/
    ├── StatusMenuView.swift         # MODIFY: カメラ選択UI追加
    └── CameraSelectionView.swift    # NEW: カメラ選択コンポーネント

FloweaseTests/
├── CameraDeviceTests.swift          # NEW: CameraDeviceモデルのテスト
├── CameraDeviceManagerTests.swift   # NEW: デバイス監視のテスト
├── CameraServiceTests.swift         # MODIFY: カメラ選択機能のテスト追加
├── CameraSelectionViewTests.swift   # NEW: カメラ選択UIのテスト
└── MonitoringStateTests.swift       # MODIFY: 新しいPauseReasonのテスト追加
```

**Structure Decision**: 既存のMVVMアーキテクチャを維持。View は CameraServiceProtocol 経由で `availableCameras` / `selectedCameraID` を取得。CameraDeviceManager は CameraService の内部実装詳細として隠蔽する。

## Complexity Tracking

> No Constitution violations requiring justification.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| N/A | - | - |
