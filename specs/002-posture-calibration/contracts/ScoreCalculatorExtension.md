# Contract: ScoreCalculator Extension

**Feature**: 002-posture-calibration

ScoreCalculatorのキャリブレーション対応拡張インターフェース。

## 概要

既存のScoreCalculatorを拡張して、基準姿勢からの逸脱度に基づくスコア計算を追加する。

## 変更点

### 新規プロパティ

```swift
/// 基準姿勢（nil時は固定しきい値モード）
var referencePosture: ReferencePosture?
```

### 新規メソッド

```swift
/// 基準姿勢を設定する
func setReferencePosture(_ referencePosture: ReferencePosture?)

/// キャリブレーションモードかどうか
var isCalibrated: Bool { get }
```

### calculate(from:) の変更

既存の `calculate(from pose: BodyPose)` メソッドの内部ロジックを以下のように変更:

1. `referencePosture` が nil の場合:
   - 既存の固定しきい値を使用してスコア計算（現在の動作を維持）

2. `referencePosture` が設定されている場合:
   - 各評価項目について、現在値と基準値の差分を計算
   - 差分を偏差としてスコア計算

### 差分計算の詳細

```swift
// 頭傾きの例
let currentDeviation = abs(pose.nose.x - pose.neck.x)
let baselineDeviation = referencePosture.baselineMetrics.headTiltDeviation
let relativeDeviation = abs(currentDeviation - baselineDeviation)

// relativeDeviation を既存の calculateScoreFromDeviation に渡す
```

## 後方互換性

- `referencePosture` が nil の場合は既存動作を維持
- 既存のテストは変更なしでパスすること
- 新規テストで基準姿勢ありのケースをカバー

## BaselineMetrics Calculation

ReferencePostureからBaselineMetricsを計算する方法:

```swift
extension ReferencePosture {
    /// 基準姿勢から評価項目の基準値を計算
    func calculateBaselineMetrics() -> BaselineMetrics {
        // 頭傾き: 鼻と首のX座標差（左右の傾き）
        let headTilt = abs((nose?.x ?? neck.x) - neck.x)

        // 肩バランス: 左右肩のY座標差
        let shoulderBalance = abs(leftShoulder.y - rightShoulder.y)

        // 前傾: 首と鼻のY座標差（前傾時は鼻が下がる）
        // Vision座標系: Y=0が下端、Y=1が上端
        // 前傾すると鼻が首より下に来るため、neck.y - nose.y が正になる
        let forwardLean = max(0, neck.y - (nose?.y ?? neck.y))

        // 対称性: 複数の対称性指標の平均
        let symmetry = calculateSymmetryBaseline()

        return BaselineMetrics(
            headTiltDeviation: headTilt,
            shoulderBalance: shoulderBalance,
            forwardLean: forwardLean,
            symmetry: symmetry
        )
    }
}
```

**Note**: 前傾の測定はX座標ではなくY座標を使用する。これにより頭傾き（X座標差）と前傾（Y座標差）が独立した指標となる。
