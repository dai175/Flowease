# Quickstart: 顔検出ベースの姿勢検知

**Feature**: 003-face-detection
**Date**: 2026-01-02

## Prerequisites

- macOS 14.6+
- Xcode 16.0+ (Swift 6.0)
- カメラアクセス権限

## Implementation Overview

### 1. 新規ファイル作成順序

```
1. Models/FacePosition.swift           # 顔検出結果データ
2. Models/FaceBaselineMetrics.swift    # 顔ベース基準値
3. Models/FaceReferencePosture.swift   # 顔ベースキャリブレーションデータ
4. Services/FaceDetector.swift         # 顔検出サービス
5. Services/FaceScoreCalculator.swift  # 顔ベーススコア計算
```

### 2. 既存ファイル変更順序

```
1. Models/PauseReason.swift            # メッセージ変更
2. Models/ScoreBreakdown.swift         # 3項目評価に変更
3. Services/CalibrationStorage.swift   # データ形式判定追加
4. Services/CalibrationService.swift   # 顔ベースキャリブレーション
5. Services/PostureAnalyzer.swift      # 顔検出に切り替え
6. ViewModels/PostureViewModel.swift   # 顔検出結果処理
```

## Key Implementation Patterns

### Pattern 1: 顔検出リクエスト実行

```swift
import Vision

/// 顔検出サービス（バックグラウンドスレッドで実行）
final class FaceDetector: Sendable {
    private let logger = Logger(subsystem: "cc.focuswave.Flowease", category: "FaceDetector")

    /// CMSampleBufferから顔を検出
    /// - Note: バックグラウンドスレッドで実行される
    func detect(from sampleBuffer: CMSampleBuffer) async -> FacePosition? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let result = self.performDetection(sampleBuffer: sampleBuffer)
                continuation.resume(returning: result)
            }
        }
    }

    private func performDetection(sampleBuffer: CMSampleBuffer) -> FacePosition? {
        let faceRectRequest = VNDetectFaceRectanglesRequest()
        let captureQualityRequest = VNDetectFaceCaptureQualityRequest()

        let handler = VNImageRequestHandler(
            cmSampleBuffer: sampleBuffer,
            orientation: .up,
            options: [:]
        )

        do {
            // 複数リクエストを同時実行
            try handler.perform([faceRectRequest, captureQualityRequest])

            // 1. faceRectRequestから最大面積の顔を選択
            guard let rectResults = faceRectRequest.results,
                  let largestFace = selectLargestFace(from: rectResults) else {
                return nil
            }

            // 2. captureQualityRequestから対応する顔の品質を取得
            let quality = findMatchingQuality(
                for: largestFace,
                in: captureQualityRequest.results ?? []
            )

            return createFacePosition(from: largestFace, quality: quality)
        } catch {
            logger.error("顔検出エラー: \(error.localizedDescription)")
            return nil
        }
    }

    private func selectLargestFace(from observations: [VNFaceObservation]) -> VNFaceObservation? {
        observations.max { $0.boundingBox.area < $1.boundingBox.area }
    }

    /// boundingBoxの重なりで対応する顔の品質を取得
    private func findMatchingQuality(
        for face: VNFaceObservation,
        in qualityResults: [VNFaceObservation]
    ) -> Double {
        // boundingBoxが最も近い結果を探す（同一フレームなのでほぼ一致するはず）
        let matching = qualityResults.min { lhs, rhs in
            distance(face.boundingBox, lhs.boundingBox) < distance(face.boundingBox, rhs.boundingBox)
        }
        return matching?.faceCaptureQuality.map { Double($0) } ?? 0.0
    }

    private func distance(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let dx = a.midX - b.midX
        let dy = a.midY - b.midY
        return sqrt(dx * dx + dy * dy)
    }

    private func createFacePosition(from observation: VNFaceObservation, quality: Double) -> FacePosition {
        let box = observation.boundingBox
        return FacePosition(
            centerX: Double(box.midX),
            centerY: Double(box.midY),
            area: Double(box.width * box.height),
            roll: observation.roll?.doubleValue,
            captureQuality: quality,
            timestamp: Date()
        )
    }
}

extension CGRect {
    var area: CGFloat { width * height }
}
```

### Pattern 2: 顔ベーススコア計算

```swift
@MainActor
final class FaceScoreCalculator {
    private let verticalPositionWeight: Double = 0.40
    private let sizeChangeWeight: Double = 0.40
    private let tiltWeight: Double = 0.20

    // しきい値と最大逸脱
    private let verticalThreshold: Double = 0.02
    private let verticalMaxDeviation: Double = 0.15
    private let sizeThreshold: Double = 0.05
    private let sizeMaxDeviation: Double = 0.30
    private let tiltThreshold: Double = 0.05  // ~3°
    private let tiltMaxDeviation: Double = 0.35  // ~20°

    func calculate(
        from face: FacePosition,
        baseline: FaceBaselineMetrics
    ) -> PostureScore {
        // 1. 垂直位置変化（片方向：Y低下のみ）
        let yDeviation = max(0, baseline.baselineY - face.centerY)
        let verticalScore = calculateScore(
            deviation: yDeviation,
            threshold: verticalThreshold,
            maxDeviation: verticalMaxDeviation
        )

        // 2. サイズ変化（片方向：増加のみ）
        let sizeRatio = (face.area - baseline.baselineArea) / baseline.baselineArea
        let sizeDeviation = max(0, sizeRatio)
        let sizeScore = calculateScore(
            deviation: sizeDeviation,
            threshold: sizeThreshold,
            maxDeviation: sizeMaxDeviation
        )

        // 3. 傾き（両方向、ラップアラウンド考慮）
        let tiltScore: Int
        if let roll = face.roll {
            let diff = roll - baseline.baselineRoll
            let absDiff = abs(diff)
            let tiltDeviation = min(absDiff, 2 * .pi - absDiff)
            tiltScore = calculateScore(
                deviation: tiltDeviation,
                threshold: tiltThreshold,
                maxDeviation: tiltMaxDeviation
            )
        } else {
            tiltScore = 70  // roll未取得時のデフォルト
        }

        // 重み付き平均
        let totalScore = Int((
            Double(verticalScore) * verticalPositionWeight +
            Double(sizeScore) * sizeChangeWeight +
            Double(tiltScore) * tiltWeight
        ).rounded())

        return PostureScore(
            value: totalScore,
            timestamp: face.timestamp,
            breakdown: ScoreBreakdown(
                verticalPosition: verticalScore,
                sizeChange: sizeScore,
                tilt: tiltScore
            ),
            confidence: face.captureQuality
        )
    }

    private func calculateScore(
        deviation: Double,
        threshold: Double,
        maxDeviation: Double
    ) -> Int {
        if deviation <= threshold { return 100 }
        if deviation >= maxDeviation { return 0 }

        let range = maxDeviation - threshold
        let excess = deviation - threshold
        let ratio = excess / range
        return Int((100.0 * (1.0 - ratio)).rounded())
    }
}
```

### Pattern 3: データ形式判定

```swift
final class CalibrationStorage {
    func load() -> FaceReferencePosture? {
        guard let data = userDefaults.data(forKey: key) else {
            return nil
        }

        // 顔ベース形式でデコード試行
        if let facePosture = try? decoder.decode(FaceReferencePosture.self, from: data) {
            logger.info("顔ベースキャリブレーションデータを読み込み")
            return facePosture
        }

        // デコード失敗 = 旧形式または破損データ → クリア
        logger.info("キャリブレーションデータをクリア（形式不一致）")
        clear()
        return nil
    }
}
```

## Testing Checklist

- [ ] FacePosition の生成・バリデーション
- [ ] FaceBaselineMetrics のNaN/Infiniteサニタイズ
- [ ] FaceReferencePosture のエンコード/デコード
- [ ] FaceScoreCalculator の各評価項目計算
- [ ] roll角のラップアラウンド計算
- [ ] CalibrationStorage の旧形式自動クリア
- [ ] 顔未検出時の一時停止遷移
- [ ] 検出品質低下時の一時停止遷移

## Common Pitfalls

1. **Vision座標系の注意**: Y=0が下端、Y=1が上端
2. **roll角の範囲**: [-π, π) でラップアラウンドあり
3. **faceCaptureQuality**: VNDetectFaceCaptureQualityRequest実行が必要
4. **複数顔検出**: 最大面積の顔を選択
5. **CMSampleBuffer処理**: バックグラウンドキューで実行
