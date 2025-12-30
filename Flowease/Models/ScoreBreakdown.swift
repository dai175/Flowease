import Foundation

/// スコアの構成要素
///
/// 姿勢スコアの内訳を表す。各評価項目は0〜100の範囲で表現される。
/// デバッグおよび将来の詳細表示用。
struct ScoreBreakdown: Sendable, Equatable {
    /// 頭部傾斜スコア (0-100)
    ///
    /// 首-鼻の垂直からの角度偏差を評価。
    /// 100 = 完全に垂直、0 = 大きく傾いている
    let headTilt: Int

    /// 肩バランススコア (0-100)
    ///
    /// 左右肩のY座標差を評価。
    /// 100 = 完全に水平、0 = 大きく傾いている
    let shoulderBalance: Int

    /// 前傾姿勢スコア (0-100)
    ///
    /// 鼻のX座標と首/rootの前後関係を評価。
    /// 100 = 前傾なし、0 = 大きく前傾している
    let forwardLean: Int

    /// 左右対称性スコア (0-100)
    ///
    /// 左右耳・肩の対称性を評価。
    /// 100 = 完全に対称、0 = 大きく非対称
    let symmetry: Int

    /// イニシャライザ
    /// - Parameters:
    ///   - headTilt: 頭部傾斜スコア (0-100、範囲外の値はクランプされる)
    ///   - shoulderBalance: 肩バランススコア (0-100、範囲外の値はクランプされる)
    ///   - forwardLean: 前傾姿勢スコア (0-100、範囲外の値はクランプされる)
    ///   - symmetry: 左右対称性スコア (0-100、範囲外の値はクランプされる)
    init(headTilt: Int, shoulderBalance: Int, forwardLean: Int, symmetry: Int) {
        self.headTilt = min(max(headTilt, 0), 100)
        self.shoulderBalance = min(max(shoulderBalance, 0), 100)
        self.forwardLean = min(max(forwardLean, 0), 100)
        self.symmetry = min(max(symmetry, 0), 100)
    }
}
