//
//  PostureViewModel.swift
//  Flowease
//
//  姿勢監視状態を管理する ViewModel
//

// swiftlint:disable file_length

@preconcurrency import AVFoundation
import Combine
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

    /// 現在選択されているカメラのID（UIバインディング用）
    private(set) var selectedCameraID: String?

    // MARK: - Dependencies

    private let cameraService: CameraServiceProtocol
    private let postureAnalyzer: PostureAnalyzing
    private let faceScoreCalculator: FaceScoreCalculator
    /// キャリブレーションサービス
    /// Note: @Observableの追跡を有効にするため、具象型で保持
    private let calibrationService: CalibrationService
    private let logger = Logger.postureViewModel

    // MARK: - Alert Dependencies

    /// アラート用スコア履歴（通知判定用、UI表示用scoreHistoryとは別管理）
    private let alertScoreHistory: (any ScoreHistoryProtocol)?

    /// 姿勢アラートサービス
    private let alertService: PostureAlertService?

    // MARK: - Private State

    /// 初期化済みフラグ（重複初期化を防止）
    private var isInitialized = false

    /// 現在進行中のフレーム処理タスク（終了時にキャンセル用）
    /// nil = 処理中でない、非nil = 処理中
    private var processingTask: Task<Void, Never>?

    /// キャリブレーションリセット通知の購読
    ///
    /// Note: @MainActor クラスの deinit は nonisolated であるため、
    /// deinit からこのプロパティにアクセスするには nonisolated(unsafe) が必要。
    /// このプロパティは init で設定され、deinit でのみ読み取られる。
    /// Xcode の警告「has no effect」は Swift の @Observable マクロとの相互作用による
    /// 誤検知であり、実際には deinit でのアクセスに必要。
    private nonisolated(unsafe) var calibrationResetObserver: NSObjectProtocol?

    /// CameraService の selectedCameraID 変更を購読
    private var cameraSubscription: AnyCancellable?

    // MARK: - State Stabilization

    /// 状態安定化用のスコア履歴（3秒平均用）
    private var stateScoreHistory: [PostureScore] = []

    /// 状態平均化の期間（秒）
    private let stateAveragingPeriodSeconds: TimeInterval = 3.0

    // MARK: - Detection Failure Stabilization

    /// 連続検出失敗のカウンター
    private var consecutiveFailureCount: Int = 0

    /// 状態遷移に必要な連続失敗回数の閾値（一時的な検出失敗を無視するため）
    private let failureThreshold: Int = 5

    /// 検出失敗時のスコア減少量（1フレームあたり）
    private let scoreDecayPerFrame: Int = 5

    // MARK: - Constants

    /// スコア履歴の最大保持件数
    private let maxScoreHistoryCount = 10

    // MARK: - Computed Properties

    /// 平滑化されたスコア（リアルタイム表示用）
    ///
    /// スコア履歴の移動平均を返す。履歴が空の場合は 0 を返す。
    var smoothedScore: Int {
        guard !scoreHistory.isEmpty else { return 0 }
        let sum = scoreHistory.reduce(0) { $0 + $1.value }
        return sum / scoreHistory.count
    }

    /// 評価期間内の平均スコア（メイン表示・通知判定用）
    ///
    /// アラート設定の評価期間内の平均スコアを返す。
    /// アラートサービスが設定されていない場合、または評価期間内にデータがない場合は nil を返す。
    var evaluationPeriodAverageScore: Double? {
        guard let history = alertScoreHistory,
              let service = alertService else { return nil }
        return history.averageScore(within: service.settings.evaluationPeriodSeconds)
    }

    /// 評価期間（分）
    ///
    /// アラート設定から評価期間を取得する。
    /// アラートサービスが設定されていない場合はデフォルト値を返す。
    var evaluationPeriodMinutes: Int {
        let seconds = alertService?.settings.evaluationPeriodSeconds
            ?? AlertSettings.default.evaluationPeriodSeconds
        return seconds / 60
    }

    /// 安定化されたスコアステータス
    ///
    /// 3秒間の平均スコアに基づくステータスを返す。
    /// これにより、状態ラベル（Good/Fair/Poor）が頻繁に切り替わることを防ぐ。
    var stabilizedScoreStatus: ScoreStatus {
        let cutoff = Date().addingTimeInterval(-stateAveragingPeriodSeconds)
        let recentValues = stateScoreHistory
            .filter { $0.timestamp >= cutoff }
            .map(\.value)

        // 履歴がない場合は現在のスムージングスコアから計算
        guard !recentValues.isEmpty else {
            return ScoreStatus(score: smoothedScore)
        }

        let average = recentValues.reduce(0, +) / recentValues.count
        return ScoreStatus(score: average)
    }

    /// 現在のアイコン色
    ///
    /// `monitoringState` に基づいて色を返す。
    /// - active: 安定化されたステータスに応じた固定色（緑/黄/橙）
    /// - paused / disabled: グレー
    var iconColor: Color {
        switch monitoringState {
        case .active:
            return ColorGradient.color(for: stabilizedScoreStatus)
        case .paused, .disabled:
            return ColorGradient.gray
        }
    }

    /// カメラサービスへのアクセス（read-only）
    ///
    /// StatusMenuView からカメラ選択機能にアクセスするために使用します。
    var cameraServiceAccess: CameraServiceProtocol { cameraService }

    /// 利用可能なカメラ一覧
    var availableCameras: [CameraDevice] { cameraService.availableCameras }

    /// カメラ権限状態
    var cameraAuthorizationStatus: CameraAuthorizationStatus { cameraService.authorizationStatus }

    // MARK: - Camera Selection

    /// カメラを選択
    ///
    /// - Parameter deviceID: 選択するカメラのuniqueID (nil でシステムデフォルト)
    func selectCamera(_ deviceID: String?) {
        cameraService.selectCamera(deviceID)
        // Combine 購読で selectedCameraID は自動更新される
        // Mock の場合は手動で更新
        if !(cameraService is CameraService) {
            selectedCameraID = deviceID
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
    ///   - alertScoreHistory: アラート用スコア履歴（nilでアラート無効）
    ///   - alertService: 姿勢アラートサービス（nilでアラート無効）
    init(
        cameraService: CameraServiceProtocol,
        postureAnalyzer: PostureAnalyzing,
        faceScoreCalculator: FaceScoreCalculator,
        calibrationService: CalibrationService,
        alertScoreHistory: (any ScoreHistoryProtocol)? = nil,
        alertService: PostureAlertService? = nil
    ) {
        self.cameraService = cameraService
        self.postureAnalyzer = postureAnalyzer
        self.faceScoreCalculator = faceScoreCalculator
        self.calibrationService = calibrationService
        self.alertScoreHistory = alertScoreHistory
        self.alertService = alertService

        // 初期値を同期
        selectedCameraID = cameraService.selectedCameraID

        logger.debug("PostureViewModel initialized")

        // CameraService の selectedCameraID 変更を購読（具象型の場合のみ）
        if let concreteService = cameraService as? CameraService {
            cameraSubscription = concreteService.$selectedCameraID
                .receive(on: DispatchQueue.main)
                .sink { [weak self] newValue in
                    self?.selectedCameraID = newValue
                }
        }

        // キャリブレーションリセット通知を購読
        calibrationResetObserver = NotificationCenter.default.addObserver(
            forName: .calibrationReset,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleCalibrationReset()
        }
    }

    // MARK: - Deinitialization

    deinit {
        // NotificationCenter observer を解除してメモリリークを防止
        if let observer = calibrationResetObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Calibration Reset Handler

    /// キャリブレーションリセット時の処理
    ///
    /// Note: NotificationCenter コールバックの要件上 nonisolated ですが、
    /// Task ブロック内で @MainActor コンテキストに移行します
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
    /// アラートサービスが設定されている場合は通知判定も実行する。
    ///
    /// - Parameter score: 追加する姿勢スコア
    func addScore(_ score: PostureScore) {
        scoreHistory.append(score)

        // 最大件数を超えた場合は古いものから削除
        if scoreHistory.count > maxScoreHistoryCount {
            scoreHistory.removeFirst()
        }

        // 状態安定化用履歴に追加
        stateScoreHistory.append(score)
        // 古いスコアを削除（平均化期間 + 1秒のバッファ）
        let cutoff = Date().addingTimeInterval(-(stateAveragingPeriodSeconds + 1.0))
        stateScoreHistory.removeAll { $0.timestamp < cutoff }

        // 状態を active に更新
        monitoringState = .active(score)
        logger.debug("Score added: \(score.value), smoothed score: \(self.smoothedScore)")

        // アラート用スコア履歴に追加し、通知判定を実行
        if let alertHistory = alertScoreHistory, let service = alertService {
            alertHistory.add(score)
            Task {
                await service.evaluate()
            }
        }
    }

    /// スコア履歴をクリア
    ///
    /// 監視が中断された場合などに呼び出す。
    /// 状態安定化用履歴とアラートサービスの状態・履歴もリセットする。
    func clearScoreHistory() {
        scoreHistory.removeAll()
        stateScoreHistory.removeAll()
        alertService?.reset()
        logger.debug("Score history cleared (including state and alert history)")
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
        consecutiveFailureCount = 0
        monitoringState = .paused(.cameraInitializing)
        logger.info("Posture monitoring stopped")
    }

    // MARK: - Private Methods

    /// フレームから顔を分析してスコアを更新
    private func processFrame(_ sampleBuffer: CMSampleBuffer) async {
        defer { processingTask = nil }
        guard cameraService.isCapturing else { return }

        let result = await postureAnalyzer.analyze(sampleBuffer: sampleBuffer)

        switch result {
        case let .success(facePosition):
            handleSuccessfulDetection(facePosition)
        case .noFaceDetected:
            handleNoFaceDetected()
        case .lowDetectionQuality:
            break // 一時的な品質低下は無視
        case .visionError:
            handleVisionError()
        }
    }

    /// 顔検出成功時の処理
    private func handleSuccessfulDetection(_ facePosition: FacePosition) {
        consecutiveFailureCount = 0
        guard cameraService.isCapturing else { return }

        if calibrationService.state.isInProgress {
            calibrationService.processFaceFrame(facePosition)
            if calibrationService.state.isCompleted,
               let referencePosture = calibrationService.faceReferencePosture {
                faceScoreCalculator.setReferencePosture(referencePosture)
                logger.info("Calibration complete: Set reference posture to FaceScoreCalculator")
            }
            return
        }

        guard let score = faceScoreCalculator.calculate(from: facePosition) else {
            logger.debug("Score calculation failed (reference posture not set or invalid data)")
            return
        }
        addScore(score)
    }

    /// 顔未検出時の処理（スコアを徐々に減少）
    ///
    /// 減衰スコアはUI表示用のみに追加し、アラート履歴には追加しない。
    /// ユーザー不在時に誤って通知が送られることを防ぐ。
    /// breakdown は減衰比率に応じて比例スケーリングする。
    private func handleNoFaceDetected() {
        if let lastScore = scoreHistory.last {
            let decayedValue = lastScore.value - scoreDecayPerFrame
            if decayedValue > 0 {
                // breakdown を比例スケーリング
                let ratio = Double(decayedValue) / Double(lastScore.value)
                let scaledBreakdown = ScoreBreakdown(
                    verticalPosition: Int(Double(lastScore.breakdown.verticalPosition) * ratio),
                    sizeChange: Int(Double(lastScore.breakdown.sizeChange) * ratio),
                    tilt: Int(Double(lastScore.breakdown.tilt) * ratio)
                )
                let decayedScore = PostureScore(
                    value: decayedValue,
                    timestamp: Date(),
                    breakdown: scaledBreakdown,
                    confidence: 0.0
                )
                // UI表示用のみに追加（アラート履歴には追加しない）
                addScoreForDisplayOnly(decayedScore)
            } else {
                pauseIfActive(reason: .noFaceDetected, logMessage: "Paused due to no face detected (score decayed)")
            }
        } else {
            consecutiveFailureCount += 1
            if consecutiveFailureCount >= failureThreshold {
                pauseIfActive(reason: .noFaceDetected, logMessage: "Paused due to no face detected")
            }
        }
    }

    /// UI表示用のスコアのみを追加（アラート判定には使用しない）
    ///
    /// 顔未検出時の減衰スコアなど、実際の姿勢を反映しないスコアに使用する。
    private func addScoreForDisplayOnly(_ score: PostureScore) {
        scoreHistory.append(score)
        if scoreHistory.count > maxScoreHistoryCount {
            scoreHistory.removeFirst()
        }

        stateScoreHistory.append(score)
        let cutoff = Date().addingTimeInterval(-(stateAveragingPeriodSeconds + 1.0))
        stateScoreHistory.removeAll { $0.timestamp < cutoff }

        monitoringState = .active(score)
        logger.debug("Display-only score added: \(score.value) (not sent to alert history)")
    }

    /// Vision エラー時の処理
    private func handleVisionError() {
        consecutiveFailureCount += 1
        if consecutiveFailureCount >= failureThreshold {
            pauseIfActive(reason: .processingError, logMessage: "Paused due to Vision framework error")
        }
    }

    /// アクティブ状態の場合のみ一時停止する
    ///
    /// スコア履歴をクリアし、指定された理由で一時停止状態に遷移する。
    /// 連続失敗カウンターもリセットする。
    /// - Parameters:
    ///   - reason: 一時停止の理由
    ///   - logMessage: ログに出力するメッセージ
    private func pauseIfActive(reason: PauseReason, logMessage: String) {
        guard case .active = monitoringState else { return }
        monitoringState = .paused(reason)
        clearScoreHistory()
        consecutiveFailureCount = 0
        logger.debug("\(logMessage) (score history cleared)")
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
            if let newState = cameraError.asMonitoringState {
                monitoringState = newState
            } else {
                // selectedCameraFailed: フォールバック成功、状態変更なし
                logger.warning("Selected camera failed, using fallback camera")
            }
        } else {
            // 未知のエラーに対するフォールバック
            monitoringState = .paused(.cameraInitializing)
        }
    }
}
