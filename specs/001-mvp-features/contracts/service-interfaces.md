# Service Interfaces: Flowease MVP

**Branch**: `001-mvp-features` | **Date**: 2025-12-28

## 概要

このドキュメントは、Flowease MVPの内部サービス間のインターフェース契約を定義します。外部APIは存在しないため、Swiftプロトコルとして内部サービスのインターフェースを規定します。

---

## 1. PostureDetectionServiceProtocol

姿勢検知サービスのインターフェース。

```swift
import Vision
import Combine

/// 姿勢検知サービスプロトコル
protocol PostureDetectionServiceProtocol {

    // MARK: - Properties

    /// 現在の姿勢状態（リアルタイム更新）
    var currentPosture: CurrentValueSubject<PostureState?, Never> { get }

    /// 検知が実行中か
    var isDetecting: Bool { get }

    // MARK: - Methods

    /// 姿勢検知を開始
    /// - Parameter cameraDeviceID: 使用するカメラのデバイスID（nilの場合は自動選択）
    /// - Throws: カメラアクセスエラー、Vision Frameworkエラー
    func startDetection(cameraDeviceID: String?) async throws

    /// 姿勢検知を停止
    func stopDetection()

    /// 単一フレームから姿勢を検知（テスト用）
    /// - Parameter pixelBuffer: カメラからのフレーム
    /// - Returns: 検知結果
    func detectPosture(from pixelBuffer: CVPixelBuffer) async throws -> PostureState

    /// 姿勢判定の閾値を更新
    /// - Parameters:
    ///   - forwardLeanThreshold: 前かがみ閾値（度）
    ///   - neckTiltThreshold: 首傾き閾値（度）
    func updateThresholds(forwardLeanThreshold: Double, neckTiltThreshold: Double)
}
```

### 入出力仕様

| メソッド | 入力 | 出力 | エラー |
|---------|------|------|--------|
| startDetection | cameraDeviceID: String? | void | cameraAccessDenied, cameraNotFound, visionFrameworkError |
| stopDetection | - | void | - |
| detectPosture | pixelBuffer: CVPixelBuffer | PostureState | visionFrameworkError, noPoseDetected |
| updateThresholds | forwardLeanThreshold, neckTiltThreshold | void | - |

### エラー定義

```swift
enum PostureDetectionError: Error {
    case cameraAccessDenied
    case cameraNotFound
    case visionFrameworkError(Error)
    case noPoseDetected
    case insufficientConfidence
}
```

---

## 2. CameraServiceProtocol

カメラ制御サービスのインターフェース。

```swift
import AVFoundation
import Combine

/// カメラサービスプロトコル
protocol CameraServiceProtocol {

    // MARK: - Properties

    /// 利用可能なカメラ一覧
    var availableCameras: [CameraDevice] { get }

    /// 現在選択されているカメラ
    var currentCamera: CameraDevice? { get }

    /// カメラがアクティブか
    var isActive: Bool { get }

    /// カメラフレームのPublisher
    var framePublisher: AnyPublisher<CVPixelBuffer, Never> { get }

    // MARK: - Methods

    /// カメラアクセス権限を確認
    /// - Returns: 権限状態
    func checkAuthorization() async -> AVAuthorizationStatus

    /// カメラアクセス権限をリクエスト
    /// - Returns: 許可されたか
    func requestAuthorization() async -> Bool

    /// カメラを開始
    /// - Parameter deviceID: デバイスID（nilの場合は自動選択）
    /// - Throws: カメラエラー
    func startCamera(deviceID: String?) async throws

    /// カメラを停止
    func stopCamera()

    /// カメラを切り替え
    /// - Parameter deviceID: 新しいカメラのデバイスID
    func switchCamera(to deviceID: String) async throws

    /// 利用可能なカメラ一覧を更新
    func refreshAvailableCameras()
}
```

### 入出力仕様

| メソッド | 入力 | 出力 | エラー |
|---------|------|------|--------|
| checkAuthorization | - | AVAuthorizationStatus | - |
| requestAuthorization | - | Bool | - |
| startCamera | deviceID: String? | void | CameraError |
| stopCamera | - | void | - |
| switchCamera | deviceID: String | void | CameraError |
| refreshAvailableCameras | - | void | - |

### エラー定義

```swift
enum CameraError: Error {
    case accessDenied
    case deviceNotFound(deviceID: String)
    case sessionConfigurationFailed
    case alreadyRunning
}
```

---

## 3. NotificationServiceProtocol

通知サービスのインターフェース。

```swift
import UserNotifications

/// 通知サービスプロトコル
protocol NotificationServiceProtocol {

    // MARK: - Properties

    /// 通知が許可されているか
    /// - Note: 非同期プロパティ。呼び出し側は `await` を使用してアクセスする必要があります。
    ///   例: `let authorized = await notificationService.isAuthorized`
    var isAuthorized: Bool { get async }

    // MARK: - Methods

    /// 通知権限をリクエスト
    /// - Returns: 許可されたか
    func requestAuthorization() async throws -> Bool

    /// 姿勢警告通知を送信
    /// - Parameter postureState: 現在の姿勢状態
    func sendPostureAlert(postureState: PostureState) async throws

    /// 休憩リマインダー通知を送信
    func sendBreakReminder() async throws

    /// スヌーズ通知をスケジュール
    /// - Parameter delay: 遅延時間（秒）
    func scheduleSnoozeReminder(delay: TimeInterval) async throws

    /// 保留中の通知をキャンセル
    /// - Parameter identifier: 通知の識別子（nilの場合は全てキャンセル）
    func cancelNotification(identifier: String?)

    /// 通知カテゴリとアクションを設定
    func setupNotificationCategories()
}
```

### 通知カテゴリ

| カテゴリID | アクション | 説明 |
|-----------|-----------|------|
| POSTURE_ALERT | - | 姿勢警告（アクションなし） |
| BREAK_REMINDER | START_STRETCH, SNOOZE, DISMISS | 休憩リマインダー |

### 入出力仕様

| メソッド | 入力 | 出力 | エラー |
|---------|------|------|--------|
| requestAuthorization | - | Bool | AuthorizationError |
| sendPostureAlert | postureState: PostureState | void | NotificationError |
| sendBreakReminder | - | void | NotificationError |
| scheduleSnoozeReminder | delay: TimeInterval | void | NotificationError |
| cancelNotification | identifier: String? | void | - |

### エラー定義

```swift
/// 通知権限リクエスト時のエラー
enum AuthorizationError: Error {
    case denied
    case restricted
    case systemError(Error)
}

/// 通知送信時のエラー
enum NotificationError: Error {
    case deliveryFailed(Error)
    case invalidContent
}
```

---

## 4. SettingsServiceProtocol

設定管理サービスのインターフェース。

```swift
import Combine

/// 設定サービスプロトコル
protocol SettingsServiceProtocol {

    // MARK: - Properties

    /// 現在の設定
    var settings: CurrentValueSubject<UserSettings, Never> { get }

    /// 休憩リマインダー設定
    var breakReminder: CurrentValueSubject<BreakReminder, Never> { get }

    // MARK: - Methods

    /// 設定を読み込み
    func loadSettings()

    /// 設定を保存
    func saveSettings(_ settings: UserSettings)

    /// 休憩リマインダー設定を保存
    func saveBreakReminder(_ reminder: BreakReminder)

    /// 設定をデフォルトにリセット
    func resetToDefaults()

    /// 特定の設定値を更新
    /// - Parameters:
    ///   - keyPath: 設定のキーパス
    ///   - value: 新しい値
    func updateSetting<T>(_ keyPath: WritableKeyPath<UserSettings, T>, value: T)
}
```

### 入出力仕様

| メソッド | 入力 | 出力 | エラー |
|---------|------|------|--------|
| loadSettings | - | void | - |
| saveSettings | settings: UserSettings | void | - |
| saveBreakReminder | reminder: BreakReminder | void | - |
| resetToDefaults | - | void | - |
| updateSetting | keyPath, value | void | - |

---

## 5. BreakReminderServiceProtocol

休憩リマインダーサービスのインターフェース。

```swift
import Combine

/// 休憩リマインダーサービスプロトコル
protocol BreakReminderServiceProtocol {

    // MARK: - Properties

    /// 現在の休憩リマインダー状態
    var reminder: CurrentValueSubject<BreakReminder, Never> { get }

    /// 次の休憩までの残り時間（秒）
    var timeUntilNextBreak: CurrentValueSubject<TimeInterval?, Never> { get }

    /// リマインダーが動作中か
    var isRunning: Bool { get }

    // MARK: - Methods

    /// リマインダーを開始
    func start()

    /// リマインダーを停止
    func stop()

    /// 休憩を記録
    func recordBreak()

    /// スヌーズ（5分後に再通知）
    func snooze()

    /// 休憩間隔を更新
    /// - Parameter minutes: 新しい間隔（分）
    func updateInterval(minutes: Int)
}
```

### 入出力仕様

| メソッド | 入力 | 出力 | エラー |
|---------|------|------|--------|
| start | - | void | - |
| stop | - | void | - |
| recordBreak | - | void | - |
| snooze | - | void | - |
| updateInterval | minutes: Int | void | - |

---

## 6. StretchServiceProtocol

ストレッチガイドサービスのインターフェース。

```swift
import Combine

/// ストレッチサービスプロトコル
protocol StretchServiceProtocol {

    // MARK: - Properties

    /// 利用可能なストレッチ一覧
    var stretches: [Stretch] { get }

    /// 現在のセッション
    var currentSession: CurrentValueSubject<StretchSession?, Never> { get }

    /// セッションが進行中か
    var isSessionActive: Bool { get }

    // MARK: - Methods

    /// 新しいストレッチセッションを開始
    /// - Parameter stretches: セッションに含めるストレッチ（nilの場合は全て）
    func startSession(stretches: [Stretch]?)

    /// セッションを終了
    func endSession()

    /// 現在のストレッチを完了し、次に進む
    func nextStretch()

    /// 現在のストレッチをスキップ
    func skipStretch()

    /// セッションを一時停止
    func pauseSession()

    /// セッションを再開
    func resumeSession()

    /// カテゴリでストレッチをフィルタ
    /// - Parameter category: ストレッチカテゴリ
    /// - Returns: フィルタされたストレッチ
    func stretches(for category: StretchCategory) -> [Stretch]
}
```

### 入出力仕様

| メソッド | 入力 | 出力 | エラー |
|---------|------|------|--------|
| startSession | stretches: [Stretch]? | void | - |
| endSession | - | void | - |
| nextStretch | - | void | - |
| skipStretch | - | void | - |
| pauseSession | - | void | - |
| resumeSession | - | void | - |
| stretches(for:) | category: StretchCategory | [Stretch] | - |

---

## サービス依存関係図

```
┌─────────────────────────────────────────────────────────────┐
│                       AppDelegate                           │
│  (アプリのエントリーポイント、サービスの初期化と管理)           │
└─────────────────────────────────────────────────────────────┘
                              │
          ┌───────────────────┼───────────────────┐
          │                   │                   │
          ▼                   ▼                   ▼
┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐
│  CameraService   │ │ SettingsService  │ │NotificationService│
└──────────────────┘ └──────────────────┘ └──────────────────┘
          │                   │                   ▲
          │                   │                   │
          ▼                   ▼                   │
┌──────────────────┐ ┌──────────────────┐         │
│PostureDetection  │ │BreakReminder     │─────────┘
│Service           │ │Service           │
└──────────────────┘ └──────────────────┘
          │                   │
          │                   ▼
          │          ┌──────────────────┐
          │          │ StretchService   │
          │          └──────────────────┘
          │                   │
          └───────────────────┴───────────────────┐
                              ▼                   │
┌─────────────────────────────────────────────────────────────┐
│                       Views (SwiftUI)                       │
│  PopoverView, SettingsView, StretchGuideView                │
└─────────────────────────────────────────────────────────────┘
```

---

## 依存性注入

サービスはプロトコルベースで設計され、依存性注入を通じて提供されます。

```swift
/// 依存性コンテナ
class ServiceContainer {
    static let shared = ServiceContainer()

    lazy var cameraService: CameraServiceProtocol = CameraService()
    lazy var settingsService: SettingsServiceProtocol = SettingsService()
    lazy var notificationService: NotificationServiceProtocol = NotificationService()

    lazy var postureDetectionService: PostureDetectionServiceProtocol = {
        PostureDetectionService(cameraService: cameraService)
    }()

    lazy var breakReminderService: BreakReminderServiceProtocol = {
        BreakReminderService(
            notificationService: notificationService,
            settingsService: settingsService
        )
    }()

    lazy var stretchService: StretchServiceProtocol = StretchService()
}
```

### テスト用モック

```swift
/// テスト用のモックサービス
class MockPostureDetectionService: PostureDetectionServiceProtocol {
    var currentPosture = CurrentValueSubject<PostureState?, Never>(nil)
    var isDetecting = false

    // テスト用のスタブ実装
    func startDetection(cameraDeviceID: String?) async throws {
        isDetecting = true
    }

    func stopDetection() {
        isDetecting = false
    }

    // ...
}
```
