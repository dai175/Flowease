// PostureAnalyzer.swift
// Flowease
//
// Vision フレームワークを使用した姿勢分析を担当するサービス

import CoreVideo
import OSLog
import Vision

// MARK: - PostureAnalyzing

/// 姿勢分析プロトコル
///
/// テスト可能性のために PostureAnalyzer の抽象化を提供する。
/// 実装は Vision フレームワークを使用するが、テストではモック化可能。
protocol PostureAnalyzing: Sendable {
    /// ピクセルバッファから姿勢を分析
    /// - Parameter pixelBuffer: カメラからのフレームデータ
    /// - Returns: 検出された姿勢、または人物が検出されない場合は nil
    func analyze(pixelBuffer: CVPixelBuffer) async -> BodyPose?
}

// MARK: - PostureAnalyzer

/// Vision フレームワークを使用した姿勢分析の実装
///
/// カメラからのフレームを受け取り、VNDetectHumanBodyPoseRequest を使用して
/// 上半身の姿勢を検出する。検出結果は BodyPose モデルに変換して返す。
@MainActor
final class PostureAnalyzer: PostureAnalyzing, @unchecked Sendable {
    // MARK: - Properties

    private let logger = Logger(subsystem: "cc.focuswave.Flowease", category: "PostureAnalyzer")

    // MARK: - Initialization

    init() {
        logger.debug("PostureAnalyzer 初期化完了")
    }

    // MARK: - PostureAnalyzing

    /// ピクセルバッファから姿勢を分析
    /// - Parameter pixelBuffer: カメラからのフレームデータ
    /// - Returns: 検出された姿勢、または人物が検出されない場合は nil
    func analyze(pixelBuffer: CVPixelBuffer) async -> BodyPose? {
        // VNDetectHumanBodyPoseRequest を作成
        let request = VNDetectHumanBodyPoseRequest()

        // VNImageRequestHandler で実行
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])

        do {
            try handler.perform([request])
        } catch {
            logger.error("姿勢検出リクエストの実行に失敗: \(error.localizedDescription)")
            return nil
        }

        // 結果を取得（最初の検出結果のみ使用）
        guard let observation = request.results?.first else {
            logger.debug("人物が検出されませんでした")
            return nil
        }

        // VNHumanBodyPoseObservation を BodyPose に変換
        let bodyPose = convertToBodyPose(from: observation)

        if bodyPose.isValid {
            logger.debug("姿勢を検出しました")
        } else {
            logger.debug("検出された姿勢が無効です（必須関節が不足または低信頼度）")
        }

        return bodyPose
    }

    // MARK: - Private Methods

    /// VNHumanBodyPoseObservation を BodyPose に変換
    /// - Parameter observation: Vision フレームワークの姿勢検出結果
    /// - Returns: 変換された BodyPose
    private func convertToBodyPose(from observation: VNHumanBodyPoseObservation) -> BodyPose {
        BodyPose(
            nose: extractJoint(from: observation, jointName: .nose),
            neck: extractJoint(from: observation, jointName: .neck),
            leftShoulder: extractJoint(from: observation, jointName: .leftShoulder),
            rightShoulder: extractJoint(from: observation, jointName: .rightShoulder),
            leftEar: extractJoint(from: observation, jointName: .leftEar),
            rightEar: extractJoint(from: observation, jointName: .rightEar),
            root: extractJoint(from: observation, jointName: .root),
            timestamp: Date()
        )
    }

    /// 指定した関節の位置を抽出
    /// - Parameters:
    ///   - observation: Vision フレームワークの姿勢検出結果
    ///   - jointName: 抽出する関節の名前
    /// - Returns: 関節位置、または検出されなかった場合は nil
    private func extractJoint(
        from observation: VNHumanBodyPoseObservation,
        jointName: VNHumanBodyPoseObservation.JointName
    ) -> JointPosition? {
        do {
            let point = try observation.recognizedPoint(jointName)

            // 信頼度が極めて低い場合は検出失敗として扱う
            guard point.confidence > 0.1 else {
                return nil
            }

            return JointPosition(
                x: point.location.x,
                y: point.location.y,
                confidence: Double(point.confidence)
            )
        } catch {
            // 関節が検出されなかった場合
            return nil
        }
    }
}
