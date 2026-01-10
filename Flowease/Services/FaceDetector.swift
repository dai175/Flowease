// FaceDetector.swift
// Flowease
//
// 顔検出サービス（Vision Framework使用）

@preconcurrency import AVFoundation
import CoreGraphics
import Foundation
import OSLog
@preconcurrency import Vision

// MARK: - FaceDetectionError

/// 顔検出エラー
///
/// Vision Framework で発生する可能性のあるエラーを分類する。
enum FaceDetectionError: Error, Sendable, Equatable {
    /// 顔が検出されなかった
    case noFaceDetected

    /// Vision Framework のリクエスト実行エラー
    ///
    /// - Parameter description: エラーの詳細説明
    case visionRequestFailed(String)
}

// MARK: - FaceDetectorProtocol

/// 顔検出プロトコル
///
/// テスト可能性のために FaceDetector の抽象化を提供する。
/// 実装は Vision フレームワークを使用するが、テストではモック化可能。
protocol FaceDetectorProtocol: Sendable {
    /// CMSampleBufferから顔を検出
    /// - Parameter sampleBuffer: カメラからのフレームデータ
    /// - Returns: 検出結果（成功時は FacePosition、失敗時はエラー）
    func detect(from sampleBuffer: sending CMSampleBuffer) async -> Result<FacePosition, FaceDetectionError>
}

// MARK: - FaceDetector

/// Vision フレームワークを使用した顔検出の実装
///
/// カメラからのフレームを受け取り、VNDetectFaceRectanglesRequest と
/// VNDetectFaceCaptureQualityRequest を使用して顔を検出する。
/// 複数の顔が検出された場合は最大面積の顔を選択する。
final class FaceDetector: FaceDetectorProtocol, Sendable {
    // MARK: - Properties

    private let logger = Logger(subsystem: "cc.focuswave.Flowease", category: "FaceDetector")

    // MARK: - Initialization

    nonisolated init() {
        logger.debug("FaceDetector initialized")
    }

    // MARK: - FaceDetectorProtocol

    /// CMSampleBufferから顔を検出
    ///
    /// VNDetectFaceRectanglesRequestとVNDetectFaceCaptureQualityRequestを
    /// 同時実行し、顔の位置・サイズ・傾き・検出品質を取得する。
    /// 複数の顔が検出された場合は最大面積の顔を選択する（FR-007）。
    ///
    /// - Parameter sampleBuffer: カメラからのフレームデータ
    /// - Returns: 検出結果（成功時は FacePosition、失敗時はエラー）
    nonisolated func detect(from sampleBuffer: sending CMSampleBuffer) async
        -> Result<FacePosition, FaceDetectionError> {
        // Vision処理はCPU負荷が高いためバックグラウンドスレッドで実行
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                let result = performDetection(sampleBuffer: sampleBuffer)
                continuation.resume(returning: result)
            }
        }
    }

    // MARK: - Private Methods

    /// 顔検出を実行
    ///
    /// 単一のVNImageRequestHandlerでfaceRectRequestとcaptureQualityRequestを
    /// バンドル実行し、効率的に顔検出と品質評価を行う（research.md参照）。
    private nonisolated func performDetection(sampleBuffer: CMSampleBuffer)
        -> Result<FacePosition, FaceDetectionError> {
        let faceRectRequest = VNDetectFaceRectanglesRequest()
        let captureQualityRequest = VNDetectFaceCaptureQualityRequest()

        // 単一ハンドラーでバンドル実行（research.md: Vision Frameworkが内部で並行実行を最適化）
        let handler = VNImageRequestHandler(
            cmSampleBuffer: sampleBuffer,
            orientation: .up,
            options: [:]
        )

        do {
            try handler.perform([faceRectRequest, captureQualityRequest])

            guard let rectResults = faceRectRequest.results else {
                logger.debug("No face detection result: results is nil")
                return .failure(.noFaceDetected)
            }

            // 複数顔から最大面積を選択（FR-007）
            guard let largestFace = selectLargestFace(from: rectResults) else {
                logger.debug("No face detection result: 0 faces detected")
                return .failure(.noFaceDetected)
            }

            // 最大面積の顔に対応する品質値を取得
            let quality = findMatchingQuality(
                for: largestFace,
                in: captureQualityRequest.results ?? []
            )

            let position = createFacePosition(from: largestFace, quality: quality)

            logger.debug("""
            Face detected: center=(\(String(format: "%.3f", position.centerX)), \
            \(String(format: "%.3f", position.centerY))), \
            area=\(String(format: "%.4f", position.area)), \
            roll=\(position.roll.map { String(format: "%.3f", $0) } ?? "nil"), \
            quality=\(String(format: "%.2f", position.captureQuality))
            """)

            return .success(position)
        } catch {
            logger.error("Vision request failed: \(error.localizedDescription)")
            return .failure(.visionRequestFailed(error.localizedDescription))
        }
    }

    /// 最大面積の顔を選択（FR-007準拠）
    ///
    /// 複数の顔が検出された場合、boundingBoxの面積が最大の顔を対象とする。
    /// 画面中央のユーザーが通常最も大きく映るため、この戦略が適切。
    ///
    /// - Parameter observations: VNDetectFaceRectanglesRequestの結果
    /// - Returns: 最大面積の顔、検出なしの場合はnil
    nonisolated func selectLargestFace(from observations: [VNFaceObservation]) -> VNFaceObservation? {
        observations.max { $0.boundingBox.area < $1.boundingBox.area }
    }

    /// 対応する顔の検出品質を取得（FR-001準拠）
    ///
    /// VNDetectFaceCaptureQualityRequestの結果から、指定された顔に
    /// 最も近いboundingBoxを持つ観測の品質値を取得する。
    /// VNDetectFaceRectanglesRequestとVNDetectFaceCaptureQualityRequestは
    /// 独立して顔を検出するため、boundingBoxの距離で対応付けを行う。
    ///
    /// - Parameters:
    ///   - face: 品質を取得したい顔の観測
    ///   - qualityResults: VNDetectFaceCaptureQualityRequestの結果
    /// - Returns: 検出品質（0.0-1.0）、対応する顔が見つからない場合は0.0
    nonisolated func findMatchingQuality(
        for face: VNFaceObservation,
        in qualityResults: [VNFaceObservation]
    ) -> Double {
        // boundingBoxの中心点間の距離が最小のものをマッチングとする
        let matching = qualityResults.min { lhs, rhs in
            distance(face.boundingBox, lhs.boundingBox) < distance(face.boundingBox, rhs.boundingBox)
        }
        // faceCaptureQualityはOptional<NSNumber>のため、適切にアンラップ
        // 見つからない場合は0.0を返す（0.3未満 = 検出精度低下として扱われる）
        return matching?.faceCaptureQuality.map { Double($0) } ?? 0.0
    }

    /// 2つのCGRect間の距離を計算
    private nonisolated func distance(_ rectA: CGRect, _ rectB: CGRect) -> CGFloat {
        let dx = rectA.midX - rectB.midX
        let dy = rectA.midY - rectB.midY
        return sqrt(dx * dx + dy * dy)
    }

    /// VNFaceObservationからFacePositionを生成
    private nonisolated func createFacePosition(from observation: VNFaceObservation, quality: Double) -> FacePosition {
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

// MARK: - CGRect Extension

extension CGRect {
    /// 矩形の面積
    nonisolated var area: CGFloat { width * height }
}
