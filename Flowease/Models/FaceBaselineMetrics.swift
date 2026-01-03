import Foundation

/// キャリブレーション時に記録された顔ベース基準値
///
/// 基準姿勢時の顔位置・サイズ・傾きを保持する。
/// スコア計算時にこの値を基準として逸脱度を算出する。
struct FaceBaselineMetrics: Codable, Sendable, Equatable {
    /// 基準顔中心Y座標（正規化座標 0-1）
    let baselineY: Double

    /// 基準顔面積（正規化座標）
    let baselineArea: Double

    /// 基準roll角（ラジアン）
    let baselineRoll: Double

    // MARK: - Default Values for Sanitization

    /// baselineYのデフォルト値（画面中央）
    private static let defaultBaselineY: Double = 0.5

    /// baselineAreaのデフォルト値（小さめのデフォルト）
    private static let defaultBaselineArea: Double = 0.01

    /// baselineRollのデフォルト値（傾きなし）
    private static let defaultBaselineRoll: Double = 0.0

    // MARK: - Initializer

    /// イニシャライザ（NaN/Infinite値をデフォルト値にサニタイズ）
    ///
    /// - Parameters:
    ///   - baselineY: 基準顔中心Y座標。NaNまたはInfiniteの場合は0.5
    ///   - baselineArea: 基準顔面積。NaNまたはInfiniteの場合は0.01
    ///   - baselineRoll: 基準roll角。NaNまたはInfiniteの場合は0.0
    init(baselineY: Double, baselineArea: Double, baselineRoll: Double) {
        self.baselineY = Self.sanitize(baselineY, default: Self.defaultBaselineY)
        self.baselineArea = Self.sanitize(baselineArea, default: Self.defaultBaselineArea)
        self.baselineRoll = Self.sanitize(baselineRoll, default: Self.defaultBaselineRoll)
    }

    // MARK: - Private Helpers

    /// NaN/Infinite値をデフォルト値にサニタイズ
    private static func sanitize(_ value: Double, default defaultValue: Double) -> Double {
        if value.isNaN || value.isInfinite {
            return defaultValue
        }
        return value
    }
}
