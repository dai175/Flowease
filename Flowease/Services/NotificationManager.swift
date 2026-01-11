import Foundation
import OSLog
import UserNotifications

// MARK: - NotificationManagerProtocol

/// 通知マネージャープロトコル
protocol NotificationManagerProtocol: Sendable {
    /// 通知権限をリクエストする
    /// - Returns: 権限が許可された場合はtrue
    func requestAuthorization() async -> Bool

    /// 現在の通知権限ステータスを取得する
    func getAuthorizationStatus() async -> UNAuthorizationStatus

    /// 姿勢アラート通知を送信する
    func sendPostureAlert() async
}

// MARK: - NotificationManager

/// macOS通知の管理
///
/// UNUserNotificationCenterを使用してローカル通知を管理する。
/// 権限リクエストと通知送信を担当。
final class NotificationManager: NotificationManagerProtocol, Sendable {
    private let logger = Logger(subsystem: "cc.focuswave.Flowease", category: "NotificationManager")
    private let notificationCenter: UNUserNotificationCenter

    /// 姿勢アラート通知の固定識別子（新しい通知が古い通知を置き換える）
    private static let postureAlertIdentifier = "cc.focuswave.Flowease.postureAlert"

    init(notificationCenter: UNUserNotificationCenter = .current()) {
        self.notificationCenter = notificationCenter
        logger.debug("NotificationManager initialized")
    }

    /// 通知権限をリクエストする
    ///
    /// ユーザーに通知権限を要求し、結果を返す。
    ///
    /// - Returns: 権限が許可された場合はtrue
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound])
            logger.info("Notification authorization \(granted ? "granted" : "denied")")
            return granted
        } catch {
            logger.error("Failed to request notification authorization: \(error.localizedDescription)")
            return false
        }
    }

    /// 現在の通知権限ステータスを取得する
    ///
    /// - Returns: 現在の権限ステータス
    func getAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await notificationCenter.notificationSettings()
        logger.debug("Authorization status: \(String(describing: settings.authorizationStatus.rawValue))")
        return settings.authorizationStatus
    }

    /// 姿勢アラート通知を送信する
    ///
    /// 姿勢が悪い状態が続いていることをユーザーに通知する。
    func sendPostureAlert() async {
        // 権限チェック
        let status = await getAuthorizationStatus()
        guard status == .authorized else {
            logger.debug("Cannot send notification: not authorized (status: \(status.rawValue))")
            return
        }

        // 通知コンテンツの作成
        let content = UNMutableNotificationContent()
        content.title = String(localized: "alert.title")
        content.body = String(localized: "alert.body")
        content.sound = .default

        // 即時配信のリクエストを作成（固定識別子で前の通知を置き換える）
        let request = UNNotificationRequest(
            identifier: Self.postureAlertIdentifier,
            content: content,
            trigger: nil // nilで即時配信
        )

        do {
            try await notificationCenter.add(request)
            logger.info("Posture alert notification sent")
        } catch {
            logger.error("Failed to send posture alert notification: \(error.localizedDescription)")
        }
    }
}
