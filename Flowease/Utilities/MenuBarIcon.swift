// MenuBarIcon.swift
// Flowease
//
// メニューバーアイコン生成ユーティリティ

import AppKit

/// メニューバーアイコン生成ユーティリティ
///
/// 姿勢監視状態に応じたメニューバーアイコンを生成する。
/// AppState から抽出された責務分離の結果。
enum MenuBarIcon {
    // MARK: - Constants

    /// アイコンサイズ
    private static let iconSize = CGSize(width: 18, height: 18)

    /// 円のサイズとオフセット
    private static let circleRect = NSRect(x: 3, y: 3, width: 12, height: 12)

    // MARK: - Public Methods

    /// 監視状態に応じたメニューバーアイコンを生成
    ///
    /// - Parameters:
    ///   - state: 現在の監視状態
    ///   - score: 平滑化されたスコア（active 状態時に使用）
    /// - Returns: 状態に応じた色の円形アイコン
    static func create(for state: MonitoringState, score: Int) -> NSImage {
        let color = iconColor(for: state, score: score)
        return createCircleIcon(color: color)
    }

    // MARK: - Private Methods

    /// 監視状態に応じたアイコン色を取得
    ///
    /// スコアに応じたグラデーション色を返す。
    /// - スコア 0: 赤
    /// - スコア 100: 緑
    private static func iconColor(for state: MonitoringState, score: Int) -> NSColor {
        switch state {
        case .active:
            return ColorGradient.nsColor(fromScore: score)
        case .paused, .disabled:
            return ColorGradient.nsGray
        }
    }

    /// 円形アイコン画像を作成
    private static func createCircleIcon(color: NSColor) -> NSImage {
        let image = NSImage(size: iconSize)

        image.lockFocus()
        color.setFill()
        NSBezierPath(ovalIn: circleRect).fill()
        image.unlockFocus()

        image.isTemplate = false
        return image
    }
}
