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

    // MARK: - Computed Properties

    /// メニューバーアイコン（スコアに応じた色）
    var menuBarIcon: NSImage {
        MenuBarIcon.create(
            for: postureViewModel.monitoringState,
            score: postureViewModel.smoothedScore
        )
    }

    // MARK: - Initialization

    init() {
        // サービスを作成
        let storage = CalibrationStorage()
        let calibrationService = CalibrationService(storage: storage)
        self.calibrationService = calibrationService

        // ViewModel を作成
        postureViewModel = PostureViewModel(
            cameraService: CameraService(),
            postureAnalyzer: PostureAnalyzer(),
            faceScoreCalculator: FaceScoreCalculator(),
            calibrationService: calibrationService
        )

        calibrationViewModel = CalibrationViewModel(calibrationService: calibrationService)

        // 初期化を開始
        Task {
            await postureViewModel.initialize()
        }
    }
}
