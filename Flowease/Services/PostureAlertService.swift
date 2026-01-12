import Foundation
import OSLog
import UserNotifications

// MARK: - PostureAlertService

/// 姿勢アラート通知サービス
///
/// スコア履歴を監視し、悪い姿勢が一定期間続いた場合に通知を送信する。
///
/// ## 通知判定アルゴリズム
/// 1. 評価期間内のデータ充足率をチェック（50%以上必要）
/// 2. 平均スコアを計算
/// 3. 平均スコアが閾値以下かつ通知可能な状態であれば通知送信
///
/// ## 再通知条件
/// - 姿勢が一度改善された後に再度悪化した場合
/// - または、最短通知間隔が経過した場合（リマインド）
@MainActor
final class PostureAlertService {
    private let logger = Logger.postureAlertService

    // MARK: - Dependencies

    private let scoreHistory: ScoreHistory
    private let notificationManager: NotificationManagerProtocol

    // MARK: - State

    /// 現在の通知設定（読み取り専用）
    private(set) var settings: AlertSettings
    private var state: AlertState = .initial

    /// データ充足率の最小要件（50%）
    private let minimumDataCompleteness: Double = 0.5

    // MARK: - Initialization

    /// PostureAlertServiceを初期化する
    ///
    /// - Parameters:
    ///   - scoreHistory: スコア履歴管理
    ///   - settings: 通知設定
    ///   - notificationManager: 通知送信マネージャー
    init(
        scoreHistory: ScoreHistory,
        settings: AlertSettings,
        notificationManager: NotificationManagerProtocol
    ) {
        self.scoreHistory = scoreHistory
        self.settings = settings
        self.notificationManager = notificationManager
        logger.debug("PostureAlertService initialized with threshold: \(settings.threshold)")
    }

    // MARK: - Public Methods

    /// 設定を更新する
    ///
    /// - Parameter newSettings: 新しい設定
    func updateSettings(_ newSettings: AlertSettings) {
        settings = newSettings
        logger.debug("Settings updated: threshold=\(newSettings.threshold), enabled=\(newSettings.isEnabled)")
    }

    /// 現在の設定を取得する
    var currentSettings: AlertSettings {
        settings
    }

    /// 通知状態をリセットする
    ///
    /// 監視停止・一時停止時に呼び出し、再開時にクリーンな状態から始める。
    /// スコア履歴もクリアされる。
    func reset() {
        state = .initial
        scoreHistory.clear()
        logger.debug("Alert service reset: state and history cleared")
    }

    /// 姿勢評価を実行し、必要に応じて通知を送信する
    ///
    /// スコア更新のたびに呼び出される。
    func evaluate() async {
        // 通知が無効の場合はスキップ
        guard settings.isEnabled else {
            logger.debug("Evaluation skipped: alerts disabled")
            return
        }

        // データ充足率をチェック
        let completeness = scoreHistory.dataCompleteness(
            within: settings.evaluationPeriodSeconds,
            expectedInterval: 1.0
        )
        guard completeness >= minimumDataCompleteness else {
            logger.debug("Evaluation skipped: insufficient data (\(Int(completeness * 100))%)")
            return
        }

        // 平均スコアを計算
        guard let averageScore = scoreHistory.averageScore(within: settings.evaluationPeriodSeconds) else {
            logger.debug("Evaluation skipped: no score data")
            return
        }

        logger.debug("Evaluating: average=\(Int(averageScore)), threshold=\(self.settings.threshold)")

        // 姿勢が良好かどうかを判定
        let isPostureGood = averageScore > Double(settings.threshold)

        if isPostureGood {
            // 姿勢が改善された
            if !state.hasImprovedSinceLastNotification {
                state.hasImprovedSinceLastNotification = true
                logger.info("Posture improved, notification state reset")
            }
            return
        }

        // 姿勢が悪い - 通知可能かチェック
        if canSendNotification() {
            await sendNotification()
        }
    }

    // MARK: - Private Methods

    /// 通知送信可能かどうかを判定する
    ///
    /// - Returns: 通知送信可能な場合はtrue
    private func canSendNotification() -> Bool {
        // 初回または姿勢改善後は通知可能
        if state.hasImprovedSinceLastNotification {
            return true
        }

        // 最短間隔が経過していれば通知可能（リマインド）
        if let lastTime = state.lastNotificationTime {
            let elapsed = Date().timeIntervalSince(lastTime)
            if elapsed >= Double(settings.minimumIntervalSeconds) {
                logger.debug("Minimum interval elapsed (\(Int(elapsed))s), can send reminder")
                return true
            }
        }

        return false
    }

    /// 通知を送信し、状態を更新する
    ///
    /// 通知権限が未許可の場合は先に権限をリクエストする。
    private func sendNotification() async {
        // 通知権限をチェックし、必要ならリクエスト
        let status = await notificationManager.getAuthorizationStatus()
        if status == .notDetermined {
            logger.info("Requesting notification authorization...")
            let granted = await notificationManager.requestAuthorization()
            if !granted {
                logger.info("Notification authorization denied, skipping notification")
                return
            }
        } else if status != .authorized {
            logger.debug("Notification not authorized (status: \(status.rawValue)), skipping")
            return
        }

        await notificationManager.sendPostureAlert()

        state.lastNotificationTime = Date()
        state.hasImprovedSinceLastNotification = false

        logger.info("Posture alert notification sent")
    }

    // MARK: - Testing Support

    #if DEBUG
        /// テスト用: 最後の通知時刻を設定する
        func setLastNotificationTimeForTesting(_ date: Date?) {
            state.lastNotificationTime = date
            state.hasImprovedSinceLastNotification = false
        }

        /// テスト用: 現在の状態を取得する
        var currentStateForTesting: AlertState {
            state
        }
    #endif
}
