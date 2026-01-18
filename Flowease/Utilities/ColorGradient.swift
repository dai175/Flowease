import AppKit
import SwiftUI

/// スコア→色変換ヘルパー
///
/// 姿勢スコアから SwiftUI の Color または AppKit の NSColor を生成するユーティリティ。
enum ColorGradient {
    // MARK: - Constants

    /// 彩度（ダークモード）
    private static let saturation: CGFloat = 0.8
    /// 明度（ダークモード）
    private static let brightness: CGFloat = 0.9

    /// 彩度（ライトモード）- コントラスト向上のため高め
    private static let saturationLight: CGFloat = 0.85
    /// 明度（ライトモード）- 白背景での視認性向上のため低め
    private static let brightnessLight: CGFloat = 0.55

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

    // MARK: - SwiftUI Color

    /// スコアから SwiftUI Color を生成
    ///
    /// - Parameter score: 0〜100の範囲のスコア（範囲外の値は自動的にクランプされる）
    /// - Returns: スコアに対応した色
    static func color(fromScore score: Int) -> Color {
        Color(
            hue: hue(fromScore: score),
            saturation: saturation,
            brightness: brightness
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
        let (sat, bri) = colorScheme == .light
            ? (saturationLight, brightnessLight)
            : (saturation, brightness)
        return Color(
            hue: hue(fromScore: score),
            saturation: sat,
            brightness: bri
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
        NSColor(
            hue: hue(fromScore: score),
            saturation: saturation,
            brightness: brightness,
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
        Color(
            hue: hue(for: status),
            saturation: saturation,
            brightness: brightness
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
        let (sat, bri) = colorScheme == .light
            ? (saturationLight, brightnessLight)
            : (saturation, brightness)
        return Color(
            hue: hue(for: status),
            saturation: sat,
            brightness: bri
        )
    }

    /// ステータスに対応する固定色（NSColor）
    ///
    /// メニューバーアイコンなど AppKit コンポーネントで使用。
    ///
    /// - Parameter status: スコアステータス
    /// - Returns: ステータスに対応した NSColor
    static func nsColor(for status: ScoreStatus) -> NSColor {
        NSColor(
            hue: hue(for: status),
            saturation: saturation,
            brightness: brightness,
            alpha: 1.0
        )
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
}
