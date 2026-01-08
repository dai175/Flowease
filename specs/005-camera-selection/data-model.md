# Data Model: カメラ選択機能

**Feature**: 005-camera-selection
**Date**: 2026-01-08

## Entities

### CameraDevice

カメラデバイスを表すモデル。`AVCaptureDevice` のラッパーとして機能し、UI表示に必要な情報を提供する。

```swift
/// カメラデバイスを表すモデル
struct CameraDevice: Identifiable, Equatable, Sendable {
    /// デバイスの一意識別子（AVCaptureDevice.uniqueID）
    let id: String

    /// デバイス名（AVCaptureDevice.localizedName）
    let name: String

    /// 接続状態
    var isConnected: Bool

    /// システムデフォルトかどうか
    var isDefault: Bool
}
```

| Field | Type | Description | Validation |
|-------|------|-------------|------------|
| `id` | `String` | AVCaptureDevice.uniqueID | Non-empty, immutable |
| `name` | `String` | AVCaptureDevice.localizedName | Non-empty |
| `isConnected` | `Bool` | AVCaptureDevice.isConnected | Runtime state |
| `isDefault` | `Bool` | システムデフォルトカメラかどうか | Computed from AVCaptureDevice.default |

### CameraSelection (Persistence)

UserDefaults に保存されるカメラ選択設定。

| Key | Type | Description | Default |
|-----|------|-------------|---------|
| `selectedCameraDeviceID` | `String?` | 選択されたカメラのuniqueID | `nil` (システムデフォルト使用) |

## Relationships

```
┌─────────────────┐      monitors      ┌──────────────────────┐
│ CameraDevice    │ <─────────────────>│ CameraDeviceManager  │
│ Manager         │                    │                      │
└─────────────────┘                    └──────────────────────┘
        │                                        │
        │ provides                               │ notifies
        ▼                                        ▼
┌─────────────────┐      uses          ┌──────────────────────┐
│ CameraDevice[]  │ ─────────────────> │ CameraService        │
│ (available)     │                    │ (capture)            │
└─────────────────┘                    └──────────────────────┘
        │                                        │
        │ displays                               │ updates
        ▼                                        ▼
┌─────────────────┐      observes      ┌──────────────────────┐
│ CameraSelection │ <─────────────────>│ PostureViewModel     │
│ View            │                    │                      │
└─────────────────┘                    └──────────────────────┘
```

## State Transitions

### カメラ接続状態

```
┌─────────────┐
│ Disconnected│
└──────┬──────┘
       │ device connected
       ▼
┌─────────────┐
│ Connected   │
└──────┬──────┘
       │ device disconnected
       ▼
┌─────────────┐
│ Disconnected│
└─────────────┘
```

### カメラ選択状態

```
┌──────────────────┐
│ No Selection     │ (初回起動、または保存されたカメラが存在しない)
│ (use default)    │
└────────┬─────────┘
         │ user selects camera
         ▼
┌──────────────────┐
│ Camera Selected  │
│ (capturing)      │
└────────┬─────────┘
         │ selected camera disconnected
         ▼
┌──────────────────┐
│ Camera Selected  │
│ (disconnected)   │
│ → show warning   │ ← FR-004: メニュー内ステータス表示で通知
└────────┬─────────┘
         │ camera reconnected
         ▼
┌──────────────────┐
│ Camera Selected  │
│ (auto-resume)    │
└──────────────────┘
```

### フォールバック時の通知（FR-004）

選択されたカメラが利用不可でデフォルトカメラにフォールバックした場合:
1. フォールバックが発生したことをメニュー内ステータスで通知
2. 通知内容例: 「選択されたカメラが見つかりません。デフォルトカメラを使用しています。」
3. ユーザーはカメラ選択メニューから別のカメラを選択可能

## Extensions to Existing Models

### PauseReason (Modify)

新しい理由を追加:

```swift
enum PauseReason: Sendable, Equatable {
    // ... existing cases ...

    /// 選択されたカメラが切断された
    ///
    /// ユーザーが選択したカメラが物理的に切断された場合。
    /// 再接続されるか、別のカメラを選択するまで一時停止。
    case selectedCameraDisconnected
}
```

### CameraServiceProtocol (Extend)

新しいメソッドを追加:

```swift
@MainActor
protocol CameraServiceProtocol: AnyObject, Sendable {
    // ... existing members ...

    /// 利用可能なカメラデバイス一覧
    var availableCameras: [CameraDevice] { get }

    /// 現在選択されているカメラのID
    var selectedCameraID: String? { get }

    /// カメラを選択
    /// - Parameter deviceID: 選択するカメラのuniqueID (nil でシステムデフォルト)
    func selectCamera(_ deviceID: String?)
}
```

## Validation Rules

1. **CameraDevice.id**: 空文字列は無効。AVCaptureDevice.uniqueID から取得した値のみ有効
2. **CameraDevice.name**: 空文字列は無効。AVCaptureDevice.localizedName から取得
3. **selectedCameraDeviceID**:
   - `nil` は有効（システムデフォルトを意味する）
   - 非nil の場合、対応するデバイスが存在しなければシステムデフォルトにフォールバック
4. **同名カメラの区別**:
   - 同じ `name` を持つカメラが複数ある場合、リスト表示時に番号を付与
   - 例: "Logitech C920", "Logitech C920 (2)"
