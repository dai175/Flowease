# Data Model: 顔検出ベースの姿勢検知

**Feature**: 003-face-detection
**Date**: 2026-01-02
**Status**: Draft

## Overview

顔検出ベースの姿勢評価に必要なエンティティ定義。既存のMVVMアーキテクチャを維持しつつ、体検出から顔検出への移行を行う。

## Entity Definitions

### 1. FacePosition (NEW)

**Purpose**: 単一フレームの顔検出結果を保持

**Location**: `Flowease/Models/FacePosition.swift`

```swift
/// 顔検出結果データ
///
/// VNFaceObservationから取得した顔の位置・サイズ・傾き情報を保持する。
/// 姿勢スコアの算出に使用される。
struct FacePosition: Sendable, Equatable {
    /// 顔中心のX座標（正規化座標 0-1）
    let centerX: Double

    /// 顔中心のY座標（正規化座標 0-1、Y=0が下端）
    let centerY: Double

    /// 顔の面積（width × height、正規化座標）
    let area: Double

    /// 顔の傾き（roll角、ラジアン単位、[-π, π)）
    /// nilの場合はroll角取得不可
    let roll: Double?

    /// 検出品質（0-1、VNDetectFaceCaptureQualityRequest由来）
    let captureQuality: Double

    /// 検出時刻
    let timestamp: Date

    /// 最小検出品質しきい値
    static let minimumCaptureQuality: Double = 0.3

    /// 検出品質が十分かどうか
    var hasAcceptableQuality: Bool {
        captureQuality >= Self.minimumCaptureQuality
    }
}
```

**Validation Rules**:
- `centerX`, `centerY`: 0.0 ≤ value ≤ 1.0
- `area`: 0.0 < value ≤ 1.0
- `roll`: -π ≤ value < π (nilの場合はroll未取得)
- `captureQuality`: 0.0 ≤ value ≤ 1.0

**Relationships**:
- VNFaceObservationから生成
- FaceBaselineMetricsの算出に使用

---

### 2. FaceBaselineMetrics (NEW)

**Purpose**: キャリブレーション時の顔ベース基準値を保持

**Location**: `Flowease/Models/FaceBaselineMetrics.swift`

```swift
/// キャリブレーション時に記録された顔ベース基準値
///
/// 基準姿勢時の顔位置・サイズ・傾きを保持する。
/// スコア計算時にこの値を基準として逸脱度を算出する。
struct FaceBaselineMetrics: Codable, Sendable, Equatable {
    /// 基準顔中心Y座標（正規化座標 0-1）
    let baselineY: Double

    /// 基準顔面積（正規化座標）
    let baselineArea: Double

    /// 基準roll角（ラジアン）
    let baselineRoll: Double

    /// イニシャライザ（NaN/Infinite値を0にサニタイズ）
    init(baselineY: Double, baselineArea: Double, baselineRoll: Double) {
        self.baselineY = baselineY.isNaN || baselineY.isInfinite ? 0.5 : baselineY
        self.baselineArea = baselineArea.isNaN || baselineArea.isInfinite ? 0.01 : baselineArea
        self.baselineRoll = baselineRoll.isNaN || baselineRoll.isInfinite ? 0.0 : baselineRoll
    }
}
```

**Validation Rules**:
- `baselineY`: 0.0 ≤ value ≤ 1.0 (デフォルト 0.5)
- `baselineArea`: 0.0 < value ≤ 1.0 (デフォルト 0.01)
- `baselineRoll`: -π ≤ value < π (デフォルト 0.0)

---

### 3. FaceReferencePosture (NEW)

**Purpose**: 顔ベースのキャリブレーションデータを保持

**Location**: `Flowease/Models/FaceReferencePosture.swift`

```swift
/// 顔ベースの基準姿勢
///
/// 複数フレームから平均化された顔位置と評価項目の基準値を保持する。
/// UserDefaultsへの永続化に対応するためCodableを実装。
struct FaceReferencePosture: Codable, Sendable, Equatable {
    /// キャリブレーション完了日時
    let calibratedAt: Date

    /// 平均化に使用したフレーム数
    let frameCount: Int

    /// 全フレームの平均検出品質 (0.0〜1.0)
    let averageQuality: Double

    /// 基準姿勢時の評価項目値
    let baselineMetrics: FaceBaselineMetrics

    /// 最低必要フレーム数（約1秒分、15FPS処理前提）
    static let minimumFrameCount = 15

    /// 最低必要検出品質
    static let minimumQuality = 0.3

    /// 有効なキャリブレーションデータかどうか
    var isValid: Bool {
        frameCount >= Self.minimumFrameCount &&
            averageQuality >= Self.minimumQuality
    }

    /// イニシャライザ
    init(
        calibratedAt: Date = Date(),
        frameCount: Int,
        averageQuality: Double,
        baselineMetrics: FaceBaselineMetrics
    ) {
        self.calibratedAt = calibratedAt
        self.frameCount = max(0, frameCount)
        self.averageQuality = min(max(averageQuality, 0.0), 1.0)
        self.baselineMetrics = baselineMetrics
    }
}
```

**Validation Rules**:
- `frameCount`: ≥ 15
- `averageQuality`: ≥ 0.3

**State Transitions**:
- nil → FaceReferencePosture (キャリブレーション完了時)
- FaceReferencePosture → nil (データクリア時)
- ReferencePosture (旧形式) → nil (自動クリア)

---

### 4. PauseReason (MODIFY)

**Purpose**: 既存列挙型のメッセージ変更

**Location**: `Flowease/Models/PauseReason.swift`

**Changes**:
```swift
/// 一時停止理由
enum PauseReason: Sendable, Equatable {
    /// 顔が検出されない（変更: 「人物」→「顔」）
    case noFaceDetected  // Renamed from noPersonDetected

    /// 検出精度が低い
    case lowDetectionQuality

    /// ユーザーメッセージ
    var userMessage: String {
        switch self {
        case .noFaceDetected:
            return "顔が検出されません"  // Changed from "人物が検出されません"
        case .lowDetectionQuality:
            return "検出精度が低下しています"
        }
    }
}
```

---

### 5. ScoreBreakdown (MODIFY)

**Purpose**: 既存構造体を顔ベースの3項目に変更

**Location**: `Flowease/Models/ScoreBreakdown.swift`

**Changes**:
```swift
/// 姿勢スコアの内訳
struct ScoreBreakdown: Sendable, Equatable, Codable {
    /// 垂直位置変化スコア（うつむき検出）- 重み40%
    let verticalPosition: Int

    /// サイズ変化スコア（前傾検出）- 重み40%
    let sizeChange: Int

    /// 傾きスコア（首の傾き検出）- 重み20%
    let tilt: Int

    // 旧プロパティは削除:
    // - headTilt, shoulderBalance, forwardLean, symmetry
}
```

---

## Relationships Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        Runtime Flow                              │
│                                                                  │
│  CMSampleBuffer                                                  │
│       │                                                          │
│       ▼                                                          │
│  ┌─────────────────┐      ┌─────────────────┐                   │
│  │ VNFaceObservation│ ──▶ │  FacePosition   │                   │
│  └─────────────────┘      └─────────────────┘                   │
│                                   │                              │
│                    ┌──────────────┴──────────────┐              │
│                    │                             │               │
│                    ▼                             ▼               │
│         ┌───────────────────┐        ┌──────────────────┐       │
│         │ FaceScoreCalculator│        │CalibrationService│       │
│         └───────────────────┘        └──────────────────┘       │
│                    │                             │               │
│                    ▼                             ▼               │
│         ┌───────────────────┐        ┌──────────────────────┐   │
│         │   PostureScore    │        │ FaceReferencePosture │   │
│         │  (ScoreBreakdown) │        │ (FaceBaselineMetrics)│   │
│         └───────────────────┘        └──────────────────────┘   │
│                                               │                  │
│                                               ▼                  │
│                                      ┌──────────────────┐       │
│                                      │  UserDefaults    │       │
│                                      │ (CalibrationStorage)│    │
│                                      └──────────────────┘       │
└─────────────────────────────────────────────────────────────────┘
```

## Storage Schema

### UserDefaults Keys (既存キーを継続使用)

| Key | Type | Description |
|-----|------|-------------|
| `calibrationData` | Data (JSON) | FaceReferencePosture encoded |

### Data Format Detection

```swift
// CalibrationStorage内での形式判定ロジック
func load() -> FaceReferencePosture? {
    guard let data = userDefaults.data(forKey: key) else { return nil }

    // 顔ベース形式でデコード試行
    if let facePosture = try? decoder.decode(FaceReferencePosture.self, from: data) {
        return facePosture
    }

    // デコード失敗 = 旧形式または破損データ → クリア
    userDefaults.removeObject(forKey: key)
    return nil
}
```

## Migration Notes

### Breaking Changes

1. **ReferencePosture.swift → 削除**
   - FaceReferencePosture.swift で置き換え
   - 既存のキャリブレーションデータは自動クリア
   - ユーザーは再キャリブレーションが必要

2. **BaselineMetrics.swift → 削除**
   - FaceBaselineMetrics.swift で置き換え
   - 4項目評価 → 3項目評価
   - プロパティ名・意味が完全に変更

3. **ScoreBreakdown**
   - headTilt, shoulderBalance, forwardLean, symmetry → verticalPosition, sizeChange, tilt
   - UIでの表示が変更（メニューには影響なし）

4. **関連ファイルの削除候補**
   - ReferenceJointPosition.swift（ReferencePosture専用のため不要）
   - BodyPose.swift, JointPosition.swift（顔検出移行後は未使用、テスト依存確認後に削除）

### Backward Compatibility

- UserDefaultsキーは変更なし（`calibrationData`）
- 新旧形式はデコード成否で判別（構造が異なるため自然に失敗）
- 旧形式データは読み込み時に自動クリア（FR-009）
