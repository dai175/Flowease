import Foundation

/// 正規化された関節位置
///
/// Vision フレームワークから取得した関節位置を表す。
/// 座標は画像サイズに対して正規化された値（0.0〜1.0）で表現される。
struct JointPosition: Sendable, Equatable {
    /// X座標 (0.0 = 左端, 1.0 = 右端)
    let x: Double

    /// Y座標 (0.0 = 下端, 1.0 = 上端)
    let y: Double

    /// 検出の信頼度 (0.0 〜 1.0)
    let confidence: Double

    /// イニシャライザ
    /// - Parameters:
    ///   - x: X座標 (0.0〜1.0、範囲外の値はクランプされる)
    ///   - y: Y座標 (0.0〜1.0、範囲外の値はクランプされる)
    ///   - confidence: 検出の信頼度 (0.0〜1.0、範囲外の値はクランプされる)
    init(x: Double, y: Double, confidence: Double) {
        self.x = min(max(x, 0.0), 1.0)
        self.y = min(max(y, 0.0), 1.0)
        self.confidence = min(max(confidence, 0.0), 1.0)
    }
}
