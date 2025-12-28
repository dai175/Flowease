# Research: Flowease MVP機能

**Branch**: `001-mvp-features` | **Date**: 2025-12-28

## 概要

このドキュメントは、Flowease MVP機能の実装に必要な技術調査結果をまとめたものです。

---

## 1. Apple Vision Framework - Body Pose Detection

### 決定事項

**VNDetectHumanBodyPoseRequest**を使用してユーザーの姿勢をリアルタイムで検知する。

### 根拠

- Apple公式のVision Frameworkで、macOS 11.0+でネイティブサポート
- 19個の身体ランドマークを検出可能
- Neural Engineを活用したパフォーマンス最適化が可能
- ローカル処理のみで外部サーバー不要（プライバシー要件を満たす）

### 検討した代替案

| 代替案 | 却下理由 |
|--------|----------|
| MediaPipe | サードパーティ依存、macOSネイティブでない |
| CoreML カスタムモデル | 開発コスト高、精度保証なし |
| CreateML | Body Pose専用モデルなし |

### 技術詳細

#### 利用可能なランドマーク（JointName）

姿勢検知に重要なポイント:
- `nose` - 顔の中心
- `neck` - 首の付け根
- `leftShoulder` / `rightShoulder` - 肩
- `root` - 骨盤の中心（腰の基準点）
- `leftEar` / `rightEar` - 耳（頭の傾き検出用）

#### 姿勢判定アルゴリズム

```swift
// 前かがみ検出（Forward Lean Detection）
func detectForwardLean(_ observation: VNHumanBodyPoseObservation) -> (angle: Double, isLeaning: Bool) {
    guard let nose = getJointPoint(observation, joint: .nose),
          let neck = getJointPoint(observation, joint: .neck),
          let hip = getJointPoint(observation, joint: .root) else {
        return (0, false)
    }

    // 首から腰までのベクトル
    let spineVector = CGPoint(x: hip.x - neck.x, y: hip.y - neck.y)
    let verticalVector = CGPoint(x: 0, y: 1)

    let angle = angleBetweenVectors(spineVector, verticalVector)
    let isLeaning = angle > 15.0  // 15度以上で警告

    return (angle, isLeaning)
}

// 首の傾き検出（Neck Tilt Detection）
func detectNeckTilt(_ observation: VNHumanBodyPoseObservation) -> (angle: Double, isTilted: Bool) {
    guard let nose = getJointPoint(observation, joint: .nose),
          let neck = getJointPoint(observation, joint: .neck) else {
        return (0, false)
    }

    let headVector = CGPoint(x: nose.x - neck.x, y: nose.y - neck.y)
    let verticalVector = CGPoint(x: 0, y: 1)

    let angle = angleBetweenVectors(headVector, verticalVector)
    let isTilted = angle > 20.0  // 20度以上で警告

    return (angle, isTilted)
}
```

#### 信頼度チェック

```swift
func getJointPoint(_ observation: VNHumanBodyPoseObservation,
                   joint: VNHumanBodyPoseObservation.JointName) -> CGPoint? {
    guard let recognizedPoint = try? observation.recognizedPoint(joint) else {
        return nil
    }

    // 信頼度が0.5以上の場合のみ使用
    guard recognizedPoint.confidence > 0.5 else {
        return nil
    }

    return CGPoint(x: recognizedPoint.location.x,
                   y: recognizedPoint.location.y)
}
```

---

## 2. AVFoundation カメラ統合

### 決定事項

**AVCaptureSession**と**VNImageRequestHandler**を組み合わせて、2秒間隔の間欠検知を実装する。

### 根拠

- CPU使用率5%以下の要件を満たすため、常時検知ではなく間欠検知を採用
- 低解像度（640x480）で姿勢検知には十分な精度を確保
- AVFoundationはmacOSネイティブで安定した動作

### 検討した代替案

| 代替案 | 却下理由 |
|--------|----------|
| 常時検知（毎フレーム） | CPU使用率が高くバッテリー消費大 |
| 外部ライブラリ（OpenCV等） | 依存関係増加、Swiftとの統合が複雑 |

### 技術詳細

#### 推奨カメラ設定

```swift
// 低解像度設定（姿勢検知には十分）
captureSession?.sessionPreset = .vga640x480

// フレームレート制限（15fps）
if let connection = videoOutput.connection(with: .video) {
    if connection.isVideoMinFrameDurationSupported {
        connection.videoMinFrameDuration = CMTime(value: 1, timescale: 15)
    }
}
```

#### 間欠検知の実装

```swift
private var lastDetectionTime: Date?
private let detectionInterval: TimeInterval = 2.0  // 2秒間隔

private func shouldPerformDetection() -> Bool {
    guard let lastTime = lastDetectionTime else {
        lastDetectionTime = Date()
        return true
    }

    let elapsed = Date().timeIntervalSince(lastTime)
    if elapsed >= detectionInterval {
        lastDetectionTime = Date()
        return true
    }

    return false
}
```

#### パフォーマンス最適化チェックリスト

| 項目 | 推奨設定 | 理由 |
|------|----------|------|
| 検知間隔 | 2秒 | CPU使用率5%以下を維持 |
| カメラ解像度 | 640x480 (VGA) | 姿勢検知には十分、処理負荷軽減 |
| フレームレート | 15 fps | リアルタイム性と省電力のバランス |
| Neural Engine | 有効 (`usesCPUOnly = false`) | CPU負荷を軽減 |
| フレーム破棄 | 有効 | 遅延防止 |

---

## 3. macOS メニューバーアプリ

### 決定事項

**NSStatusBar + NSStatusItem + NSPopover**の組み合わせで、SwiftUIと統合したメニューバー専用アプリを実装する。

### 根拠

- macOS標準のAPIで安定した動作
- SwiftUIとの統合が`@NSApplicationDelegateAdaptor`で容易
- ポップオーバーでリッチなUIを提供可能
- SF Symbolsでカラーアイコンを動的に変更可能

### 検討した代替案

| 代替案 | 却下理由 |
|--------|----------|
| SwiftUI MenuBarExtra のみ | アイコン動的変更の柔軟性が低い |
| Cocoa のみ（SwiftUI なし） | UI実装の生産性が低い |

### 技術詳細

#### Dockアイコン非表示（Info.plist）

```xml
<key>LSUIElement</key>
<true/>
```

#### AppDelegate実装パターン

```swift
import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "figure.stand", accessibilityDescription: "Flowease")
            button.action = #selector(togglePopover)
            button.target = self
        }

        let popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 400)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: ContentView())
        self.popover = popover
    }

    @objc func togglePopover() {
        if let button = statusItem?.button {
            if let popover = self.popover {
                if popover.isShown {
                    popover.performClose(nil)
                } else {
                    NSApp.activate(ignoringOtherApps: true)
                    popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                }
            }
        }
    }
}
```

#### 動的アイコン変更

```swift
func updateMenuBarIcon(for status: PostureStatus) {
    guard let button = statusItem?.button else { return }

    let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        .applying(.init(paletteColors: [status.color]))

    let image = NSImage(systemSymbolName: status.iconName, accessibilityDescription: "姿勢ステータス")
    button.image = image?.withSymbolConfiguration(config)
}
```

#### SwiftUI App統合

```swift
@main
struct FloweaseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}
```

---

## 4. UserNotifications Framework

### 決定事項

**UserNotifications**フレームワークを使用し、アクション付きローカル通知を実装する。

### 根拠

- macOS標準のAPIで追加の依存関係なし
- async/awaitをネイティブサポート
- 通知アクション（ボタン）をサポート
- 通知の更新・置換が容易

### 技術詳細

#### 通知権限リクエスト

```swift
func requestAuthorization() async throws -> Bool {
    let center = UNUserNotificationCenter.current()
    let options: UNAuthorizationOptions = [.alert, .sound, .badge]
    let granted = try await center.requestAuthorization(options: options)
    return granted
}
```

#### アクション付き通知

```swift
// アクションの定義
let startAction = UNNotificationAction(
    identifier: "START_STRETCH_ACTION",
    title: "ストレッチを開始",
    options: [.foreground]
)

let snoozeAction = UNNotificationAction(
    identifier: "SNOOZE_ACTION",
    title: "5分後にリマインド",
    options: []
)

// カテゴリの作成
let stretchCategory = UNNotificationCategory(
    identifier: "STRETCH_REMINDER",
    actions: [startAction, snoozeAction],
    intentIdentifiers: [],
    options: []
)

UNUserNotificationCenter.current().setNotificationCategories([stretchCategory])
```

#### 通知送信

```swift
func sendNotificationWithActions(title: String, body: String) async throws {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default
    content.categoryIdentifier = "STRETCH_REMINDER"

    let request = UNNotificationRequest(
        identifier: UUID().uuidString,
        content: content,
        trigger: nil
    )

    try await UNUserNotificationCenter.current().add(request)
}
```

#### 通知頻度のベストプラクティス

- **姿勢警告**: 5秒間悪い姿勢が続いた場合にのみ通知（連続通知防止）
- **休憩リマインダー**: ユーザー設定の間隔（30〜60分）で通知
- **スヌーズ**: 5分後に再通知
- **勤務時間考慮**: オプションで夜間・休日の通知を無効化

---

## 5. ストレッチガイド

### 決定事項

静的なアニメーションデータ（Lottie形式またはSwiftUIアニメーション）と30秒タイマーで実装する。

### 根拠

- MVPでは複雑なモーションキャプチャ連動は不要
- SwiftUIの標準アニメーションで十分なUXを提供可能
- 6種類のストレッチは静的データで管理

### ストレッチコンテンツ

| 名前 | カテゴリ | 所要時間 | 説明 |
|------|----------|----------|------|
| 首回し | 首 | 30秒 | 左右にゆっくり首を回す |
| 首筋伸ばし | 首 | 30秒 | 左右に首を傾けて伸ばす |
| 肩回し | 肩 | 30秒 | 両肩を前後に回す |
| 肩甲骨寄せ | 肩 | 30秒 | 肩甲骨を寄せて胸を開く |
| 腰ひねり | 腰 | 30秒 | 椅子に座ったまま腰をひねる |
| 背伸び | 全身 | 30秒 | 両手を上げて全身を伸ばす |

---

## 6. データ永続化

### 決定事項

**UserDefaults**を使用して設定と軽量なデータを保存する。

### 根拠

- MVPでは複雑なデータ構造は不要
- UserDefaultsはmacOS標準で追加の設定不要
- キーバリューストアで設定の保存に最適

### 検討した代替案

| 代替案 | 却下理由 |
|--------|----------|
| Core Data | MVPには過剰な機能 |
| SQLite | 同上 |
| ファイル保存 | 構造化データの管理が煩雑 |

### 保存するデータ

```swift
struct UserSettings: Codable {
    var selectedCameraID: String?
    var breakInterval: Int = 30  // 分単位（30〜60）
    var postureSensitivity: Double = 0.5  // 0.0〜1.0
    var notificationsEnabled: Bool = true
}
```

---

## 7. Info.plist 必須設定

### カメラ使用理由

```xml
<key>NSCameraUsageDescription</key>
<string>Floweaseは、あなたの姿勢をリアルタイムで検知し、悪い姿勢が続いた場合に通知を送ります。カメラ映像はデバイス内でのみ処理され、外部に送信されることはありません。</string>
```

### Dockアイコン非表示

```xml
<key>LSUIElement</key>
<true/>
```

---

## まとめ

| 技術領域 | 選択した技術 | 理由 |
|----------|--------------|------|
| 姿勢検知 | Vision Framework (VNDetectHumanBodyPoseRequest) | ネイティブ、プライバシー保護、Neural Engine対応 |
| カメラ連携 | AVFoundation | macOS標準、安定性 |
| UI | NSStatusBar + SwiftUI | メニューバー常駐、リッチなUI |
| 通知 | UserNotifications | macOS標準、アクション対応 |
| データ保存 | UserDefaults | シンプル、MVPに最適 |
| アニメーション | SwiftUI標準 | 追加依存なし |

全ての技術選択は以下の原則に基づいています:
- **Privacy First**: 全処理をローカルで完結
- **Simplicity**: macOS標準APIを優先、外部依存を最小化
- **Performance**: CPU使用率5%以下、2秒間隔の間欠検知
