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
        let color = iconColor(for: postureViewModel.monitoringState)
        return createIcon(color: color)
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

    // MARK: - Private Methods

    /// アイコン画像を作成
    private func createIcon(color: NSColor) -> NSImage {
        let size = CGSize(width: 18, height: 18)
        let image = NSImage(size: size)

        image.lockFocus()
        color.setFill()
        NSBezierPath(ovalIn: NSRect(x: 3, y: 3, width: 12, height: 12)).fill()
        image.unlockFocus()

        image.isTemplate = false
        return image
    }

    /// 監視状態に応じたアイコン色を取得
    private func iconColor(for state: MonitoringState) -> NSColor {
        switch state {
        case .active:
            let score = postureViewModel.smoothedScore
            let clampedScore = min(max(score, 0), 100)
            let hue = CGFloat(clampedScore) / 300.0
            return NSColor(hue: hue, saturation: 0.8, brightness: 0.9, alpha: 1.0)

        case .paused, .disabled:
            return .gray
        }
    }
}
