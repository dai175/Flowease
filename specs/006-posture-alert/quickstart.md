# Quickstart: 姿勢アラート通知機能

**Date**: 2026-01-11
**Feature**: 006-posture-alert

## 概要

この機能は、悪い姿勢が一定期間続いた場合にmacOS通知でユーザーに気づきを与えます。

## アーキテクチャ

```
┌─────────────┐    PostureScore    ┌──────────────┐
│  AppState   │───────────────────▶│ ScoreHistory │
└─────────────┘                    └──────┬───────┘
                                          │
                                          │ average
                                          ▼
┌─────────────┐    settings        ┌──────────────────────┐
│AlertSettings│◀──────────────────▶│ PostureAlertService  │
│  Storage    │                    └──────────┬───────────┘
└─────────────┘                               │
                                              │ notify
                                              ▼
                                   ┌──────────────────────┐
                                   │ NotificationManager  │
                                   └──────────────────────┘
```

## 主要コンポーネント

### 1. ScoreHistory
スコアの時系列データを管理。評価期間内の平均スコアを計算。

```swift
let history = ScoreHistory()
history.add(postureScore)
let average = history.averageScore(within: 300) // 5分間の平均
```

### 2. AlertSettings
ユーザー設定を保持。

```swift
var settings = AlertSettings.default
settings.threshold = 60        // 閾値60以下で通知
settings.evaluationPeriodSeconds = 300  // 5分間の平均
settings.minimumIntervalSeconds = 900   // 15分間隔
```

### 3. PostureAlertService
通知判定ロジックを実装。

```swift
let service = PostureAlertService(
    history: history,
    settings: settings,
    notificationManager: notificationManager
)

// スコア更新のたびに呼び出す
service.evaluate()
```

### 4. NotificationManager
macOS通知の送信を担当。

```swift
let manager = NotificationManager()
await manager.requestAuthorization()
await manager.sendPostureAlert()
```

## 統合フロー

```swift
// AppState.swift での統合例

@Observable
final class AppState {
    private let scoreHistory = ScoreHistory()
    private let alertService: PostureAlertService

    func updatePostureScore(_ score: PostureScore) {
        self.postureScore = score
        scoreHistory.add(score)
        alertService.evaluate()
    }
}
```

## 通知判定アルゴリズム

```
1. 評価期間内のデータ充足率をチェック
   - 50%未満 → 判定スキップ

2. 平均スコアを計算

3. 平均スコア > 閾値?
   - Yes → 姿勢改善フラグをtrue、終了
   - No → 次へ

4. 通知可能か判定:
   - 姿勢改善フラグがtrue → 通知可能
   - 最短間隔が経過 → 通知可能
   - どちらでもない → 終了

5. 通知送信
   - lastNotificationTime を更新
   - 姿勢改善フラグをfalse
```

## テスト方法

### ユニットテスト

```swift
// ScoreHistoryTests
func testAverageCalculation() {
    let history = ScoreHistory()
    history.add(PostureScore(value: 50, ...))
    history.add(PostureScore(value: 70, ...))
    XCTAssertEqual(history.averageScore(within: 60), 60.0)
}

// PostureAlertServiceTests
func testNotificationTriggered() {
    // 閾値60、5分間平均50のスコアを追加
    // 通知が送信されることを確認
}
```

### 手動テスト

1. アプリを起動
2. 設定で評価期間を1分に変更
3. 意図的に悪い姿勢を維持
4. 1分後に通知が届くことを確認
5. 姿勢を正して、不要な通知が来ないことを確認

## 設定UI

```
┌─────────────────────────────────┐
│ 通知設定                         │
├─────────────────────────────────┤
│ ☑ 通知を有効化                   │
│                                 │
│ 閾値スコア        [===60===] 60  │
│                                 │
│ 評価期間          [===5====] 5分 │
│                                 │
│ 最短通知間隔      [===15===] 15分│
└─────────────────────────────────┘
```

## ローカライズ

通知テキスト:
- EN: "Your posture needs attention"
- JA: "姿勢が崩れています"

設定ラベル:
- EN: "Alert Settings" / JA: "通知設定"
- EN: "Enable Alerts" / JA: "通知を有効化"
- EN: "Score Threshold" / JA: "閾値スコア"
- EN: "Evaluation Period" / JA: "評価期間"
- EN: "Minimum Interval" / JA: "最短通知間隔"
