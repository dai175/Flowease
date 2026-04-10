// CalibrationService.swift
// Flowease
//
// キャリブレーションの実行と管理

import Foundation
import Observation
import OSLog

// MARK: - CalibrationError

/// キャリブレーション処理で発生するエラー
enum CalibrationError: Error, Equatable {
    /// 既にキャリブレーション実行中
    case alreadyInProgress

    /// 顔が検出されなかった
    case noFaceDetected

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

    /// キャリブレーションを開始
    /// - Throws: CalibrationError.alreadyInProgress（既に実行中の場合）
    func startCalibration() async throws

    /// キャリブレーションをキャンセル
    /// 実行中でない場合は何もしない
    func cancelCalibration()

    /// キャリブレーションをリセット（基準姿勢を削除）
    func resetCalibration()

    /// 顔フレームを処理してキャリブレーションデータを収集
    /// - Parameter face: 検出された顔位置データ
    func processFaceFrame(_ face: FacePosition)

    /// 顔未検出フレームを処理
    /// キャリブレーション中に顔が検出されなかった場合に呼び出す
    func processNoFaceFrame()

    /// 現在の顔ベース基準姿勢（完了時のみ有効）
    var faceReferencePosture: FaceReferencePosture? { get }

    /// UI状態を開始前状態にリセット（データは保持）
    /// キャリブレーションウィンドウを開く際に呼び出す
    func prepareForRecalibration()
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
    private let logger = Logger.calibrationService

    // MARK: - Calibration Data Collection

    /// 収集中の顔フレームデータ（位置の累積値）
    private var accumulatedFacePositions: AccumulatedFacePositions?

    /// 収集中の進捗情報
    private var currentProgress: CalibrationProgress?

    /// 最初のフレームを受け取ったかどうか
    private var hasReceivedFirstFrame = false

    // MARK: - Computed Properties

    /// 現在の顔ベース基準姿勢
    /// 旧形式または破損データは自動的にクリアされる
    var faceReferencePosture: FaceReferencePosture? {
        storage.loadFaceReferencePostureWithAutoClean()
    }

    // MARK: - Initializer

    /// イニシャライザ
    /// - Parameter storage: 永続化ストレージ
    init(storage: CalibrationStorageProtocol) {
        self.storage = storage

        // 初期状態はストレージの内容から導出
        // 旧形式または破損データは自動的にクリアされる
        if storage.loadFaceReferencePostureWithAutoClean() != nil {
            state = .completed
        } else {
            state = .notCalibrated
        }

        logger.debug("CalibrationService initialized: state=\(self.state.statusDescription)")
    }

    // MARK: - CalibrationServiceProtocol

    func startCalibration() async throws {
        // 既に実行中の場合はエラー
        if state.isInProgress {
            logger.warning("Failed to start calibration: already in progress")
            throw CalibrationError.alreadyInProgress
        }

        // 進捗情報を初期化（タイマーは最初のフレーム受信時に開始）
        accumulatedFacePositions = AccumulatedFacePositions()
        hasReceivedFirstFrame = false
        currentProgress = nil // 最初のフレーム受信時に作成

        // フレーム受信待ち状態の進捗で開始（タイマー未開始）
        state = .inProgress(.waitingForFrames())
        logger.info("Calibration started (waiting for frames)")
    }

    func cancelCalibration() {
        // 実行中でなければ何もしない
        guard state.isInProgress else {
            return
        }

        // 初期状態に戻す（キャンセルは失敗ではない）
        state = .notCalibrated
        currentProgress = nil
        accumulatedFacePositions = nil
        hasReceivedFirstFrame = false
        logger.info("Calibration cancelled")
    }

    /// UI状態を開始前状態にリセット（データは保持）
    ///
    /// キャリブレーションウィンドウを開く際に呼び出し、
    /// 「良い姿勢を保持してください」の開始画面を表示可能にする。
    /// ストレージのデータは削除しないため、`isCalibrated`は維持される。
    func prepareForRecalibration() {
        clearInProgressState()
        state = .notCalibrated
        logger.debug("Prepared for recalibration: state reset to notCalibrated")
    }

    func resetCalibration() {
        clearInProgressState()
        storage.deleteFaceReferencePosture()
        state = .notCalibrated
        logger.info("Calibration reset")
    }

    /// 実行中の状態をクリア（共通処理）
    private func clearInProgressState() {
        guard state.isInProgress else { return }
        currentProgress = nil
        accumulatedFacePositions = nil
        hasReceivedFirstFrame = false
    }

    // MARK: - Face Calibration

    /// 顔フレームを処理してキャリブレーションデータを収集
    func processFaceFrame(_ face: FacePosition) {
        // 実行中でなければ無視
        guard state.isInProgress,
              var accumulated = accumulatedFacePositions
        else {
            return
        }

        // 最初のフレーム受信時にタイマーを開始
        startTimerOnFirstFrame(logMessage: "Calibration: Starting frame collection")

        guard var progress = currentProgress else {
            return
        }

        // フレームの品質をチェック
        let frameQuality = evaluateFaceFrameQuality(face)

        // 進捗を更新
        progress.addFrame(quality: frameQuality)

        // 高品質フレームなら位置データを累積
        if frameQuality == .highConfidence {
            accumulated.add(face)
        }

        // 失敗判定
        if handleFailureIfNeeded(progress: progress) {
            return
        }

        // 完了判定
        if progress.isComplete {
            completeFaceCalibration(accumulated: accumulated)
            return
        }

        // 状態を更新
        currentProgress = progress
        accumulatedFacePositions = accumulated
        state = .inProgress(progress)
    }

    /// 顔未検出フレームを処理
    func processNoFaceFrame() {
        // 実行中でなければ無視
        guard state.isInProgress else {
            return
        }

        // 最初のフレーム受信時にタイマーを開始（顔未検出でも開始）
        startTimerOnFirstFrame(logMessage: "Calibration: Starting frame collection (no face detected)")

        guard var progress = currentProgress else {
            return
        }

        // 顔未検出としてフレームを追加
        progress.addFrame(quality: .noFaceDetected)

        // 失敗判定
        if handleFailureIfNeeded(progress: progress) {
            return
        }

        // 状態を更新
        currentProgress = progress
        state = .inProgress(progress)
    }

    // MARK: - Private Methods

    /// 最初のフレーム受信時にタイマーを開始
    ///
    /// - Parameter logMessage: ログに出力するメッセージ
    private func startTimerOnFirstFrame(logMessage: String) {
        guard !hasReceivedFirstFrame else { return }
        hasReceivedFirstFrame = true
        currentProgress = CalibrationProgress()
        logger.debug("\(logMessage)")
    }

    /// 失敗判定を行い、失敗時は状態を更新
    ///
    /// - Parameter progress: 現在の進捗
    /// - Returns: 失敗した場合は true
    private func handleFailureIfNeeded(progress: CalibrationProgress) -> Bool {
        guard let failure = progress.failureReason else {
            return false
        }
        state = .failed(failure)
        clearCalibrationData()
        logger.warning("Calibration failed: \(failure.logDescription)")
        return true
    }

    /// キャリブレーションデータをクリア
    ///
    /// 失敗時・完了時の共通クリーンアップ処理。
    private func clearCalibrationData() {
        currentProgress = nil
        accumulatedFacePositions = nil
    }

    /// 顔フレームの品質を評価
    ///
    /// - Parameter face: 評価する顔位置データ
    /// - Returns: フレームの品質レベル
    private func evaluateFaceFrameQuality(_ face: FacePosition) -> CalibrationProgress.FrameQuality {
        // FacePosition.isValid をチェック
        guard face.isValid else {
            return .noFaceDetected
        }

        // captureQuality が閾値以上かチェック（FacePosition.minimumCaptureQuality = 0.3）
        if face.captureQuality >= FacePosition.minimumCaptureQuality {
            return .highConfidence
        } else {
            return .lowConfidence
        }
    }

    /// キャリブレーションを完了
    private func completeFaceCalibration(accumulated: AccumulatedFacePositions) {
        // フレーム数が不足していれば失敗
        guard accumulated.frameCount >= FaceReferencePosture.minimumFrameCount else {
            state = .failed(.insufficientFrames)
            clearCalibrationData()
            logger.warning("""
            Calibration failed: insufficient frames \
            (\(accumulated.frameCount) < \(FaceReferencePosture.minimumFrameCount))
            """)
            return
        }

        // 平均位置からFaceReferencePostureを生成
        let facePosture = accumulated.createFaceReferencePosture()

        // 品質チェック
        guard facePosture.isValid else {
            state = .failed(.lowConfidence)
            clearCalibrationData()
            logger.warning("Calibration failed: average quality insufficient")
            return
        }

        // ストレージに保存
        storage.saveFaceReferencePosture(facePosture)

        // 状態を完了に
        state = .completed
        clearCalibrationData()

        let avgQuality = String(format: "%.2f", facePosture.averageQuality)
        logger
            .info(
                "Calibration complete: frameCount=\(facePosture.frameCount), avgQuality=\(avgQuality)"
            )
        logger.debug("""
        Calibration baseline: \
        baselineY=\(String(format: "%.3f", facePosture.baselineMetrics.baselineY)), \
        baselineArea=\(String(format: "%.3f", facePosture.baselineMetrics.baselineArea)), \
        baselineRoll=\(String(format: "%.3f", facePosture.baselineMetrics.baselineRoll))
        """)
    }
}
