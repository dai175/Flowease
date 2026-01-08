# Research: カメラ選択機能

**Feature**: 005-camera-selection
**Date**: 2026-01-08

## 1. カメラデバイスの列挙と監視

### Decision
`AVCaptureDevice.DiscoverySession` を使用してビデオデバイスを列挙し、KVO（Key-Value Observing）で `devices` プロパティを監視する。

### Rationale
- `AVCaptureDevice.DiscoverySession` は macOS 10.15+ でサポートされ、デバイスの動的な追加・削除を監視可能
- `devices` プロパティは KVO 対応で、外部カメラの接続・切断をリアルタイムで検知できる
- `deviceTypes` に `.builtInWideAngleCamera` と `.externalUnknown` を指定することで内蔵・外部カメラ両方を取得

### Alternatives Considered
1. **`AVCaptureDevice.devices(for:)`**: 非推奨（deprecated）であり、動的な監視ができない
2. **`IOKit` 直接使用**: 低レベルAPIで複雑、AVFoundation で十分対応可能
3. **ポーリング**: 非効率でバッテリー消費が増加

### Implementation Notes
```swift
let discoverySession = AVCaptureDevice.DiscoverySession(
    deviceTypes: [.builtInWideAngleCamera, .externalUnknown],
    mediaType: .video,
    position: .unspecified
)
// KVO で devices を監視
discoverySession.observe(\.devices, options: [.new]) { session, change in
    // デバイスリスト更新
}
```

## 2. カメラ選択の永続化

### Decision
`UserDefaults` に選択されたカメラの `uniqueID`（String）を保存する。

### Rationale
- 既存プロジェクトで `UserDefaults` を `CalibrationStorage` で使用しており、一貫性がある
- カメラの `uniqueID` は macOS が保証する一意識別子で、再接続時も同じ値
- シンプルな文字列保存で十分（複雑なデータ構造は不要）

### Alternatives Considered
1. **CoreData**: 単一の文字列保存にはオーバーキル
2. **ファイルベース（JSON）**: UserDefaults と比べて利点なし
3. **Keychain**: セキュリティ要件なし（カメラIDは機密情報ではない）

### Implementation Notes
- キー: `selectedCameraDeviceID`
- 保存されたIDのカメラが存在しない場合は `AVCaptureDevice.default(for: .video)` にフォールバック

## 3. カメラ切り替え時のセッション管理

### Decision
カメラ切り替え時は既存の `AVCaptureSession` を停止・破棄し、新しいセッションを作成する。

### Rationale
- `AVCaptureSession.beginConfiguration()` / `commitConfiguration()` で入力デバイスを切り替えることも可能だが、既存の `CameraService.setupCaptureSession()` の構造を活かすため、セッション再作成が最もシンプル
- セッション再作成は1秒以内で完了（Success Criteria SC-002 を満たす）
- 切り替え中は既存の `MonitoringState.paused(.cameraInitializing)` を使用

### Alternatives Considered
1. **セッション内で入力切り替え**: 複雑なエラーハンドリングが必要
2. **複数セッション保持**: メモリ消費増加、不要な複雑さ

### Implementation Notes
```swift
func switchCamera(to deviceID: String) {
    stopCapturing()  // 既存セッション停止
    selectedCameraID = deviceID
    startCapturing() // 新しいデバイスでセッション作成
}
```

## 4. デバイス切断の検知と復帰

### Decision
`AVCaptureSession.runtimeErrorNotification` と `DiscoverySession` の KVO を組み合わせて切断を検知し、再接続時は自動的にキャプチャを再開する。

### Rationale
- 既存の `CameraService` は `runtimeErrorNotification` を監視しており、拡張が容易
- `DiscoverySession` の KVO でデバイスリストの変化を検知し、選択中のカメラの再接続を判定
- 2つのメカニズムの組み合わせで確実な検知が可能

### Alternatives Considered
1. **`wasDisconnectedNotification` のみ**: macOS では利用不可（iOS のみ）
2. **ポーリング**: 非効率

### Implementation Notes
- 切断検知: `runtimeErrorNotification` でエラーコード `AVError.sessionWasInterrupted` または `deviceNotConnected` を監視
- 再接続検知: `DiscoverySession.devices` の変化で、保存済み `uniqueID` を持つデバイスの出現を監視
- 自動再開: 選択されていたデバイスが再接続されたら `startCapturing()` を呼び出す

## 5. UI統合パターン

### Decision
`StatusMenuView` に `CameraSelectionView` サブビューを追加し、`Picker` または `Menu` でカメラ選択を提供する。

### Rationale
- SwiftUI の `Picker` は macOS のネイティブなポップアップメニューを提供
- `@Observable` パターンで状態管理し、選択変更を即座に反映
- 既存の `StatusMenuView` の構造（VStack、Divider）に自然に統合可能

### Alternatives Considered
1. **別ウィンドウ**: 設定項目が1つだけなのでオーバーキル
2. **コンテキストメニュー**: 発見性が低い
3. **NSMenu直接使用**: SwiftUI との統合が複雑

### Implementation Notes
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
                Text(camera.name).tag(camera.id as String?)
            }
        }
    }
}
```

**Note**: View は CameraService（CameraServiceProtocol）から `availableCameras` と `selectedCameraID` を取得します。CameraDeviceManager は CameraService の内部実装詳細として隠蔽されます。

## 6. デフォルトカメラの決定

### Decision
選択されたカメラが利用不可の場合、`AVCaptureDevice.default(for: .video)` が返すシステムデフォルトカメラを使用する。

### Rationale
- Clarifications で「システムのデフォルトカメラ（OSが優先するカメラ）」と決定済み
- macOS はユーザーの設定や最後に使用したカメラを考慮してデフォルトを決定
- アプリ独自のロジック（リスト先頭など）よりもユーザーの期待に沿う

### Implementation Notes
```swift
func resolveCamera(preferredID: String?) -> (device: AVCaptureDevice?, didFallback: Bool) {
    if let id = preferredID,
       let device = AVCaptureDevice(uniqueID: id),
       device.isConnected {
        return (device, false)
    }
    // フォールバック時は通知が必要（FR-004）
    return (AVCaptureDevice.default(for: .video), preferredID != nil)
}
```

**Note**: フォールバックが発生した場合（`didFallback == true`）、FR-004 に従いメニュー内のステータス表示でユーザーに通知する。

## Summary

| Topic | Decision |
|-------|----------|
| デバイス列挙・監視 | `AVCaptureDevice.DiscoverySession` + KVO |
| 永続化 | `UserDefaults` に `uniqueID` を保存 |
| セッション管理 | 切り替え時にセッション再作成 |
| 切断検知 | `runtimeErrorNotification` + DiscoverySession KVO |
| UI | `StatusMenuView` 内に `Picker` で統合 |
| デフォルト | `AVCaptureDevice.default(for: .video)` |
