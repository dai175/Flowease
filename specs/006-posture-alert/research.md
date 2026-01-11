# Research: 姿勢アラート通知機能

**Date**: 2026-01-11
**Feature**: 006-posture-alert

## 1. macOS通知API

### Decision
`UserNotifications` フレームワークの `UNUserNotificationCenter` を使用する。

### Rationale
- macOS 10.14以降で標準提供
- 権限管理が組み込み済み
- ローカル通知に最適
- アプリがバックグラウンドでも配信可能

### Alternatives Considered
- **NSUserNotification** (非推奨): macOS 11で廃止
- **カスタムポップオーバー**: システム通知の一貫性を損なう

### Implementation Notes
```swift
import UserNotifications

// 権限リクエスト
UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])

// 通知送信
let content = UNMutableNotificationContent()
content.title = "Flowease"
content.body = String(localized: "Your posture needs attention")
let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
UNUserNotificationCenter.current().add(request)
```

## 2. スコア履歴の保持方法

### Decision
メモリ内の配列で保持し、評価期間を超えた古いデータは自動的に削除する。永続化はしない。

### Rationale
- 評価期間は最大10分（設定範囲: 1-10分）
- スコアは約1秒間隔で更新（最大600件程度）
- メモリ効率が良く、実装がシンプル
- アプリ再起動時にリセットされても問題ない（新たにデータ蓄積開始）

### Alternatives Considered
- **UserDefaults**: 頻繁な書き込みで非効率
- **Core Data**: 過剰な複雑さ
- **ファイル**: 不要な永続化

### Data Structure
```swift
struct ScoreRecord: Sendable {
    let value: Int       // 0-100
    let timestamp: Date
}

// 時系列配列（新しい順）
var history: [ScoreRecord] = []
```

## 3. 設定の永続化

### Decision
`UserDefaults` を使用する。既存の `CalibrationStorage` パターンを踏襲。

### Rationale
- 少量のシンプルなデータ（4つの設定値）
- 既存パターンとの一貫性
- 追加の依存なし

### Implementation Notes
```swift
// Keys（既存のCalibrationStorageKeys パターンに準拠）
enum AlertSettingsKeys {
    static let isEnabled = "flowease.alert.isEnabled"
    static let threshold = "flowease.alert.threshold"
    static let evaluationPeriod = "flowease.alert.evaluationPeriod"
    static let minimumInterval = "flowease.alert.minimumInterval"
}
```

## 4. 通知判定のタイミング

### Decision
スコアが更新されるたびに判定を実行する（イベント駆動）。

### Rationale
- スコア更新頻度（約1秒間隔）で十分
- 追加のタイマー不要
- リソース効率が良い

### Alternatives Considered
- **定期タイマー**: 不必要なCPU使用
- **バッチ処理**: リアルタイム性が低下

## 5. ローカライゼーション

### Decision
既存の `Localizable.xcstrings` に通知テキストを追加する。

### Strings to Add
| Key | English | Japanese |
|-----|---------|----------|
| `alert.title` | Flowease | Flowease |
| `alert.body` | Your posture needs attention | 姿勢が崩れています |
| `alert.settings.title` | Alert Settings | 通知設定 |
| `alert.settings.enabled` | Enable Alerts | 通知を有効化 |
| `alert.settings.threshold` | Score Threshold | 閾値スコア |
| `alert.settings.period` | Evaluation Period | 評価期間 |
| `alert.settings.interval` | Minimum Interval | 最短通知間隔 |

## 6. 既存コードとの統合ポイント

### AppState.swift
- `PostureAlertService` のインスタンスを保持
- スコア更新時に通知判定を呼び出す

### Integration Flow
```
CameraService → PostureAnalyzer → FaceScoreCalculator → PostureScore
                                                            ↓
                                                    AppState.updateScore()
                                                            ↓
                                                    ScoreHistory.add()
                                                            ↓
                                                    PostureAlertService.evaluate()
                                                            ↓
                                                    NotificationManager.send() (if needed)
```

## Summary

すべての技術的な疑問点は解決済み。既存のアーキテクチャパターンを踏襲し、標準フレームワークのみで実装可能。
