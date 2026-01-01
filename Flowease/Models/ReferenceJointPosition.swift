import Foundation

/// キャリブレーションで記録した基準姿勢の関節位置
///
/// 複数フレームから平均化された関節位置を表す。
/// UserDefaultsへの永続化に対応するためCodableを実装。
struct ReferenceJointPosition: Codable, Sendable, Equatable {
    /// X座標 (0.0 = 左端, 1.0 = 右端)
    let x: Double

    /// Y座標 (0.0 = 下端, 1.0 = 上端)
    let y: Double

    /// 信頼度 (0.0 〜 1.0)
    let confidence: Double

    /// イニシャライザ
    /// - Parameters:
    ///   - x: X座標 (0.0〜1.0、範囲外の値はクランプされる)
    ///   - y: Y座標 (0.0〜1.0、範囲外の値はクランプされる)
    ///   - confidence: 信頼度 (0.0〜1.0、範囲外の値はクランプされる)
    init(x: Double, y: Double, confidence: Double) {
        self.x = x.isNaN ? 0.0 : min(max(x, 0.0), 1.0)
        self.y = y.isNaN ? 0.0 : min(max(y, 0.0), 1.0)
        self.confidence = confidence.isNaN ? 0.0 : min(max(confidence, 0.0), 1.0)
    }

    /// デコード時もバリデーションを適用
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawX = try container.decode(Double.self, forKey: .x)
        let rawY = try container.decode(Double.self, forKey: .y)
        let rawConfidence = try container.decode(Double.self, forKey: .confidence)
        self.init(x: rawX, y: rawY, confidence: rawConfidence)
    }
}
