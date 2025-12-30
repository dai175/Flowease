import SwiftUI

/// スコア→色変換ヘルパー
///
/// 姿勢スコアから SwiftUI の Color を生成するユーティリティ。
enum ColorGradient {
    /// スコアから SwiftUI Color を生成
    ///
    /// スコア 0 = 赤 (Hue 0°)、スコア 100 = 緑 (Hue 120°) のグラデーション。
    ///
    /// - Parameter score: 0〜100の範囲のスコア（範囲外の値は自動的にクランプされる）
    /// - Returns: スコアに対応した色
    static func color(fromScore score: Int) -> Color {
        let clampedScore = min(max(score, 0), 100)
        let hue = Double(clampedScore) / 100.0 / 3.0
        return Color(
            hue: hue,
            saturation: 0.8,
            brightness: 0.9
        )
    }

    /// グレー色
    ///
    /// カメラ利用不可時や人物未検出時に使用。
    static let gray: Color = .gray
}
