import Foundation
import Testing

@testable import Flowease

/// ScoreHistoryのテスト
@MainActor
struct ScoreHistoryTests {
    // MARK: - Test Helpers

    private func makeScoreRecord(value: Int, timestamp: Date = Date()) -> ScoreRecord {
        ScoreRecord(value: value, timestamp: timestamp)
    }

    // MARK: - Add Score Tests

    @Test func addScoreStoresRecord() {
        // Given
        let history = ScoreHistory()
        let record = makeScoreRecord(value: 75)

        // When
        history.add(record)

        // Then
        #expect(history.recordCount == 1)
    }

    @Test func addMultipleScoresStoresAllRecords() {
        // Given
        let history = ScoreHistory()

        // When
        history.add(makeScoreRecord(value: 80))
        history.add(makeScoreRecord(value: 70))
        history.add(makeScoreRecord(value: 60))

        // Then
        #expect(history.recordCount == 3)
    }

    // MARK: - Average Score Tests

    @Test func averageScoreWithNoRecordsReturnsNil() {
        // Given
        let history = ScoreHistory()

        // When
        let average = history.averageScore(within: 300)

        // Then
        #expect(average == nil)
    }

    @Test func averageScoreWithSingleRecordReturnsThatValue() {
        // Given
        let history = ScoreHistory()
        history.add(makeScoreRecord(value: 75))

        // When
        let average = history.averageScore(within: 300)

        // Then
        #expect(average == 75.0)
    }

    @Test func averageScoreCalculatesCorrectly() {
        // Given
        let history = ScoreHistory()
        history.add(makeScoreRecord(value: 60))
        history.add(makeScoreRecord(value: 80))
        history.add(makeScoreRecord(value: 70))

        // When
        let average = history.averageScore(within: 300)

        // Then
        #expect(average == 70.0)
    }

    @Test func averageScoreExcludesOldRecords() {
        // Given
        let history = ScoreHistory()
        let now = Date()
        let oldTimestamp = now.addingTimeInterval(-400) // 400秒前（評価期間外）
        let recentTimestamp = now.addingTimeInterval(-100) // 100秒前（評価期間内）

        history.add(makeScoreRecord(value: 20, timestamp: oldTimestamp))
        history.add(makeScoreRecord(value: 80, timestamp: recentTimestamp))

        // When
        let average = history.averageScore(within: 300) // 300秒以内

        // Then
        #expect(average == 80.0) // 古いレコードは除外される
    }

    // MARK: - Data Completeness Tests

    @Test func dataCompletenessWithNoRecordsReturnsZero() {
        // Given
        let history = ScoreHistory()

        // When
        let completeness = history.dataCompleteness(within: 60, expectedInterval: 1.0)

        // Then
        #expect(completeness == 0.0)
    }

    @Test func dataCompletenessWithFullDataReturnsOne() {
        // Given
        let history = ScoreHistory()
        let now = Date()

        // 60秒分のデータを追加（1秒間隔で60件）
        for i in 0 ..< 60 {
            let timestamp = now.addingTimeInterval(-Double(i))
            history.add(makeScoreRecord(value: 70, timestamp: timestamp))
        }

        // When
        let completeness = history.dataCompleteness(within: 60, expectedInterval: 1.0)

        // Then
        #expect(completeness == 1.0)
    }

    @Test func dataCompletenessWithHalfDataReturnsHalf() {
        // Given
        let history = ScoreHistory()
        let now = Date()

        // 30秒分のデータを追加（1秒間隔で30件、60秒期間の半分）
        for i in 0 ..< 30 {
            let timestamp = now.addingTimeInterval(-Double(i))
            history.add(makeScoreRecord(value: 70, timestamp: timestamp))
        }

        // When
        let completeness = history.dataCompleteness(within: 60, expectedInterval: 1.0)

        // Then
        #expect(completeness == 0.5)
    }

    @Test func dataCompletenessCapsAtOne() {
        // Given
        let history = ScoreHistory()
        let now = Date()

        // 期待値より多いデータを追加
        for i in 0 ..< 120 {
            let timestamp = now.addingTimeInterval(-Double(i) * 0.5) // 0.5秒間隔で120件
            history.add(makeScoreRecord(value: 70, timestamp: timestamp))
        }

        // When
        let completeness = history.dataCompleteness(within: 60, expectedInterval: 1.0)

        // Then
        #expect(completeness == 1.0) // 1.0を超えない
    }

    // MARK: - Pruning Tests

    @Test func oldRecordsArePruned() {
        // Given
        let history = ScoreHistory()
        let now = Date()
        let veryOldTimestamp = now.addingTimeInterval(-700) // 700秒前（最大保持期間を超過）

        history.add(makeScoreRecord(value: 50, timestamp: veryOldTimestamp))
        history.add(makeScoreRecord(value: 80, timestamp: now))

        // When: 内部でpruneが実行される
        // Then: 古いレコードは削除され、新しいレコードのみ残る
        #expect(history.recordCount == 1)
        #expect(history.averageScore(within: 300) == 80.0)
    }

    // MARK: - Clear Tests

    @Test func clearRemovesAllRecords() {
        // Given
        let history = ScoreHistory()
        history.add(makeScoreRecord(value: 70))
        history.add(makeScoreRecord(value: 80))
        #expect(history.recordCount == 2)

        // When
        history.clear()

        // Then
        #expect(history.recordCount == 0)
        #expect(history.averageScore(within: 300) == nil)
    }
}
