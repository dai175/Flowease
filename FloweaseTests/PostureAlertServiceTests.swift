import Foundation
import Testing
import UserNotifications

@testable import Flowease

// MARK: - Mock NotificationManager

/// テスト用のNotificationManagerモック
final class MockNotificationManager: NotificationManagerProtocol, @unchecked Sendable {
    private(set) var sendPostureAlertCallCount = 0
    private(set) var requestAuthorizationCallCount = 0
    var authorizationStatus: UNAuthorizationStatus = .authorized

    func requestAuthorization() async -> Bool {
        requestAuthorizationCallCount += 1
        return authorizationStatus == .authorized
    }

    func getAuthorizationStatus() async -> UNAuthorizationStatus {
        authorizationStatus
    }

    func sendPostureAlert() async {
        sendPostureAlertCallCount += 1
    }

    func reset() {
        sendPostureAlertCallCount = 0
        requestAuthorizationCallCount = 0
    }
}

// MARK: - PostureAlertServiceTests

/// PostureAlertServiceのテスト
@MainActor
struct PostureAlertServiceTests {
    // MARK: - Test Helpers

    private func makeScoreRecord(value: Int, timestamp: Date = Date()) -> ScoreRecord {
        ScoreRecord(value: value, timestamp: timestamp)
    }

    private func makeService(
        settings: AlertSettings = .default,
        notificationManager: MockNotificationManager = MockNotificationManager()
    ) -> (PostureAlertService, ScoreHistory, MockNotificationManager) {
        let history = ScoreHistory()
        let service = PostureAlertService(
            scoreHistory: history,
            settings: settings,
            notificationManager: notificationManager
        )
        return (service, history, notificationManager)
    }

    /// 十分なデータを追加するヘルパー（データ充足率50%以上）
    private func addSufficientData(
        to history: ScoreHistory,
        value: Int,
        count: Int,
        evaluationPeriodSeconds: Int
    ) {
        let now = Date()
        let interval = Double(evaluationPeriodSeconds) / Double(count)
        for i in 0 ..< count {
            let timestamp = now.addingTimeInterval(-Double(i) * interval)
            history.add(makeScoreRecord(value: value, timestamp: timestamp))
        }
    }

    // MARK: - Notification Trigger Tests

    @Test func notificationTriggeredWhenAverageScoreBelowThreshold() async {
        // Given: 閾値60、平均スコア50のデータ
        let settings = AlertSettings(
            isEnabled: true,
            threshold: 60,
            evaluationPeriodSeconds: 60,
            minimumIntervalSeconds: 300
        )
        let mockNotification = MockNotificationManager()
        let (service, history, _) = makeService(settings: settings, notificationManager: mockNotification)

        // 十分なデータを追加（50%以上の充足率）
        addSufficientData(to: history, value: 50, count: 35, evaluationPeriodSeconds: 60)

        // When
        await service.evaluate()

        // Then
        #expect(mockNotification.sendPostureAlertCallCount == 1)
    }

    @Test func notificationNotTriggeredWhenAverageScoreAboveThreshold() async {
        // Given: 閾値60、平均スコア70のデータ
        let settings = AlertSettings(
            isEnabled: true,
            threshold: 60,
            evaluationPeriodSeconds: 60,
            minimumIntervalSeconds: 300
        )
        let mockNotification = MockNotificationManager()
        let (service, history, _) = makeService(settings: settings, notificationManager: mockNotification)

        // 十分なデータを追加
        addSufficientData(to: history, value: 70, count: 35, evaluationPeriodSeconds: 60)

        // When
        await service.evaluate()

        // Then
        #expect(mockNotification.sendPostureAlertCallCount == 0)
    }

    @Test func notificationNotTriggeredWhenDisabled() async {
        // Given: 通知無効
        let settings = AlertSettings(
            isEnabled: false,
            threshold: 60,
            evaluationPeriodSeconds: 60,
            minimumIntervalSeconds: 300
        )
        let mockNotification = MockNotificationManager()
        let (service, history, _) = makeService(settings: settings, notificationManager: mockNotification)

        // 悪いスコアのデータを追加
        addSufficientData(to: history, value: 50, count: 35, evaluationPeriodSeconds: 60)

        // When
        await service.evaluate()

        // Then
        #expect(mockNotification.sendPostureAlertCallCount == 0)
    }

    // MARK: - State Reset Tests

    @Test func stateResetWhenPostureImproves() async {
        // Given: 最初に悪い姿勢で通知
        let settings = AlertSettings(
            isEnabled: true,
            threshold: 60,
            evaluationPeriodSeconds: 60,
            minimumIntervalSeconds: 300
        )
        let mockNotification = MockNotificationManager()
        let (service, history, _) = makeService(settings: settings, notificationManager: mockNotification)

        // 悪いスコアで通知をトリガー
        addSufficientData(to: history, value: 50, count: 35, evaluationPeriodSeconds: 60)
        await service.evaluate()
        #expect(mockNotification.sendPostureAlertCallCount == 1)

        // When: 姿勢が改善される（履歴をクリアして良いスコアを追加）
        history.clear()
        addSufficientData(to: history, value: 70, count: 35, evaluationPeriodSeconds: 60)
        await service.evaluate()

        // Then: 通知は追加されない（姿勢が良いため）
        #expect(mockNotification.sendPostureAlertCallCount == 1)

        // When: 再度姿勢が悪化
        history.clear()
        addSufficientData(to: history, value: 50, count: 35, evaluationPeriodSeconds: 60)
        await service.evaluate()

        // Then: 姿勢改善後の悪化なので再通知される
        #expect(mockNotification.sendPostureAlertCallCount == 2)
    }

    // MARK: - Minimum Interval Tests

    @Test func noRenotificationWithinMinimumInterval() async {
        // Given: 最短間隔300秒
        let settings = AlertSettings(
            isEnabled: true,
            threshold: 60,
            evaluationPeriodSeconds: 60,
            minimumIntervalSeconds: 300
        )
        let mockNotification = MockNotificationManager()
        let (service, history, _) = makeService(settings: settings, notificationManager: mockNotification)

        // 悪いスコアで通知をトリガー
        addSufficientData(to: history, value: 50, count: 35, evaluationPeriodSeconds: 60)
        await service.evaluate()
        #expect(mockNotification.sendPostureAlertCallCount == 1)

        // When: 姿勢改善なしで再度評価（最短間隔内）
        await service.evaluate()

        // Then: 再通知されない
        #expect(mockNotification.sendPostureAlertCallCount == 1)
    }

    @Test func renotificationAfterMinimumIntervalWithoutImprovement() async {
        // Given: 最短間隔を短く設定してテスト
        let settings = AlertSettings(
            isEnabled: true,
            threshold: 60,
            evaluationPeriodSeconds: 60,
            minimumIntervalSeconds: 300 // 5分
        )
        let mockNotification = MockNotificationManager()
        let history = ScoreHistory()
        let service = PostureAlertService(
            scoreHistory: history,
            settings: settings,
            notificationManager: mockNotification
        )

        // 悪いスコアで通知をトリガー
        addSufficientData(to: history, value: 50, count: 35, evaluationPeriodSeconds: 60)
        await service.evaluate()
        #expect(mockNotification.sendPostureAlertCallCount == 1)

        // When: 通知状態を手動で過去に設定（最短間隔経過をシミュレート）
        service.setLastNotificationTimeForTesting(Date().addingTimeInterval(-400))

        await service.evaluate()

        // Then: 最短間隔経過後は再通知される
        #expect(mockNotification.sendPostureAlertCallCount == 2)
    }

    // MARK: - Data Completeness Tests

    @Test func notificationSkippedWhenDataCompletenessBelow50Percent() async {
        // Given: データ充足率50%未満
        let settings = AlertSettings(
            isEnabled: true,
            threshold: 60,
            evaluationPeriodSeconds: 60,
            minimumIntervalSeconds: 300
        )
        let mockNotification = MockNotificationManager()
        let (service, history, _) = makeService(settings: settings, notificationManager: mockNotification)

        // 少ないデータを追加（50%未満）
        let now = Date()
        for i in 0 ..< 20 { // 60秒期間に対して20件のみ（約33%）
            let timestamp = now.addingTimeInterval(-Double(i) * 3)
            history.add(makeScoreRecord(value: 50, timestamp: timestamp))
        }

        // When
        await service.evaluate()

        // Then: データ不足のため通知されない
        #expect(mockNotification.sendPostureAlertCallCount == 0)
    }

    @Test func notificationTriggeredWhenDataCompletenessAtLeast50Percent() async {
        // Given: データ充足率ちょうど50%
        let settings = AlertSettings(
            isEnabled: true,
            threshold: 60,
            evaluationPeriodSeconds: 60,
            minimumIntervalSeconds: 300
        )
        let mockNotification = MockNotificationManager()
        let (service, history, _) = makeService(settings: settings, notificationManager: mockNotification)

        // 50%のデータを追加
        let now = Date()
        for i in 0 ..< 30 { // 60秒期間に対して30件（50%）
            let timestamp = now.addingTimeInterval(-Double(i) * 2)
            history.add(makeScoreRecord(value: 50, timestamp: timestamp))
        }

        // When
        await service.evaluate()

        // Then: 50%以上なので通知される
        #expect(mockNotification.sendPostureAlertCallCount == 1)
    }

    // MARK: - Settings Update Tests

    @Test func settingsUpdateAffectsEvaluation() async {
        // Given: 初期閾値60
        var settings = AlertSettings(
            isEnabled: true,
            threshold: 60,
            evaluationPeriodSeconds: 60,
            minimumIntervalSeconds: 300
        )
        let mockNotification = MockNotificationManager()
        let history = ScoreHistory()
        let service = PostureAlertService(
            scoreHistory: history,
            settings: settings,
            notificationManager: mockNotification
        )

        // スコア55のデータを追加（閾値60以下なので通知対象）
        addSufficientData(to: history, value: 55, count: 35, evaluationPeriodSeconds: 60)
        await service.evaluate()
        #expect(mockNotification.sendPostureAlertCallCount == 1)

        // When: 閾値を50に変更
        settings.threshold = 50
        service.updateSettings(settings)

        // 履歴クリアして同じスコアで再評価
        history.clear()
        mockNotification.reset()
        addSufficientData(to: history, value: 55, count: 35, evaluationPeriodSeconds: 60)
        await service.evaluate()

        // Then: 新しい閾値50より上なので通知されない
        #expect(mockNotification.sendPostureAlertCallCount == 0)
    }

    // MARK: - Edge Cases

    @Test func noNotificationWhenHistoryIsEmpty() async {
        // Given: 空の履歴
        let settings = AlertSettings.default
        let mockNotification = MockNotificationManager()
        let (service, _, _) = makeService(settings: settings, notificationManager: mockNotification)

        // When
        await service.evaluate()

        // Then
        #expect(mockNotification.sendPostureAlertCallCount == 0)
    }

    @Test func notificationAtExactThreshold() async {
        // Given: スコアがちょうど閾値と同じ
        let settings = AlertSettings(
            isEnabled: true,
            threshold: 60,
            evaluationPeriodSeconds: 60,
            minimumIntervalSeconds: 300
        )
        let mockNotification = MockNotificationManager()
        let (service, history, _) = makeService(settings: settings, notificationManager: mockNotification)

        // ちょうど閾値60のデータ
        addSufficientData(to: history, value: 60, count: 35, evaluationPeriodSeconds: 60)

        // When
        await service.evaluate()

        // Then: 閾値「以下」なので通知される
        #expect(mockNotification.sendPostureAlertCallCount == 1)
    }

    // MARK: - Reset Tests

    @Test func resetClearsHistoryAndState() async {
        // Given: 通知が送信された状態
        let settings = AlertSettings(
            isEnabled: true,
            threshold: 60,
            evaluationPeriodSeconds: 60,
            minimumIntervalSeconds: 300
        )
        let mockNotification = MockNotificationManager()
        let (service, history, _) = makeService(settings: settings, notificationManager: mockNotification)

        // 悪いスコアで通知をトリガー
        addSufficientData(to: history, value: 50, count: 35, evaluationPeriodSeconds: 60)
        await service.evaluate()
        #expect(mockNotification.sendPostureAlertCallCount == 1)

        // When: リセットを実行
        service.reset()

        // Then: 履歴がクリアされている
        #expect(history.recordCount == 0)
        #expect(history.averageScore(within: 60) == nil)

        // And: 状態がリセットされている（再度データを追加して通知が発火することを確認）
        addSufficientData(to: history, value: 50, count: 35, evaluationPeriodSeconds: 60)
        await service.evaluate()

        // リセット後は初期状態なので、新しいデータで通知が発火する
        #expect(mockNotification.sendPostureAlertCallCount == 2)
    }

    @Test func resetPreventsNotificationFromOldData() async {
        // Given: 監視停止前に悪いスコアがあった状態をシミュレート
        let settings = AlertSettings(
            isEnabled: true,
            threshold: 60,
            evaluationPeriodSeconds: 60,
            minimumIntervalSeconds: 300
        )
        let mockNotification = MockNotificationManager()
        let (service, history, _) = makeService(settings: settings, notificationManager: mockNotification)

        // 停止前の悪いスコアデータ
        addSufficientData(to: history, value: 50, count: 35, evaluationPeriodSeconds: 60)

        // When: 監視停止時にリセット（clearScoreHistoryの動作をシミュレート）
        service.reset()

        // Then: 再開後、古いデータがないので通知されない
        await service.evaluate()
        #expect(mockNotification.sendPostureAlertCallCount == 0)

        // And: 新しい良いスコアを追加しても通知されない
        addSufficientData(to: history, value: 70, count: 35, evaluationPeriodSeconds: 60)
        await service.evaluate()
        #expect(mockNotification.sendPostureAlertCallCount == 0)
    }
}
