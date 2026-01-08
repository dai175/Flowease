# Quickstart: カメラ選択機能

**Feature**: 005-camera-selection
**Date**: 2026-01-08

## Overview

この機能は、ユーザーが複数のカメラデバイスから姿勢モニタリングに使用するカメラを選択できるようにします。

## Key Components

### 1. CameraDevice (Model)

カメラデバイスを表すシンプルなモデル:

```swift
struct CameraDevice: Identifiable, Equatable, Sendable {
    let id: String      // AVCaptureDevice.uniqueID
    let name: String    // AVCaptureDevice.localizedName
    var isConnected: Bool
    var isDefault: Bool
}
```

### 2. CameraDeviceManager (Internal Service)

カメラデバイスの列挙と監視を担当（CameraService の内部実装）:

```swift
@MainActor
final class CameraDeviceManager {
    private(set) var availableCameras: [CameraDevice] = []
    var onDevicesChanged: (([CameraDevice]) -> Void)?

    init() {
        setupDiscoverySession()
    }

    private func setupDiscoverySession() {
        // AVCaptureDevice.DiscoverySession で監視
        // 変更時に onDevicesChanged を呼び出す
    }
}
```

**Note**: CameraDeviceManager は CameraService の内部実装詳細であり、View から直接参照しません。

### 3. CameraService Extensions

既存の `CameraService` に選択機能を追加:

```swift
extension CameraService {
    var selectedCameraID: String? { /* UserDefaults から取得 */ }

    func selectCamera(_ deviceID: String?) {
        // 1. 現在のキャプチャを停止
        // 2. 選択を永続化
        // 3. 新しいカメラでキャプチャ開始
    }
}
```

### 4. CameraSelectionView (UI)

メニュー内のカメラ選択UI:

```swift
struct CameraSelectionView: View {
    let availableCameras: [CameraDevice]
    let selectedCameraID: String?
    let onSelect: (String?) -> Void

    var body: some View {
        Picker("Camera", selection: Binding(
            get: { selectedCameraID },
            set: { onSelect($0) }
        )) {
            ForEach(availableCameras) { camera in
                HStack {
                    Text(camera.name)
                    if camera.isDefault {
                        Text("(Default)").foregroundStyle(.secondary)
                    }
                }
                .tag(camera.id as String?)
            }
        }
    }
}
```

**Note**: View は CameraServiceProtocol から `availableCameras` と `selectedCameraID` を取得します。

## Integration Points

### StatusMenuView に統合

```swift
struct StatusMenuView: View {
    let viewModel: PostureViewModel
    // ...

    var body: some View {
        VStack {
            // ... existing content ...

            Divider()

            // カメラ選択セクション（権限取得後のみ表示）
            if viewModel.cameraService.authorizationStatus == .authorized {
                CameraSelectionView(
                    availableCameras: viewModel.cameraService.availableCameras,
                    selectedCameraID: viewModel.cameraService.selectedCameraID,
                    onSelect: { cameraID in
                        viewModel.cameraService.selectCamera(cameraID)
                    }
                )
            }
        }
    }
}
```

**Note**:
- spec.md の Edge Cases に従い、カメラ権限が許可されている場合のみカメラ選択UIを表示
- View は CameraService（CameraServiceProtocol）経由で `availableCameras` と `selectedCameraID` を取得
- CameraDeviceManager は CameraService の内部実装詳細として隠蔽

## Event Flow

### カメラ選択時

```
User selects camera in Picker
    ↓
CameraSelectionView.onSelect called
    ↓
CameraService.selectCamera(deviceID)
    ↓
1. stopCapturing()
2. Save to UserDefaults
3. startCapturing() with new device
    ↓
PostureViewModel observes state change
    ↓
UI updates (paused → active)
```

### カメラ切断時

```
Camera physically disconnected
    ↓
DiscoverySession KVO fires
    ↓
CameraDeviceManager updates availableCameras
    ↓
CameraService detects via runtimeErrorNotification
    ↓
MonitoringState → .paused(.selectedCameraDisconnected)
    ↓
UI shows disconnection feedback
```

### カメラ再接続時

```
Camera physically reconnected
    ↓
DiscoverySession KVO fires
    ↓
CameraDeviceManager updates availableCameras
    ↓
Check: reconnected device.id == selectedCameraID?
    ↓ Yes
CameraService.startCapturing()
    ↓
MonitoringState → .active(score)
```

## Testing Strategy

### Unit Tests

1. `CameraDevice` モデルの等価性テスト
2. `CameraDeviceManager` のデバイスリスト更新テスト（モック使用）
3. `CameraService.selectCamera()` の永続化テスト
4. フォールバックロジックのテスト

### Integration Tests

1. カメラ選択 → キャプチャ開始の統合テスト
2. 切断 → 再接続の自動復帰テスト

### Manual Tests

1. 複数カメラ環境でのUI表示確認
2. 外部カメラの着脱テスト
3. アプリ再起動後の選択復元確認

## Success Criteria Verification

| Criteria | Verification Method |
|----------|---------------------|
| SC-001: 3クリック以内 | UI操作で確認: メニュークリック → カメラ選択 → 完了 |
| SC-002: 1秒以内切り替え | Instruments でレイテンシ計測 |
| SC-003: 2秒以内通知 | 外部カメラ切断テストで計測 |
| SC-004: 3秒以内再開 | 外部カメラ再接続テストで計測 |
| SC-005: 再起動後復元 | アプリ再起動テストで確認 |
