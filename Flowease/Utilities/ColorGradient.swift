import AppKit
import SwiftUI

/// スコア→色変換ヘルパー
///
/// 姿勢スコアから SwiftUI の Color または AppKit の NSColor を生成するユーティリティ。
enum ColorGradient {
    // MARK: - Constants

    /// 彩度
    private static let saturation: CGFloat = 0.8
    /// 明度
    private static let brightness: CGFloat = 0.9

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
}
