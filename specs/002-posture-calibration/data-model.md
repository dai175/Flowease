# Data Model: 姿勢キャリブレーション機能

**Feature**: 002-posture-calibration
**Date**: 2026-01-01

## Entity Relationship Diagram

```
┌─────────────────────────┐
│   ReferencePosture      │
├─────────────────────────┤
│ + nose: ReferenceJointPosition? │
│ + neck: ReferenceJointPosition  │
│ + leftShoulder: Ref...  │
│ + rightShoulder: Ref... │
│ + leftEar: ReferenceJ.? │
│ + rightEar: ReferenceJ.?│
│ + root: ReferenceJointPosition? │
│ + calibratedAt: Date    │
│ + frameCount: Int       │
│ + averageConfidence: Dbl│
├─────────────────────────┤
│ + baselineMetrics: ...  │ ──┐
└─────────────────────────┘   │
                              │
┌─────────────────────────┐   │
│   BaselineMetrics       │◄──┘
├─────────────────────────┤
│ + headTiltDeviation: Dbl│
│ + shoulderBalance: Dbl  │
│ + forwardLean: Double   │
│ + symmetry: Double      │
└─────────────────────────┘

┌─────────────────────────┐
│   ReferenceJointPosition        │
├─────────────────────────┤
│ + x: Double             │
│ + y: Double             │
│ + confidence: Double    │
└─────────────────────────┘

┌─────────────────────────┐
│   CalibrationState      │
├─────────────────────────┤
│ case notCalibrated      │
│ case inProgress(prog.)  │
│ case completed          │
│ case failed(reason)     │
└─────────────────────────┘

┌─────────────────────────┐
│   CalibrationProgress   │
├─────────────────────────┤
│ + startTime: Date       │
│ + collectedFrames: Int  │
│ + targetDuration: TI    │
│ + lowConfidenceStreak: I│
└─────────────────────────┘

┌─────────────────────────┐
│   CalibrationFailure    │
├─────────────────────────┤
│ case noPersonDetected   │
│ case lowConfidence      │
│ case insufficientFrames │
│ case cancelled          │
└─────────────────────────┘
```

## Entities

### ReferencePosture

ユーザーがキャリブレーションで設定した基準姿勢。

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| nose | ReferenceJointPosition? | No | 鼻の平均位置 |
| neck | ReferenceJointPosition | Yes | 首の平均位置（必須） |
| leftShoulder | ReferenceJointPosition | Yes | 左肩の平均位置（必須） |
| rightShoulder | ReferenceJointPosition | Yes | 右肩の平均位置（必須） |
| leftEar | ReferenceJointPosition? | No | 左耳の平均位置 |
| rightEar | ReferenceJointPosition? | No | 右耳の平均位置 |
| root | ReferenceJointPosition? | No | 体の中心の平均位置 |
| calibratedAt | Date | Yes | キャリブレーション完了日時 |
| frameCount | Int | Yes | 平均化に使用したフレーム数 |
| averageConfidence | Double | Yes | 全フレームの平均信頼度 |
| baselineMetrics | BaselineMetrics | Yes | 基準姿勢時の各評価項目の値 |

**Validation Rules**:
- neck, leftShoulder, rightShoulderは必須
- frameCount >= 30（最低1秒分のフレーム）
- averageConfidence >= 0.7

**Codable**: Yes (UserDefaults永続化用)

### ReferenceJointPosition

基準姿勢における関節の平均位置。

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| x | Double | Yes | X座標（0.0-1.0の正規化値） |
| y | Double | Yes | Y座標（0.0-1.0の正規化値） |
| confidence | Double | Yes | 平均信頼度（0.0-1.0） |

**Validation Rules**:
- x, y: 0.0 <= value <= 1.0
- confidence: 0.0 <= value <= 1.0

**Codable**: Yes

### BaselineMetrics

基準姿勢時の各評価項目の計算値。スコア計算時にこの値をゼロ点として使用。

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| headTiltDeviation | Double | Yes | 頭傾き: 首-鼻のX座標差（左右の傾き） |
| shoulderBalance | Double | Yes | 肩バランス: 左右肩のY座標差 |
| forwardLean | Double | Yes | 前傾: 首-鼻のY座標差（前傾時は鼻が下がる） |
| symmetry | Double | Yes | 対称性: 平均偏差値 |

**Codable**: Yes

### CalibrationState

キャリブレーションの現在状態を表す列挙型。

| Case | Associated Value | Description |
|------|-----------------|-------------|
| notCalibrated | - | キャリブレーション未実行 |
| inProgress | CalibrationProgress | キャリブレーション実行中 |
| completed | - | キャリブレーション完了 |
| failed | CalibrationFailure | キャリブレーション失敗 |

### CalibrationProgress

キャリブレーション進行状況。

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| startTime | Date | Yes | 開始時刻 |
| collectedFrames | Int | Yes | 収集済みフレーム数 |
| targetDuration | TimeInterval | Yes | 目標時間（3.0秒） |
| lowConfidenceStreak | Int | Yes | 低信頼度の連続フレーム数 |

**Computed Properties**:
- `progress: Double` → 0.0〜1.0の進捗率
- `remainingSeconds: Double` → 残り秒数
- `shouldFail: Bool` → lowConfidenceStreak >= 30 (約1秒)

### CalibrationFailure

キャリブレーション失敗の理由。

| Case | Description | User Message |
|------|-------------|--------------|
| noPersonDetected | 人物が検出されなかった | 「カメラに映るようにしてください」 |
| lowConfidence | 信頼度が低い状態が続いた | 「照明を調整してください」 |
| insufficientFrames | 十分なフレームが収集できなかった | 「もう一度お試しください」 |
| cancelled | ユーザーがキャンセル | - |

## State Transitions

```
                    ┌─────────────────┐
                    │  notCalibrated  │
                    └────────┬────────┘
                             │ startCalibration()
                             ▼
                    ┌─────────────────┐
           ┌───────│   inProgress    │───────┐
           │       └────────┬────────┘       │
           │                │                │
    cancel() or        complete()       failure detected
    timeout             success
           │                │                │
           ▼                ▼                ▼
    ┌──────────┐    ┌─────────────┐    ┌──────────┐
    │  failed  │    │  completed  │    │  failed  │
    │(cancelled)│    └──────┬──────┘    │ (reason) │
    └──────────┘           │           └──────────┘
           │               │                │
           └───────────────┼────────────────┘
                           │ reset()
                           ▼
                    ┌─────────────────┐
                    │  notCalibrated  │
                    └─────────────────┘
```

## Persistence

### UserDefaults Keys

| Key | Type | Description |
|-----|------|-------------|
| `flowease.calibration.referencePosture` | Data (JSON) | ReferencePostureのエンコード済みデータ |

**Note**: `completedAt` は `ReferencePosture.calibratedAt` に含まれるため別途保存しない。

### State Derivation

CalibrationStateは永続化せず、`referencePosture` の有無から導出する:

| referencePosture | 導出される状態 |
|------------------|---------------|
| nil | `notCalibrated` |
| 存在する | `completed` |

`inProgress` / `failed` は一時的な状態であり、アプリ再起動時には `notCalibrated` または `completed` に復帰する。

### Migration Strategy

- 既存ユーザー: 初回起動時は`notCalibrated`状態
- フォールバック: ReferencePosture読み込み失敗時は固定しきい値モード

## Relationships to Existing Models

### BodyPose → ReferencePosture

- `ReferencePosture`は複数の`BodyPose`から平均化して生成
- 構造は類似（同じ関節セット）だが、ReferencePostureは永続化のためCodable

### ScoreCalculator ← ReferencePosture

- ScoreCalculatorは`ReferencePosture`を参照してスコア計算
- `ReferencePosture.baselineMetrics`を使用して逸脱度を計算
