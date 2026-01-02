// CalibrationService.swift
// Flowease
//
// キャリブレーションの実行と管理
//
// T013: CalibrationServiceProtocolとCalibrationServiceを作成
// T014: CalibrationErrorを作成

import Foundation
import Observation
import OSLog

// MARK: - CalibrationError

/// キャリブレーション処理で発生するエラー
enum CalibrationError: Error, Equatable, Sendable {
    /// 既にキャリブレーション実行中
    case alreadyInProgress

    /// 人物が検出されなかった
    case noPersonDetected

    /// 信頼度が低い状態が続いた
    case lowConfidence

    /// 十分なフレームが収集できなかった
    case insufficientFrames
}

// MARK: - CalibrationServiceProtocol

/// キャリブレーションサービスのプロトコル
///
/// キャリブレーションの開始・キャンセル・リセット・フレーム処理を定義する。
/// テスト時にはモック実装に差し替え可能。
@MainActor
protocol CalibrationServiceProtocol: AnyObject {
    /// 現在のキャリブレーション状態
    var state: CalibrationState { get }

    /// 現在の基準姿勢（完了時のみ有効）
    var referencePosture: ReferencePosture? { get }

    /// キャリブレーションを開始
    /// - Throws: CalibrationError.alreadyInProgress（既に実行中の場合）
    func startCalibration() async throws

    /// キャリブレーションをキャンセル
    /// 実行中でない場合は何もしない
    func cancelCalibration()

    /// キャリブレーションをリセット（基準姿勢を削除）
    func resetCalibration()

    /// フレームを処理してキャリブレーションデータを収集
    /// - Parameter pose: 検出された姿勢データ
    func processFrame(_ pose: BodyPose)
}

// MARK: - CalibrationService

/// キャリブレーションサービスの実装
///
/// ユーザーの「良い姿勢」を基準として記録し、永続化する。
/// 3秒間（約90フレーム）の複数フレームを平均化して基準姿勢を生成。
@MainActor
@Observable
final class CalibrationService: CalibrationServiceProtocol {
    // MARK: - Properties

    /// 現在のキャリブレーション状態
    private(set) var state: CalibrationState

    /// 永続化ストレージ
    private let storage: CalibrationStorageProtocol

    /// ロガー
    private let logger = Logger(subsystem: "cc.focuswave.Flowease", category: "CalibrationService")

    /// 信頼度閾値（BodyPose.minimumConfidenceと同じ0.5を使用）
    private let confidenceThreshold: Double = 0.5

    // MARK: - Calibration Data Collection

    /// 収集中のフレームデータ（位置の累積値）
    private var accumulatedPositions: AccumulatedPositions?

    /// 収集中の進捗情報
    private var currentProgress: CalibrationProgress?

    /// 最初のフレームを受け取ったかどうか
    private var hasReceivedFirstFrame = false

    // MARK: - Computed Properties

    /// 現在の基準姿勢
    var referencePosture: ReferencePosture? {
        storage.loadReferencePosture()
    }

    // MARK: - Initializer

    /// イニシャライザ
    /// - Parameter storage: 永続化ストレージ
    init(storage: CalibrationStorageProtocol) {
        self.storage = storage

        // 初期状態はストレージの内容から導出
        if storage.loadReferencePosture() != nil {
            state = .completed
        } else {
            state = .notCalibrated
        }

        logger.debug("CalibrationService 初期化完了: state=\(self.state.statusDescription)")
    }

    // MARK: - CalibrationServiceProtocol

    func startCalibration() async throws {
        // 既に実行中の場合はエラー
        if state.isInProgress {
            logger.warning("キャリブレーション開始失敗: 既に実行中")
            throw CalibrationError.alreadyInProgress
        }

        // 進捗情報を初期化（タイマーは最初のフレーム受信時に開始）
        accumulatedPositions = AccumulatedPositions()
        hasReceivedFirstFrame = false
        currentProgress = nil // 最初のフレーム受信時に作成

        // 状態を更新（ダミーの進捗で開始）
        state = .inProgress(CalibrationProgress())
        logger.info("キャリブレーション開始（フレーム待機中）")
    }

    func cancelCalibration() {
        // 実行中でなければ何もしない
        guard state.isInProgress else {
            return
        }

        // キャンセル状態に移行
        state = .failed(.cancelled)
        currentProgress = nil
        accumulatedPositions = nil
        hasReceivedFirstFrame = false
        logger.info("キャリブレーションをキャンセルしました")
    }

    func resetCalibration() {
        // 実行中ならキャンセル
        if state.isInProgress {
            currentProgress = nil
            accumulatedPositions = nil
            hasReceivedFirstFrame = false
        }

        // ストレージから削除
        storage.deleteReferencePosture()

        // 状態を未キャリブレーションに
        state = .notCalibrated
        logger.info("キャリブレーションをリセットしました")
    }

    func processFrame(_ pose: BodyPose) {
        // 実行中でなければ無視
        guard state.isInProgress,
              var accumulated = accumulatedPositions
        else {
            return
        }

        // 最初のフレーム受信時にタイマーを開始
        if !hasReceivedFirstFrame {
            hasReceivedFirstFrame = true
            currentProgress = CalibrationProgress()
            logger.debug("キャリブレーション: フレーム収集開始")
        }

        guard var progress = currentProgress else {
            return
        }

        // フレームの品質をチェック
        let frameQuality = evaluateFrameQuality(pose)

        // 進捗を更新
        progress.addFrame(quality: frameQuality)

        // 高信頼度フレームなら位置データを累積
        if frameQuality == .highConfidence {
            accumulated.add(pose)
        }

        // 失敗判定（人物未検出を優先）
        if progress.shouldFailNoPersonDetected {
            state = .failed(.noPersonDetected)
            currentProgress = nil
            accumulatedPositions = nil
            logger.warning("キャリブレーション失敗: 人物未検出が連続")
            return
        }

        if progress.shouldFailLowConfidence {
            state = .failed(.lowConfidence)
            currentProgress = nil
            accumulatedPositions = nil
            logger.warning("キャリブレーション失敗: 低信頼度が連続")
            return
        }

        // 完了判定
        if progress.isComplete {
            completeCalibration(accumulated: accumulated, progress: progress)
            return
        }

        // 状態を更新
        currentProgress = progress
        accumulatedPositions = accumulated
        state = .inProgress(progress)
    }

    // MARK: - Private Methods

    /// フレームの品質を評価
    /// - Parameter pose: 評価する姿勢データ
    /// - Returns: フレームの品質レベル
    private func evaluateFrameQuality(_ pose: BodyPose) -> CalibrationProgress.FrameQuality {
        // 必須関節が検出されているか
        guard let neck = pose.neck,
              let leftShoulder = pose.leftShoulder,
              let rightShoulder = pose.rightShoulder
        else {
            return .noPersonDetected
        }

        // 必須関節の信頼度が閾値以上か
        let requiredConfidences = [neck.confidence, leftShoulder.confidence, rightShoulder.confidence]
        if requiredConfidences.allSatisfy({ $0 >= confidenceThreshold }) {
            return .highConfidence
        } else {
            return .lowConfidence
        }
    }

    /// フレームが高信頼度かどうかを判定（後方互換性のため）
    private func isFrameHighConfidence(_ pose: BodyPose) -> Bool {
        evaluateFrameQuality(pose) == .highConfidence
    }

    /// キャリブレーションを完了
    private func completeCalibration(accumulated: AccumulatedPositions, progress: CalibrationProgress) {
        // フレーム数が不足していれば失敗
        guard accumulated.frameCount >= ReferencePosture.minimumFrameCount else {
            state = .failed(.insufficientFrames)
            currentProgress = nil
            accumulatedPositions = nil
            logger.warning("キャリブレーション失敗: フレーム数不足 (\(accumulated.frameCount) < \(ReferencePosture.minimumFrameCount))")
            return
        }

        // 平均位置を計算
        let referencePosture = accumulated.createReferencePosture()

        // 信頼度チェック
        guard referencePosture.isValid else {
            state = .failed(.lowConfidence)
            currentProgress = nil
            accumulatedPositions = nil
            logger.warning("キャリブレーション失敗: 平均信頼度が不足")
            return
        }

        // ストレージに保存
        storage.saveReferencePosture(referencePosture)

        // 状態を完了に
        state = .completed
        currentProgress = nil
        accumulatedPositions = nil

        logger.info("""
        キャリブレーション完了: frameCount=\(referencePosture.frameCount), \
        avgConfidence=\(String(format: "%.2f", referencePosture.averageConfidence))
        """)
    }
}
