//
//  PostureViewModel.swift
//  Flowease
//
//  姿勢監視状態を管理する ViewModel
//

@preconcurrency import AVFoundation
import Foundation
import Observation
import OSLog
import SwiftUI

// MARK: - PostureViewModel

/// 姿勢監視の状態を管理する ViewModel
///
/// カメラ権限の確認・要求と監視状態の更新を担当する。
/// SwiftUI ビューは `monitoringState` を監視して UI を更新する。
@MainActor
@Observable
final class PostureViewModel {
    // MARK: - Published State

    /// 現在の監視状態
    private(set) var monitoringState: MonitoringState = .paused(.cameraInitializing)

    /// スコア履歴 (スムージング用、最大10件)
    private(set) var scoreHistory: [PostureScore] = []

    // MARK: - Dependencies

    private let cameraService: CameraServiceProtocol
    private let postureAnalyzer: PostureAnalyzing
    private let faceScoreCalculator: FaceScoreCalculator
    /// キャリブレーションサービス
    /// Note: @Observableの追跡を有効にするため、具象型で保持
    private let calibrationService: CalibrationService
    private let logger = Logger(subsystem: "cc.focuswave.Flowease", category: "PostureViewModel")

    // MARK: - Private State

    /// 初期化済みフラグ（重複初期化を防止）
    private var isInitialized = false

    /// 現在進行中のフレーム処理タスク（終了時にキャンセル用）
    /// nil = 処理中でない、非nil = 処理中
    private var processingTask: Task<Void, Never>?

    /// キャリブレーションリセット通知の購読
    private var calibrationResetObserver: NSObjectProtocol?

    // MARK: - Constants

    /// スコア履歴の最大保持件数
    private let maxScoreHistoryCount = 10

    // MARK: - Computed Properties

    /// 平滑化されたスコア
    ///
    /// スコア履歴の移動平均を返す。履歴が空の場合は 0 を返す。
    var smoothedScore: Int {
        guard !scoreHistory.isEmpty else { return 0 }
        let sum = scoreHistory.reduce(0) { $0 + $1.value }
        return sum / scoreHistory.count
    }

    /// 現在のアイコン色
    ///
    /// `monitoringState` に基づいて色を返す。
    /// - active: スコアに応じた緑〜赤のグラデーション
    /// - paused / disabled: グレー
    var iconColor: Color {
        switch monitoringState {
        case .active:
            return ColorGradient.color(fromScore: smoothedScore)
        case .paused, .disabled:
            return ColorGradient.gray
        }
    }

    // MARK: - Initialization

    /// イニシャライザ
    ///
    /// - Parameters:
    ///   - cameraService: カメラサービス（依存注入によりテスト可能）
    ///   - postureAnalyzer: 姿勢分析サービス
    ///   - faceScoreCalculator: 顔ベーススコア計算サービス
    ///   - calibrationService: キャリブレーションサービス
    init(
        cameraService: CameraServiceProtocol,
        postureAnalyzer: PostureAnalyzing,
        faceScoreCalculator: FaceScoreCalculator,
        calibrationService: CalibrationService
    ) {
        self.cameraService = cameraService
        self.postureAnalyzer = postureAnalyzer
        self.faceScoreCalculator = faceScoreCalculator
        self.calibrationService = calibrationService
        logger.debug("PostureViewModel initialized")

        // キャリブレーションリセット通知を購読
        calibrationResetObserver = NotificationCenter.default.addObserver(
            forName: .calibrationReset,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleCalibrationReset()
        }
    }

    // MARK: - Calibration Reset Handler

    /// キャリブレーションリセット時の処理
    private nonisolated func handleCalibrationReset() {
        Task { @MainActor in
            faceScoreCalculator.setReferencePosture(nil)
            logger.info("Calibration reset: Cleared FaceScoreCalculator reference posture")
        }
    }

    /// 本番用イニシャライザ
    ///
    /// デフォルトのサービスを使用する。
    convenience init() {
        let storage = CalibrationStorage()
        let calibrationService = CalibrationService(storage: storage)
        self.init(
            cameraService: CameraService(),
            postureAnalyzer: PostureAnalyzer(),
            faceScoreCalculator: FaceScoreCalculator(),
            calibrationService: calibrationService
        )
    }

    // MARK: - Public Methods

    /// 初期化処理
    ///
    /// アプリ起動時に呼び出し、カメラ権限を確認して監視状態を更新する。
    /// 権限が未決定の場合は自動的にリクエストする。
    /// 複数回呼び出されても安全（べき等）。
    func initialize() async {
        guard !isInitialized else {
            logger.debug("PostureViewModel already initialized")
            return
        }
        isInitialized = true

        logger.info("PostureViewModel initialization started")

        // キャリブレーション済みの場合、基準姿勢をFaceScoreCalculatorに設定
        if let referencePosture = calibrationService.faceReferencePosture {
            faceScoreCalculator.setReferencePosture(referencePosture)
            logger.info("Calibrated: Set reference posture to FaceScoreCalculator")
        }

        // カメラデバイス・権限チェック
        updateMonitoringState()

        // 権限が未決定の場合はリクエスト
        if cameraService.authorizationStatus == .notDetermined {
            logger.info("Requesting camera permission...")
            _ = await cameraService.requestAuthorization()
            updateMonitoringState()
        }

        logger.info("PostureViewModel initialization complete: \(String(describing: self.monitoringState))")

        // 権限が許可されていれば監視を開始
        if cameraService.authorizationStatus == .authorized {
            startMonitoring()
        }
    }

    /// 監視状態を更新
    ///
    /// カメラサービスの現在の状態に基づいて `monitoringState` を更新する。
    /// active 状態の場合は維持される（スコアが追加されたら active になり、
    /// 明示的に変更されない限り維持）。
    func updateMonitoringState() {
        // active 状態の場合は維持
        if case .active = monitoringState {
            return
        }

        let newState = cameraService.toMonitoringState()

        // 状態が変化した場合のみログ出力
        if monitoringState != newState {
            logger.debug("State update: \(String(describing: self.monitoringState)) -> \(String(describing: newState))")
        }

        monitoringState = newState
    }

    /// スコアを追加
    ///
    /// 新しいスコアを履歴に追加し、監視状態を `active` に更新する。
    /// 履歴が最大件数を超えた場合は古いものから削除する。
    ///
    /// - Parameter score: 追加する姿勢スコア
    func addScore(_ score: PostureScore) {
        scoreHistory.append(score)

        // 最大件数を超えた場合は古いものから削除
        if scoreHistory.count > maxScoreHistoryCount {
            scoreHistory.removeFirst()
        }

        // 状態を active に更新
        monitoringState = .active(score)
        logger.debug("Score added: \(score.value), smoothed score: \(self.smoothedScore)")
    }

    /// スコア履歴をクリア
    ///
    /// 監視が中断された場合などに呼び出す。
    func clearScoreHistory() {
        scoreHistory.removeAll()
        logger.debug("Score history cleared")
    }

    /// 姿勢監視を開始
    ///
    /// カメラ権限が許可されている場合、フレームキャプチャを開始する。
    /// 権限がない場合は何もしない。
    func startMonitoring() {
        guard cameraService.authorizationStatus == .authorized else {
            logger.warning("Cannot start monitoring: Camera permission not granted")
            return
        }

        // デリゲートを設定してキャプチャ開始
        cameraService.frameDelegate = self
        cameraService.startCapturing()
        logger.info("Posture monitoring started")
    }

    /// 姿勢監視を停止
    ///
    /// フレームキャプチャを停止し、状態をリセットする。
    /// 進行中のフレーム処理タスクもキャンセルする。
    func stopMonitoring() {
        // 進行中のタスクをキャンセル
        processingTask?.cancel()
        processingTask = nil

        cameraService.stopCapturing()
        cameraService.frameDelegate = nil
        clearScoreHistory()
        monitoringState = .paused(.cameraInitializing)
        logger.info("Posture monitoring stopped")
    }

    // MARK: - Private Methods

    /// フレームから顔を分析してスコアを更新
    ///
    /// - Parameter sampleBuffer: カメラからのフレームデータ
    private func processFrame(_ sampleBuffer: CMSampleBuffer) async {
        // タスク完了時に参照をクリア（次のフレーム処理を許可）
        defer { processingTask = nil }

        // 停止後に飛んできたフレームは無視
        guard cameraService.isCapturing else {
            return
        }

        // 顔を分析
        let result = await postureAnalyzer.analyze(sampleBuffer: sampleBuffer)

        switch result {
        case let .success(facePosition):
            // 顔分析中に停止された場合は無視
            guard cameraService.isCapturing else {
                return
            }

            // キャリブレーション中であればフレームを渡す
            if calibrationService.state.isInProgress {
                calibrationService.processFaceFrame(facePosition)

                // キャリブレーション完了後、基準姿勢を設定
                if calibrationService.state.isCompleted,
                   let referencePosture = calibrationService.faceReferencePosture {
                    faceScoreCalculator.setReferencePosture(referencePosture)
                    logger.info("Calibration complete: Set reference posture to FaceScoreCalculator")
                }
                return
            }

            // スコアを計算
            guard let score = faceScoreCalculator.calculate(from: facePosition) else {
                logger.debug("Score calculation failed (reference posture not set or invalid data)")
                return
            }

            // スコアを追加（状態は addScore 内で active に更新される）
            addScore(score)

        case .noFaceDetected:
            // 顔が検出されない場合、スコア履歴をクリアして一時停止
            if case .active = monitoringState {
                monitoringState = .paused(.noFaceDetected)
                clearScoreHistory()
                logger.debug("Paused due to no face detected (score history cleared)")
            }

        case .lowDetectionQuality:
            // 検出精度が低下している場合、スコア履歴をクリアして一時停止
            if case .active = monitoringState {
                monitoringState = .paused(.lowDetectionQuality)
                clearScoreHistory()
                logger.debug("Paused due to low detection quality (score history cleared)")
            }
        }
    }
}

// MARK: CameraFrameDelegate

extension PostureViewModel: CameraFrameDelegate {
    func cameraService(_: any CameraServiceProtocol, didCaptureFrame sampleBuffer: CMSampleBuffer) {
        // 処理中はタスクを作成しない（既存タスクの参照を上書きしない）
        // これにより stopMonitoring で実行中のタスクを確実にキャンセルできる
        guard processingTask == nil else { return }

        processingTask = Task {
            await processFrame(sampleBuffer)
        }
    }

    func cameraService(_: any CameraServiceProtocol, didEncounterError error: Error) {
        logger.error("Camera error: \(error.localizedDescription)")

        // エラーの種類に応じて状態を更新
        if let cameraError = error as? CameraServiceError {
            switch cameraError {
            case .noCameraAvailable:
                monitoringState = .disabled(.noCameraAvailable)
            case .permissionDenied:
                monitoringState = .disabled(.cameraPermissionDenied)
            case .cameraInUse:
                monitoringState = .paused(.cameraInUse)
            case .sessionConfigurationFailed:
                monitoringState = .paused(.cameraInitializing)
            }
        } else {
            // 未知のエラーに対するフォールバック
            monitoringState = .paused(.cameraInitializing)
        }
    }
}
