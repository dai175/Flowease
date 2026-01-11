import Foundation
import OSLog

/// スコア履歴管理
///
/// 姿勢スコアの時系列データを管理し、評価期間内の平均スコアと
/// データ充足率を計算する。メモリ内で保持し、永続化はしない。
final class ScoreHistory: @unchecked Sendable {
    /// 履歴データ（新しい順）
    private var records: [ScoreRecord] = []

    /// 最大保持期間（秒）
    /// 設定の最大評価期間（10分）+ バッファ（1分）
    private let maxRetentionSeconds: Int = 660 // 11分

    private let lock = NSLock()
    private let logger = Logger(subsystem: "cc.focuswave.Flowease", category: "ScoreHistory")

    init() {
        logger.debug("ScoreHistory initialized")
    }

    /// 現在のレコード数
    var recordCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return records.count
    }

    /// スコアを追加する
    ///
    /// ScoreRecordを履歴に追加し、古いデータを自動的に削除する。
    ///
    /// - Parameter record: 追加するスコアレコード
    func add(_ record: ScoreRecord) {
        lock.lock()
        defer { lock.unlock() }

        records.insert(record, at: 0)
        pruneOldRecords()

        logger.debug("Score added: \(record.value) at \(record.timestamp), total records: \(self.records.count)")
    }

    /// PostureScoreからスコアを追加する
    ///
    /// - Parameter score: 追加するPostureScore
    func add(_ score: PostureScore) {
        let record = ScoreRecord(from: score)
        add(record)
    }

    /// 指定期間内の平均スコアを計算
    ///
    /// - Parameter seconds: 現在時刻からの秒数
    /// - Returns: 平均スコア、またはデータがない場合はnil
    func averageScore(within seconds: Int) -> Double? {
        lock.lock()
        defer { lock.unlock() }

        let cutoff = Date().addingTimeInterval(-Double(seconds))
        let relevant = records.filter { $0.timestamp >= cutoff }

        guard !relevant.isEmpty else {
            logger.debug("No records within \(seconds) seconds")
            return nil
        }

        let sum = relevant.map(\.value).reduce(0, +)
        let average = Double(sum) / Double(relevant.count)

        logger.debug("Average score within \(seconds)s: \(average) (from \(relevant.count) records)")
        return average
    }

    /// 指定期間内のデータ充足率を計算
    ///
    /// - Parameters:
    ///   - seconds: 評価期間（秒）。0以下の場合は0.0を返す
    ///   - expectedInterval: 期待されるデータ間隔（秒、デフォルト1.0）。0以下の場合は0.0を返す
    /// - Returns: 充足率（0.0〜1.0）
    func dataCompleteness(within seconds: Int, expectedInterval: TimeInterval = 1.0) -> Double {
        // ゼロ除算および無効なパラメータのガード
        guard seconds > 0, expectedInterval > 0 else {
            logger
                .warning(
                    "Invalid parameters for dataCompleteness: seconds=\(seconds), expectedInterval=\(expectedInterval)"
                )
            return 0.0
        }

        lock.lock()
        defer { lock.unlock() }

        let cutoff = Date().addingTimeInterval(-Double(seconds))
        let count = records.count(where: { $0.timestamp >= cutoff })
        let expected = Double(seconds) / expectedInterval

        let completeness = min(Double(count) / expected, 1.0)

        logger.debug("Data completeness: \(completeness)")

        return completeness
    }

    /// 履歴をクリアする
    func clear() {
        lock.lock()
        defer { lock.unlock() }

        records.removeAll()
        logger.debug("Score history cleared")
    }

    /// 古いレコードを削除する
    private func pruneOldRecords() {
        let cutoff = Date().addingTimeInterval(-Double(maxRetentionSeconds))
        let beforeCount = records.count
        records.removeAll { $0.timestamp < cutoff }
        let removedCount = beforeCount - records.count

        if removedCount > 0 {
            logger.debug("Pruned \(removedCount) old records")
        }
    }
}
