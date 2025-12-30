# Data Model: 姿勢スコア表示機能

**Feature**: 001-posture-score
**Date**: 2025-12-30
**Status**: Complete

## Overview

姿勢スコア表示機能で使用するデータモデルを定義する。永続化は不要であり、全てインメモリで管理する。

---

## Entities

### 1. PostureScore

姿勢の分析結果を表すスコア。

```swift
/// 姿勢スコア (0-100)
struct PostureScore: Sendable, Equatable {
    /// スコア値 (0: 最悪 〜 100: 最良)
    let value: Int

    /// スコア算出時刻
    let timestamp: Date

    /// 各評価項目の詳細スコア
    let breakdown: ScoreBreakdown

    /// 検出の信頼度 (0.0 〜 1.0)
    let confidence: Double
}
```

**Validation Rules**:
- `value`: 0 ≤ value ≤ 100
- `confidence`: 0.0 ≤ confidence ≤ 1.0
- `timestamp`: 現在時刻以前

**Relationships**:
- `breakdown` → ScoreBreakdown (1:1)

---

### 2. ScoreBreakdown

スコアの内訳。デバッグおよび将来の詳細表示用。

```swift
/// スコアの構成要素
struct ScoreBreakdown: Sendable, Equatable {
    /// 頭部傾斜スコア (0-100)
    let headTilt: Int

    /// 肩バランススコア (0-100)
    let shoulderBalance: Int

    /// 前傾姿勢スコア (0-100)
    let forwardLean: Int

    /// 左右対称性スコア (0-100)
    let symmetry: Int
}
```

**Validation Rules**:
- 全フィールド: 0 ≤ value ≤ 100

---

### 3. MonitoringState

アプリの監視状態を表す列挙型。

```swift
/// 姿勢監視の状態
enum MonitoringState: Sendable, Equatable {
    /// 正常に監視中
    case active(PostureScore)

    /// 一時停止（人物未検出、カメラ利用不可など）
    case paused(PauseReason)

    /// 無効（カメラ権限なし）
    case disabled(DisableReason)
}
```

**State Transitions**:

```
                    ┌─────────────────┐
                    │     Initial     │
                    └────────┬────────┘
                             │
              ┌──────────────┴──────────────┐
              ▼                             ▼
     ┌────────────────┐           ┌─────────────────┐
     │    disabled    │           │     paused      │
     │ (権限なし)      │           │ (権限あり,      │
     └────────────────┘           │  カメラ準備中)   │
              │                   └────────┬────────┘
              │ 権限付与                    │ 人物検出
              ▼                             ▼
     ┌────────────────┐           ┌─────────────────┐
     │    paused      │◀─────────▶│     active      │
     │ (人物未検出)    │  検出/喪失  │ (監視中)        │
     └────────────────┘           └─────────────────┘
```

---

### 4. PauseReason

一時停止の理由。

```swift
/// 監視一時停止の理由
enum PauseReason: Sendable, Equatable {
    /// カメラの準備中
    case cameraInitializing

    /// 人物が検出されない
    case noPersonDetected

    /// カメラが他のアプリで使用中（共有不可の場合）
    case cameraInUse

    /// カメラが物理的に遮蔽されている
    case cameraObstructed

    /// 照明条件が悪く検出不能
    case poorLighting
}
```

---

### 5. DisableReason

無効状態の理由。

```swift
/// 監視無効の理由
enum DisableReason: Sendable, Equatable {
    /// カメラアクセス権限が拒否されている
    case cameraPermissionDenied

    /// カメラアクセス権限が制限されている（ペアレンタルコントロール等）
    case cameraPermissionRestricted

    /// カメラデバイスが存在しない
    case noCameraAvailable
}
```

---

### 6. JointPosition

Vision フレームワークから取得した関節位置。

```swift
/// 正規化された関節位置
struct JointPosition: Sendable, Equatable {
    /// X座標 (0.0 = 左端, 1.0 = 右端)
    let x: Double

    /// Y座標 (0.0 = 下端, 1.0 = 上端)
    let y: Double

    /// 検出の信頼度 (0.0 〜 1.0)
    let confidence: Double
}
```

**Validation Rules**:
- `x`, `y`: 0.0 ≤ value ≤ 1.0
- `confidence`: 0.0 ≤ confidence ≤ 1.0

---

### 7. BodyPose

検出された上半身の姿勢データ。

```swift
/// 上半身の姿勢データ
struct BodyPose: Sendable, Equatable {
    let nose: JointPosition?
    let neck: JointPosition?
    let leftShoulder: JointPosition?
    let rightShoulder: JointPosition?
    let leftEar: JointPosition?
    let rightEar: JointPosition?
    let root: JointPosition?

    /// 検出時刻
    let timestamp: Date

    /// 姿勢スコア算出に必要な関節が全て検出されているか
    var isValid: Bool {
        [neck, leftShoulder, rightShoulder].allSatisfy { joint in
            guard let joint = joint else { return false }
            return joint.confidence >= 0.5
        }
    }
}
```

**Relationships**:
- 各関節 → JointPosition (0..1)

---

### 8. IconColor

メニューバーアイコンの色。

```swift
/// アイコンの表示色
struct IconColor: Sendable, Equatable {
    /// 色相 (0.0 = 赤, 0.33 = 緑)
    let hue: Double

    /// 彩度 (0.0 〜 1.0)
    let saturation: Double

    /// 明度 (0.0 〜 1.0)
    let brightness: Double

    /// グレー表示かどうか
    let isGray: Bool

    /// スコアから色を生成
    static func from(score: Int) -> IconColor {
        let hue = Double(score) / 100.0 * 0.33 // 0° 〜 120°
        return IconColor(
            hue: hue,
            saturation: 0.8,
            brightness: 0.9,
            isGray: false
        )
    }

    /// グレー状態
    static let gray = IconColor(
        hue: 0,
        saturation: 0,
        brightness: 0.5,
        isGray: true
    )
}
```

---

## ViewModel State

### PostureMonitorState

UI 層で管理するアプリ全体の状態。

```swift
/// 姿勢モニターの状態（@Observable）
@Observable
final class PostureMonitorState: @unchecked Sendable {
    /// 現在の監視状態
    var monitoringState: MonitoringState = .paused(.cameraInitializing)

    /// 現在のアイコン色
    var iconColor: IconColor = .gray

    /// スコア履歴 (スムージング用、最大10件)
    var scoreHistory: [PostureScore] = []

    /// 平滑化されたスコア
    var smoothedScore: Int {
        guard !scoreHistory.isEmpty else { return 0 }
        let sum = scoreHistory.reduce(0) { $0 + $1.value }
        return sum / scoreHistory.count
    }
}
```

---

## Type Summary

| Entity | Persistence | Sendable | Usage |
|--------|-------------|----------|-------|
| PostureScore | No | Yes | スコア値と内訳 |
| ScoreBreakdown | No | Yes | スコアの詳細内訳 |
| MonitoringState | No | Yes | 監視状態の管理 |
| PauseReason | No | Yes | 一時停止理由 |
| DisableReason | No | Yes | 無効化理由 |
| JointPosition | No | Yes | 関節座標 |
| BodyPose | No | Yes | 検出された姿勢 |
| IconColor | No | Yes | アイコン色 |
| PostureMonitorState | No | No* | ViewModel状態 |

\* `@unchecked Sendable` - メインスレッドでのみアクセス

---

## Validation Summary

全エンティティで以下を保証:

1. **Range Validation**: スコアは 0-100、座標は 0.0-1.0
2. **Null Safety**: Optional を適切に使用、Force unwrap なし
3. **Thread Safety**: `Sendable` 準拠で並行処理に対応
4. **Immutability**: 値型 (struct/enum) で不変性を保証
