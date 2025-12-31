// StatusItemManager.swift
// Flowease
//
// NSStatusItem のアイコン更新を管理するクラス

import AppKit
import Observation
import OSLog

/// NSStatusItem のアイコン更新を管理するクラス
///
/// `PostureViewModel` の状態変化を監視し、
/// メニューバーアイコンを動的に更新する。
/// MenuBarExtra では動的な色変更ができないため、AppKit を使用。
@MainActor
final class StatusItemManager {
    // MARK: - Properties

    private let statusItem: NSStatusItem
    private let viewModel: PostureViewModel
    private let logger = Logger(subsystem: "cc.focuswave.Flowease", category: "StatusItemManager")

    // MARK: - Initialization

    init(statusItem: NSStatusItem, viewModel: PostureViewModel) {
        self.statusItem = statusItem
        self.viewModel = viewModel

        updateIcon()
        observeChanges()

        logger.debug("StatusItemManager 初期化完了")
    }

    // MARK: - Private Methods

    /// アイコンを更新
    private func updateIcon() {
        let color = iconColor(for: viewModel.monitoringState)
        statusItem.button?.image = createIcon(color: color)
    }

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
            let score = viewModel.smoothedScore
            let clampedScore = min(max(score, 0), 100)
            let hue = CGFloat(clampedScore) / 300.0
            return NSColor(hue: hue, saturation: 0.8, brightness: 0.9, alpha: 1.0)

        case .paused, .disabled:
            return .gray
        }
    }

    /// ViewModel の状態変化を監視（再帰的に呼び出し）
    private func observeChanges() {
        withObservationTracking {
            _ = self.viewModel.monitoringState
            _ = self.viewModel.smoothedScore
        } onChange: {
            Task { @MainActor [weak self] in
                self?.updateIcon()
                self?.observeChanges()
            }
        }
    }
}
