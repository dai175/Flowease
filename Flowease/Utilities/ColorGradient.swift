import AppKit
import SwiftUI

/// スコア→色変換ヘルパー
///
/// 姿勢スコアから SwiftUI の Color または AppKit の NSColor を生成するユーティリティ。
enum ColorGradient {
    // MARK: - Color Parameters

    /// カラースキームに応じた彩度・明度のパラメータ
    private struct ColorParams {
        let saturation: CGFloat
        let brightness: CGFloat

        /// ダークモード用（高明度で鮮やかに）
        static let dark = ColorParams(saturation: 0.8, brightness: 0.9)
        /// ライトモード用（低明度・高彩度で白背景での視認性を向上）
        static let light = ColorParams(saturation: 0.85, brightness: 0.55)

        /// カラースキームに応じたパラメータを取得
        static func forScheme(_ scheme: ColorScheme) -> ColorParams {
            scheme == .light ? .light : .dark
        }
    }

    // MARK: - Hue Calculation

    /// スコアから Hue 値を計算
    ///
    /// スコア 0 = 赤 (Hue 0°)、スコア 100 = 緑 (Hue 120° = 1/3) のグラデーション。
    ///
    /// - Parameter score: 0〜100の範囲のスコア（範囲外の値は自動的にクランプされる）
    /// - Returns: 0.0〜0.333 の Hue 値
    static func hue(fromScore score: Int) -> CGFloat {
        let clampedScore = min(max(score, 0), 100)
        return CGFloat(clampedScore) / 300.0
    }

    /// ステータスから Hue 値を取得
    ///
    /// - Parameter status: スコアステータス
    /// - Returns: 固定の Hue 値
    private static func hue(for status: ScoreStatus) -> CGFloat {
        switch status {
        case .good: 0.333 // 緑
        case .fair: 0.166 // 黄
        case .poor: 0.05 // 橙
        }
    }

    // MARK: - SwiftUI Color

    /// スコアから SwiftUI Color を生成
    ///
    /// - Parameter score: 0〜100の範囲のスコア（範囲外の値は自動的にクランプされる）
    /// - Returns: スコアに対応した色
    static func color(fromScore score: Int) -> Color {
        let params = ColorParams.dark
        return Color(
            hue: hue(fromScore: score),
            saturation: params.saturation,
            brightness: params.brightness
        )
    }

    /// スコアから SwiftUI Color を生成（カラースキーム対応）
    ///
    /// ライトモードでは明度を下げ、彩度を上げることで白背景での視認性を向上。
    ///
    /// - Parameters:
    ///   - score: 0〜100の範囲のスコア（範囲外の値は自動的にクランプされる）
    ///   - colorScheme: 現在のカラースキーム
    /// - Returns: スコアに対応した色
    static func color(fromScore score: Int, colorScheme: ColorScheme) -> Color {
        let params = ColorParams.forScheme(colorScheme)
        return Color(
            hue: hue(fromScore: score),
            saturation: params.saturation,
            brightness: params.brightness
        )
    }

    /// グレー色（SwiftUI）
    ///
    /// カメラ利用不可時や人物未検出時に使用。
    static let gray: Color = .gray

    // MARK: - AppKit NSColor

    /// スコアから NSColor を生成
    ///
    /// メニューバーアイコンなど AppKit コンポーネントで使用。
    ///
    /// - Parameter score: 0〜100の範囲のスコア（範囲外の値は自動的にクランプされる）
    /// - Returns: スコアに対応した NSColor
    static func nsColor(fromScore score: Int) -> NSColor {
        let params = ColorParams.dark
        return NSColor(
            hue: hue(fromScore: score),
            saturation: params.saturation,
            brightness: params.brightness,
            alpha: 1.0
        )
    }

    /// グレー色（NSColor）
    static let nsGray: NSColor = .gray

    // MARK: - Fixed Status Colors

    /// ステータスに対応する固定色（SwiftUI）
    ///
    /// グラデーションではなく、Good/Fair/Poor の3段階で固定色を返す。
    /// - Good: 緑 (hue: 0.333)
    /// - Fair: 黄 (hue: 0.166)
    /// - Poor: 橙 (hue: 0.05)
    ///
    /// - Parameter status: スコアステータス
    /// - Returns: ステータスに対応した固定色
    static func color(for status: ScoreStatus) -> Color {
        let params = ColorParams.dark
        return Color(
            hue: hue(for: status),
            saturation: params.saturation,
            brightness: params.brightness
        )
    }

    /// ステータスに対応する固定色（SwiftUI、カラースキーム対応）
    ///
    /// ライトモードでは明度を下げ、彩度を上げることで白背景での視認性を向上。
    ///
    /// - Parameters:
    ///   - status: スコアステータス
    ///   - colorScheme: 現在のカラースキーム
    /// - Returns: ステータスに対応した固定色
    static func color(for status: ScoreStatus, colorScheme: ColorScheme) -> Color {
        let params = ColorParams.forScheme(colorScheme)
        return Color(
            hue: hue(for: status),
            saturation: params.saturation,
            brightness: params.brightness
        )
    }

    /// ステータスに対応する固定色（NSColor）
    ///
    /// メニューバーアイコンなど AppKit コンポーネントで使用。
    ///
    /// - Parameter status: スコアステータス
    /// - Returns: ステータスに対応した NSColor
    static func nsColor(for status: ScoreStatus) -> NSColor {
        let params = ColorParams.dark
        return NSColor(
            hue: hue(for: status),
            saturation: params.saturation,
            brightness: params.brightness,
            alpha: 1.0
        )
    }
}
