// PostureAnalyzer.swift
// Flowease
//
// Vision フレームワークを使用した姿勢分析を担当するサービス

@preconcurrency import AVFoundation
import OSLog

// MARK: - AnalysisResult

/// 姿勢分析の結果
///
/// PostureAnalyzer の分析結果を表す列挙型。
/// 成功時は FacePosition を、失敗時は原因を区別して返す。
enum AnalysisResult: Sendable, Equatable {
    /// 顔が正常に検出された
    case success(FacePosition)

    /// 顔が検出されなかった
    ///
    /// カメラに顔が映っていない場合。
    case noFaceDetected

    /// 検出精度が低下している
    ///
    /// 顔は検出されるが、検出品質が低い場合。
    /// 照明条件、角度、距離など様々な原因が考えられる。
    case lowDetectionQuality

    /// Vision フレームワークエラー
    ///
    /// 顔検出処理自体が失敗した場合。
    /// エラーの詳細は FaceDetector のログに記録される。
    case visionError
}

// MARK: - PostureAnalyzing

/// 姿勢分析プロトコル
///
/// テスト可能性のために PostureAnalyzer の抽象化を提供する。
/// 実装は Vision フレームワークを使用するが、テストではモック化可能。
protocol PostureAnalyzing: Sendable {
    /// CMSampleBufferから顔を検出して分析
    /// - Parameter sampleBuffer: カメラからのフレームデータ
    /// - Returns: 分析結果（成功時は FacePosition、失敗時は原因を含む）
    func analyze(sampleBuffer: sending CMSampleBuffer) async -> AnalysisResult
}

// MARK: - PostureAnalyzer

/// Vision フレームワークを使用した姿勢分析の実装
///
/// カメラからのフレームを受け取り、FaceDetector を使用して
/// 顔の位置・サイズ・傾きを検出する。検出結果は FacePosition モデルに変換して返す。
@MainActor
final class PostureAnalyzer: PostureAnalyzing {
    // MARK: - Properties

    private let logger = Logger(subsystem: "cc.focuswave.Flowease", category: "PostureAnalyzer")

    /// 顔検出サービス
    private let faceDetector: FaceDetectorProtocol

    // MARK: - Initialization

    /// イニシャライザ
    /// - Parameter faceDetector: 顔検出サービス（依存注入によりテスト可能）
    init(faceDetector: FaceDetectorProtocol = FaceDetector()) {
        self.faceDetector = faceDetector
        logger.debug("PostureAnalyzer initialized (FaceDetector mode)")
    }

    // MARK: - PostureAnalyzing

    /// CMSampleBufferから顔を検出して分析
    /// - Parameter sampleBuffer: カメラからのフレームデータ
    /// - Returns: 分析結果（成功時は FacePosition、失敗時は原因を含む）
    nonisolated func analyze(sampleBuffer: sending CMSampleBuffer) async -> AnalysisResult {
        // FaceDetectorで顔を検出
        let detectionResult = await faceDetector.detect(from: sampleBuffer)

        switch detectionResult {
        case let .success(facePosition):
            // 検出品質のチェック
            guard facePosition.hasAcceptableQuality else {
                return .lowDetectionQuality
            }

            // バリデーションのチェック
            guard facePosition.isValid else {
                return .lowDetectionQuality
            }

            return .success(facePosition)

        case let .failure(error):
            switch error {
            case .noFaceDetected:
                return .noFaceDetected
            case .visionRequestFailed:
                return .visionError
            }
        }
    }
}
