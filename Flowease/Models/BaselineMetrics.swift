import Foundation

/// キャリブレーション時に記録された基準姿勢の評価項目値
///
/// 基準姿勢時の各評価項目の計算値を保持する。
/// スコア計算時にこの値をゼロ点として使用し、現在の姿勢との逸脱度を算出する。
struct BaselineMetrics: Codable, Sendable, Equatable {
    /// 頭傾き: 首-鼻のX座標差（左右の傾き）
    /// 正の値 = 右に傾いている, 負の値 = 左に傾いている
    let headTiltDeviation: Double

    /// 肩バランス: 左右肩のY座標差
    /// 正の値 = 左肩が上, 負の値 = 右肩が上
    let shoulderBalance: Double

    /// 前傾: 首-鼻のY座標差（前傾時は鼻が下がる）
    /// 値が小さいほど前傾している
    let forwardLean: Double

    /// 対称性: 平均偏差値
    /// 0に近いほど左右対称
    let symmetry: Double

    /// イニシャライザ
    /// - Parameters:
    ///   - headTiltDeviation: 頭傾き値
    ///   - shoulderBalance: 肩バランス値
    ///   - forwardLean: 前傾値
    ///   - symmetry: 対称性値
    init(headTiltDeviation: Double, shoulderBalance: Double, forwardLean: Double, symmetry: Double) {
        self.headTiltDeviation = headTiltDeviation.isNaN || headTiltDeviation.isInfinite ? 0.0 : headTiltDeviation
        self.shoulderBalance = shoulderBalance.isNaN || shoulderBalance.isInfinite ? 0.0 : shoulderBalance
        self.forwardLean = forwardLean.isNaN || forwardLean.isInfinite ? 0.0 : forwardLean
        self.symmetry = symmetry.isNaN || symmetry.isInfinite ? 0.0 : symmetry
    }

    /// デコード時もバリデーションを適用
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawHeadTilt = try container.decode(Double.self, forKey: .headTiltDeviation)
        let rawShoulderBalance = try container.decode(Double.self, forKey: .shoulderBalance)
        let rawForwardLean = try container.decode(Double.self, forKey: .forwardLean)
        let rawSymmetry = try container.decode(Double.self, forKey: .symmetry)
        self.init(
            headTiltDeviation: rawHeadTilt,
            shoulderBalance: rawShoulderBalance,
            forwardLean: rawForwardLean,
            symmetry: rawSymmetry
        )
    }
}
