import Foundation

/// 姿勢スコア (0-100)
///
/// 姿勢の分析結果を表すスコア。値が高いほど良好な姿勢を示す。
struct PostureScore: Sendable, Equatable {
    /// スコア値 (0: 最悪 〜 100: 最良)
    let value: Int

    /// スコア算出時刻
    let timestamp: Date

    /// 各評価項目の詳細スコア
    let breakdown: ScoreBreakdown

    /// 検出の信頼度 (0.0 〜 1.0)
    let confidence: Double

    /// イニシャライザ
    /// - Parameters:
    ///   - value: スコア値 (0-100、範囲外の値はクランプされる)
    ///   - timestamp: スコア算出時刻
    ///   - breakdown: 各評価項目の詳細スコア
    ///   - confidence: 検出の信頼度 (0.0〜1.0、範囲外の値はクランプされる)
    init(value: Int, timestamp: Date, breakdown: ScoreBreakdown, confidence: Double) {
        self.value = min(max(value, 0), 100)
        self.timestamp = timestamp
        self.breakdown = breakdown
        self.confidence = confidence.isNaN ? 0.0 : min(max(confidence, 0.0), 1.0)
    }
}
