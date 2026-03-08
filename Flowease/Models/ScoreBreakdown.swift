import Foundation

/// スコアの構成要素（顔検出ベース）
///
/// 顔検出による姿勢スコアの内訳を表す。各評価項目は0〜100の範囲で表現される。
/// 3項目評価: 垂直位置変化(40%)、サイズ変化(40%)、傾き(20%)
struct ScoreBreakdown: Equatable, Codable {
    /// 垂直位置変化スコア (0-100) - 重み40%
    ///
    /// 顔のY座標の下方変化（うつむき）を評価。
    /// 100 = 基準位置と同じ、0 = 大きくうつむいている
    let verticalPosition: Int

    /// サイズ変化スコア (0-100) - 重み40%
    ///
    /// 顔の面積増加（前傾による接近）を評価。
    /// 100 = 基準サイズと同じ、0 = 大きく前傾している
    let sizeChange: Int

    /// 傾きスコア (0-100) - 重み20%
    ///
    /// 顔のroll角（首の傾き）を評価。
    /// 100 = 傾きなし、0 = 大きく傾いている
    let tilt: Int

    /// イニシャライザ
    /// - Parameters:
    ///   - verticalPosition: 垂直位置変化スコア (0-100、範囲外の値はクランプされる)
    ///   - sizeChange: サイズ変化スコア (0-100、範囲外の値はクランプされる)
    ///   - tilt: 傾きスコア (0-100、範囲外の値はクランプされる)
    init(verticalPosition: Int, sizeChange: Int, tilt: Int) {
        self.verticalPosition = min(max(verticalPosition, 0), 100)
        self.sizeChange = min(max(sizeChange, 0), 100)
        self.tilt = min(max(tilt, 0), 100)
    }
}
