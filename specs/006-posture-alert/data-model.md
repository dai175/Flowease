# Data Model: 姿勢アラート通知機能

**Date**: 2026-01-11
**Feature**: 006-posture-alert

## Entity Relationship

```
┌─────────────────┐     uses      ┌─────────────────┐
│  ScoreHistory   │──────────────▶│   ScoreRecord   │
└─────────────────┘               └─────────────────┘
        │
        │ evaluates
        ▼
┌─────────────────┐     uses      ┌─────────────────┐
│PostureAlertSvc  │──────────────▶│   AlertState    │
└─────────────────┘               └─────────────────┘
        │
        │ reads
        ▼
┌─────────────────┐   persisted   ┌─────────────────┐
│ AlertSettings   │◀─────────────▶│AlertSettingsStg │
└─────────────────┘               └─────────────────┘
```

## Entities

### ScoreRecord

個々の姿勢スコアとタイムスタンプを保持する軽量な構造体。

```swift
/// 姿勢スコアの記録
struct ScoreRecord: Sendable, Equatable {
    /// スコア値 (0-100)
    let value: Int

    /// 記録時刻
    let timestamp: Date
}
```

**Validation Rules**:
- `value`: 0〜100の範囲（既存PostureScoreから取得するため保証済み）
- `timestamp`: 現在時刻以前

### AlertSettings

通知に関するユーザー設定を保持する構造体。

```swift
/// 通知設定
struct AlertSettings: Sendable, Equatable, Codable {
    /// 通知機能の有効/無効
    var isEnabled: Bool

    /// 閾値スコア (20-80)
    /// この値以下の平均スコアで通知をトリガー
    var threshold: Int

    /// 評価期間（秒）(60-600、つまり1-10分)
    /// この期間の平均スコアを計算
    var evaluationPeriodSeconds: Int

    /// 最短通知間隔（秒）(300-3600、つまり5-60分)
    /// 前回通知からこの時間が経過するまで再通知しない
    var minimumIntervalSeconds: Int

    /// デフォルト設定
    static let `default` = AlertSettings(
        isEnabled: true,
        threshold: 60,
        evaluationPeriodSeconds: 300,  // 5分
        minimumIntervalSeconds: 900    // 15分
    )
}
```

**Validation Rules**:
- `threshold`: 20〜80の範囲
- `evaluationPeriodSeconds`: 60〜600の範囲（1〜10分）
- `minimumIntervalSeconds`: 300〜3600の範囲（5〜60分）

**Computed Properties**:
```swift
extension AlertSettings {
    /// 評価期間（分）- UI表示用
    var evaluationPeriodMinutes: Int {
        get { evaluationPeriodSeconds / 60 }
        set { evaluationPeriodSeconds = newValue * 60 }
    }

    /// 最短通知間隔（分）- UI表示用
    var minimumIntervalMinutes: Int {
        get { minimumIntervalSeconds / 60 }
        set { minimumIntervalSeconds = newValue * 60 }
    }
}
```

### AlertState

通知の状態管理を担う構造体。再通知判定に使用。

```swift
/// 通知状態
struct AlertState: Sendable, Equatable {
    /// 最後に通知を送信した時刻（nil = 未送信）
    var lastNotificationTime: Date?

    /// 姿勢改善済みフラグ
    /// true: 前回通知後に姿勢が改善された（再度悪化したら通知可能）
    /// false: 前回通知後、まだ姿勢が改善されていない
    var hasImprovedSinceLastNotification: Bool

    /// 初期状態
    static let initial = AlertState(
        lastNotificationTime: nil,
        hasImprovedSinceLastNotification: true
    )
}
```

**State Transitions**:

```
[Initial] ──通知送信──▶ [Notified]
    ▲                      │
    │                      │
    │                 ┌────┴────┐
    │                 ▼         ▼
    │           [姿勢改善]  [間隔経過]
    │                 │         │
    └──────────通知送信◀─────────┘
```

1. **Initial → Notified**: 平均スコアが閾値以下で通知送信
2. **Notified → 姿勢改善**: 平均スコアが閾値を超える → `hasImprovedSinceLastNotification = true`
3. **姿勢改善 → Notified**: 再度平均スコアが閾値以下 → 通知送信
4. **Notified → 間隔経過**: 姿勢改善なしで最短間隔経過 → リマインド通知送信

## Storage Schema

### UserDefaults Keys

```swift
/// ストレージキーの定数（既存のCalibrationStorageKeys パターンに準拠）
enum AlertSettingsKeys {
    static let isEnabled = "flowease.alert.isEnabled"
    static let threshold = "flowease.alert.threshold"
    static let evaluationPeriod = "flowease.alert.evaluationPeriod"
    static let minimumInterval = "flowease.alert.minimumInterval"
}
```

### Data Types in UserDefaults

| Key | Type | Default |
|-----|------|---------|
| `flowease.alert.isEnabled` | Bool | true |
| `flowease.alert.threshold` | Int | 60 |
| `flowease.alert.evaluationPeriod` | Int | 300 |
| `flowease.alert.minimumInterval` | Int | 900 |

## Memory Management

### ScoreHistory

```swift
/// スコア履歴管理
final class ScoreHistory: @unchecked Sendable {
    /// 履歴データ（新しい順）
    private var records: [ScoreRecord] = []

    /// 最大保持期間（秒）
    /// 設定の最大評価期間 + バッファ
    private let maxRetentionSeconds: Int = 660  // 11分

    /// スコアを追加し、古いデータを削除
    func add(_ score: PostureScore) {
        let record = ScoreRecord(value: score.value, timestamp: score.timestamp)
        records.insert(record, at: 0)
        pruneOldRecords()
    }

    /// 指定期間内の平均スコアを計算
    func averageScore(within seconds: Int) -> Double? {
        let cutoff = Date().addingTimeInterval(-Double(seconds))
        let relevant = records.filter { $0.timestamp >= cutoff }
        guard !relevant.isEmpty else { return nil }
        return Double(relevant.map(\.value).reduce(0, +)) / Double(relevant.count)
    }

    /// 指定期間内のデータ充足率を計算
    func dataCompleteness(within seconds: Int, expectedInterval: TimeInterval = 1.0) -> Double {
        let cutoff = Date().addingTimeInterval(-Double(seconds))
        let count = records.filter { $0.timestamp >= cutoff }.count
        let expected = Double(seconds) / expectedInterval
        return min(Double(count) / expected, 1.0)
    }

    private func pruneOldRecords() {
        let cutoff = Date().addingTimeInterval(-Double(maxRetentionSeconds))
        records.removeAll { $0.timestamp < cutoff }
    }
}
```
