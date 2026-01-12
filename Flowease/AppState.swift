//
//  AppState.swift
//  Flowease
//
//  アプリケーション全体の状態を管理
//

import AppKit
import SwiftUI

/// アプリケーション全体の状態を管理
///
/// ViewModels の保持と、メニューバーアイコンの動的更新を担当する。
@MainActor
@Observable
final class AppState {
    // MARK: - ViewModels

    let postureViewModel: PostureViewModel
    let calibrationViewModel: CalibrationViewModel

    // MARK: - Private Properties

    private let calibrationService: CalibrationService

    // MARK: - Alert Properties

    /// アラート設定ストレージ
    let alertSettingsStorage: AlertSettingsStorage

    /// アラート用スコア履歴
    private let alertScoreHistory: ScoreHistory

    /// 姿勢アラートサービス
    let alertService: PostureAlertService

    // MARK: - Alert Settings

    /// 現在のアラート設定
    var alertSettings: AlertSettings

    // MARK: - Computed Properties

    /// メニューバーアイコン（スコアに応じた色）
    var menuBarIcon: NSImage {
        MenuBarIcon.create(
            for: postureViewModel.monitoringState,
            score: postureViewModel.smoothedScore
        )
    }

    // MARK: - Alert Settings Methods

    /// アラート設定を更新し永続化する
    func updateAlertSettings(_ settings: AlertSettings) {
        alertSettings = settings
        alertSettingsStorage.save(settings)
        alertService.updateSettings(settings)
    }

    // MARK: - Initialization

    init() {
        // キャリブレーションサービスを作成
        let storage = CalibrationStorage()
        let calibrationService = CalibrationService(storage: storage)
        self.calibrationService = calibrationService

        // アラート関連サービスを作成
        let alertSettingsStorage = AlertSettingsStorage()
        self.alertSettingsStorage = alertSettingsStorage

        let alertScoreHistory = ScoreHistory()
        self.alertScoreHistory = alertScoreHistory

        let loadedAlertSettings = alertSettingsStorage.load()
        alertSettings = loadedAlertSettings
        let notificationManager = NotificationManager()
        let alertService = PostureAlertService(
            scoreHistory: alertScoreHistory,
            settings: loadedAlertSettings,
            notificationManager: notificationManager
        )
        self.alertService = alertService

        // ViewModel を作成
        postureViewModel = PostureViewModel(
            cameraService: CameraService(),
            postureAnalyzer: PostureAnalyzer(),
            faceScoreCalculator: FaceScoreCalculator(),
            calibrationService: calibrationService,
            alertScoreHistory: alertScoreHistory,
            alertService: alertService
        )

        calibrationViewModel = CalibrationViewModel(calibrationService: calibrationService)

        // 初期化を開始
        Task {
            await postureViewModel.initialize()
        }
    }
}
