# Research: 顔検出ベースの姿勢検知

**Feature**: 003-face-detection
**Date**: 2026-01-02
**Status**: Complete

## 1. Vision Framework 顔検出API選定

### Decision: VNDetectFaceRectanglesRequest を使用

**Rationale**:
- バウンディングボックスとroll/yaw/pitch角度を直接提供
- VNDetectFaceLandmarksRequestより軽量（詳細ランドマーク不要のため）
- macOS 14.6+で必要なすべてのプロパティが利用可能

**Alternatives Considered**:
| API | Pros | Cons |
|-----|------|------|
| VNDetectFaceRectanglesRequest | 軽量、必要な情報を直接提供 | - |
| VNDetectFaceLandmarksRequest | より詳細な顔パーツ情報 | 重い、不要な情報が多い |

## 2. VNFaceObservation プロパティ可用性

### Decision: 以下のプロパティを使用

| プロパティ | 型 | macOS版 | 使用 | 備考 |
|---|---|---|---|---|
| boundingBox | CGRect | 10.13+ | ✅ | 顔位置・サイズ（正規化座標0-1） |
| roll | NSNumber? | 10.14+ | ✅ | 首の傾き（ラジアン） |
| yaw | NSNumber? | 10.14+ | ❌ | アプリ側で判定しない（検出器が横向きで自然に失敗） |
| pitch | NSNumber? | 12.0+ | ❌ | 使用しない（Y座標変化で代替） |
| faceCaptureQuality | CGFloat? | 11.0+ | ✅ | 検出品質（0-1） |

**Rationale**:
- macOS 14.6+ターゲットですべて利用可能
- yaw角: アプリ側で閾値判定は行わない。極端な横向きは検出器が自然に検出失敗するため
- pitch角: 安定性に欠けるため、Y座標変化で代替（仕様書記載済み）

## 3. 複数Visionリクエスト実行方式

### Decision: 単一VNImageRequestHandlerでバンドル実行

**Rationale**:
- 複数ハンドラー作成のオーバーヘッドを回避
- Vision Frameworkが内部で並行実行を最適化

**Implementation Pattern**:
```swift
let handler = VNImageRequestHandler(cmSampleBuffer: sampleBuffer,
                                     orientation: .up,
                                     options: [:])
try handler.perform([faceRectRequest, captureQualityRequest])
```

**Alternatives Considered**:
| 方式 | Pros | Cons |
|-----|------|------|
| 単一ハンドラーバンドル実行 | 効率的、推奨パターン | - |
| 個別ハンドラー | シンプル | 非効率、オーバーヘッド大 |

## 4. 30FPSリアルタイム処理最適化

### Decision: フレームスキップ + バックグラウンド実行

**Rationale**:
- 既存CameraServiceで実証済みのパターン（2フレームに1回処理）
- メインスレッド保護でUI応答性維持
- 15FPSでの処理でも2秒以内のスコア反映は十分達成可能

**Implementation Pattern**:
```swift
// 既存パターンを継続
private let frameProcessingInterval = 2  // 2フレームに1回処理

DispatchQueue.global(qos: .userInitiated).async {
    // Vision処理
    Task { @MainActor in
        // UI更新
    }
}
```

## 5. Swift 6 Concurrency対応

### Decision: @preconcurrency修飾子でAVFoundationをインポート

**Rationale**:
- 既存コードベースで採用済みのパターン
- Swift 6のSendable要件を満たす

**Implementation Pattern**:
```swift
@preconcurrency import AVFoundation
```

## 6. 既存コードとの統合方針

### Decision: 既存PostureAnalyzerを顔検出に置き換え

**Rationale**:
- 既存アーキテクチャを維持
- ScoreCalculator/CalibrationServiceは内部ロジックのみ変更
- Viewレイヤーは変更不要

**Integration Points**:

| コンポーネント | 変更内容 |
|---------------|---------|
| PostureAnalyzer | VNDetectHumanBodyPoseRequest → VNDetectFaceRectanglesRequest |
| ScoreCalculator | 4項目評価 → 3項目評価（顔ベース）、FaceScoreCalculatorとして新規作成 |
| CalibrationService | BodyPose → FacePosition |
| CalibrationStorage | FaceReferencePosture対応、旧形式自動クリア |
| ReferencePosture | **削除**（FaceReferencePostureで置き換え） |
| BaselineMetrics | **削除**（FaceBaselineMetricsで置き換え） |
| PauseReason | メッセージ変更（人物→顔） |

## 7. データ形式移行

### Decision: 旧形式データは自動クリア

**Rationale**:
- 仕様書で決定済み（FR-009）
- 移行UX不要でシンプル
- UserDefaultsキーは既存を継続使用

**Implementation Pattern**:
```swift
// CalibrationStorage.load()内で判定
func load() -> FaceReferencePosture? {
    guard let data = userDefaults.data(forKey: key) else { return nil }

    // 顔ベース形式でデコード試行
    if let facePosture = try? decoder.decode(FaceReferencePosture.self, from: data) {
        return facePosture
    }

    // デコード失敗 = 旧形式または破損データ → クリア
    clear()
    return nil
}
```

## 8. VNDetectFaceCaptureQualityRequest 利用方式

### Decision: VNDetectFaceRectanglesRequestと同時実行

**Rationale**:
- 単独実行でも顔検出を内部で行うが、同時実行が効率的
- faceCaptureQualityはVNFaceObservationに追加される

**Implementation Notes**:
- faceCaptureQuality < 0.3 で検出精度低下と判定（仕様書記載済み）
- 複数顔検出時は最大面積の顔のfaceCaptureQualityを使用

## References

- [Apple Vision Framework Documentation](https://developer.apple.com/documentation/vision)
- [VNDetectFaceRectanglesRequest](https://developer.apple.com/documentation/vision/vndetectfacerectanglesrequest)
- [VNDetectFaceCaptureQualityRequest](https://developer.apple.com/documentation/vision/vndetectfacecapturequalityrequest)
- [VNFaceObservation](https://developer.apple.com/documentation/vision/vnfaceobservation)
- 既存実装: Flowease/Services/PostureAnalyzer.swift, CameraService.swift
