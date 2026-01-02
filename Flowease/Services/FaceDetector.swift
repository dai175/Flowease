// FaceDetector.swift
// Flowease
//
// 顔検出サービス（Vision Framework使用）
//
// T006: FaceDetectorサービススタブ作成（Phase 2 Foundational）

@preconcurrency import AVFoundation
import CoreGraphics
import Foundation
import OSLog
@preconcurrency import Vision

// MARK: - FaceDetectorProtocol

/// 顔検出プロトコル
///
/// テスト可能性のために FaceDetector の抽象化を提供する。
/// 実装は Vision フレームワークを使用するが、テストではモック化可能。
protocol FaceDetectorProtocol: Sendable {
    /// CMSampleBufferから顔を検出
    /// - Parameter sampleBuffer: カメラからのフレームデータ
    /// - Returns: 検出された顔の位置情報、検出失敗時は nil
    func detect(from sampleBuffer: CMSampleBuffer) async -> FacePosition?
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
        logger.debug("FaceDetector 初期化完了")
    }

    // MARK: - FaceDetectorProtocol

    /// CMSampleBufferから顔を検出
    /// - Parameter sampleBuffer: カメラからのフレームデータ
    /// - Returns: 検出された顔の位置情報、検出失敗時は nil
    ///
    /// NOTE: Phase 2スタブ実装。US1で詳細ロジックを実装予定。
    nonisolated func detect(from sampleBuffer: CMSampleBuffer) async -> FacePosition? {
        // Vision処理はCPU負荷が高いためバックグラウンドスレッドで実行
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                let result = performDetection(sampleBuffer: sampleBuffer)
                continuation.resume(returning: result)
            }
        }
    }

    // MARK: - Private Methods (スタブ)

    /// 顔検出を実行
    /// NOTE: US1で詳細実装
    private nonisolated func performDetection(sampleBuffer: CMSampleBuffer) -> FacePosition? {
        // NOTE: T012で実装予定 - VNDetectFaceRectanglesRequest
        // NOTE: T013で実装予定 - VNDetectFaceCaptureQualityRequest
        // NOTE: T014で実装予定 - selectLargestFace

        let faceRectRequest = VNDetectFaceRectanglesRequest()
        let captureQualityRequest = VNDetectFaceCaptureQualityRequest()

        let handler = VNImageRequestHandler(
            cmSampleBuffer: sampleBuffer,
            orientation: .up,
            options: [:]
        )

        do {
            try handler.perform([faceRectRequest, captureQualityRequest])

            guard let rectResults = faceRectRequest.results,
                  let largestFace = selectLargestFace(from: rectResults)
            else {
                return nil
            }

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

    /// 最大面積の顔を選択
    /// NOTE: T014で詳細実装
    nonisolated func selectLargestFace(from observations: [VNFaceObservation]) -> VNFaceObservation? {
        observations.max { $0.boundingBox.area < $1.boundingBox.area }
    }

    /// boundingBoxの重なりで対応する顔の品質を取得
    /// NOTE: T013で詳細実装
    nonisolated func findMatchingQuality(
        for face: VNFaceObservation,
        in qualityResults: [VNFaceObservation]
    ) -> Double {
        let matching = qualityResults.min { lhs, rhs in
            distance(face.boundingBox, lhs.boundingBox) < distance(face.boundingBox, rhs.boundingBox)
        }
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
