import Foundation

/// 姿勢スコアの記録
///
/// 個々の姿勢スコアとタイムスタンプを保持する軽量な構造体。
/// ScoreHistoryで時系列データとして管理される。
struct ScoreRecord: Equatable {
    /// スコア値 (0-100)
    let value: Int

    /// 記録時刻
    let timestamp: Date

    /// PostureScoreからScoreRecordを作成する
    /// - Parameter score: PostureScore
    init(from score: PostureScore) {
        value = score.value
        timestamp = score.timestamp
    }

    /// 値を直接指定してScoreRecordを作成する
    /// - Parameters:
    ///   - value: スコア値 (0-100)
    ///   - timestamp: 記録時刻
    init(value: Int, timestamp: Date) {
        self.value = value
        self.timestamp = timestamp
    }
}
