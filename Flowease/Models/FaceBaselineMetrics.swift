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
}
