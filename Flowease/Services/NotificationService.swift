//
//  NotificationService.swift
//  Flowease
//
//  Created by Daisuke Ooba on 2025/12/29.
//

import Foundation
import UserNotifications

/// 通知サービスの実装
/// UserNotifications を使用して姿勢警告と休憩リマインダーの通知を送信する
public final class NotificationService: NSObject, NotificationServiceProtocol {
    // MARK: - Properties

    /// 通知が許可されているか
    public var isAuthorized: Bool {
        get async {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            return settings.authorizationStatus == .authorized
        }
    }

    // MARK: - Private Properties

    /// 通知センター
    private let notificationCenter = UNUserNotificationCenter.current()

    /// 最後に姿勢警告を送信した時刻
    private var lastPostureAlertTime: Date?

    /// 姿勢警告の最小間隔（秒）
    private let postureAlertMinInterval: TimeInterval = 30

    // MARK: - Initialization

    override public init() {
        super.init()
        setupNotificationCategories()
        notificationCenter.delegate = self
    }

    // MARK: - NotificationServiceProtocol

    /// 通知権限をリクエスト
    /// - Returns: 許可されたか
    public func requestAuthorization() async throws -> Bool {
        do {
            let options: UNAuthorizationOptions = [.alert, .sound, .badge]
            let granted = try await notificationCenter.requestAuthorization(options: options)
            return granted
        } catch {
            throw AuthorizationError.systemError(error)
        }
    }

    /// 姿勢警告通知を送信
    /// - Parameter postureState: 現在の姿勢状態
    public func sendPostureAlert(postureState: PostureState) async throws {
        // 権限チェック
        guard await isAuthorized else {
            throw NotificationError.notAuthorized
        }

        // 連続通知を防ぐ
        if let lastTime = lastPostureAlertTime,
           Date().timeIntervalSince(lastTime) < postureAlertMinInterval
        {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "姿勢を正してください"
        content.body = createPostureAlertBody(for: postureState)
        content.sound = .default
        content.categoryIdentifier = Constants.NotificationIdentifiers.Category.postureAlert

        let request = UNNotificationRequest(
            identifier: "posture-alert-\(UUID().uuidString)",
            content: content,
            trigger: nil // 即時配信
        )

        do {
            try await notificationCenter.add(request)
            lastPostureAlertTime = Date()
        } catch {
            throw NotificationError.deliveryFailed(error)
        }
    }

    /// 休憩リマインダー通知を送信
    public func sendBreakReminder() async throws {
        // 権限チェック
        guard await isAuthorized else {
            throw NotificationError.notAuthorized
        }

        let content = UNMutableNotificationContent()
        content.title = "休憩の時間です"
        content.body = "長時間の作業お疲れ様です。少し休憩してストレッチをしましょう。"
        content.sound = .default
        content.categoryIdentifier = Constants.NotificationIdentifiers.Category.breakReminder

        let request = UNNotificationRequest(
            identifier: "break-reminder-\(UUID().uuidString)",
            content: content,
            trigger: nil // 即時配信
        )

        do {
            try await notificationCenter.add(request)
        } catch {
            throw NotificationError.deliveryFailed(error)
        }
    }

    /// スヌーズ通知をスケジュール
    /// - Parameter delay: 遅延時間（秒）
    public func scheduleSnoozeReminder(delay: TimeInterval) async throws {
        // 権限チェック
        guard await isAuthorized else {
            throw NotificationError.notAuthorized
        }

        let content = UNMutableNotificationContent()
        content.title = "休憩の時間です"
        content.body = "スヌーズ時間が経過しました。休憩してストレッチをしましょう。"
        content.sound = .default
        content.categoryIdentifier = Constants.NotificationIdentifiers.Category.breakReminder

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: delay,
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "snooze-reminder-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
        } catch {
            throw NotificationError.deliveryFailed(error)
        }
    }

    /// 保留中の通知をキャンセル
    /// - Parameter identifier: 通知の識別子（nilの場合は全てキャンセル）
    public func cancelNotification(identifier: String?) {
        if let identifier = identifier {
            notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
            notificationCenter.removeDeliveredNotifications(withIdentifiers: [identifier])
        } else {
            notificationCenter.removeAllPendingNotificationRequests()
            notificationCenter.removeAllDeliveredNotifications()
        }
    }

    /// 通知カテゴリとアクションを設定
    public func setupNotificationCategories() {
        // 姿勢警告カテゴリ（アクションなし）
        let postureAlertCategory = UNNotificationCategory(
            identifier: Constants.NotificationIdentifiers.Category.postureAlert,
            actions: [],
            intentIdentifiers: [],
            options: []
        )

        // 休憩リマインダーアクション
        let startStretchAction = UNNotificationAction(
            identifier: Constants.NotificationIdentifiers.Action.startStretch,
            title: "ストレッチを開始",
            options: [.foreground]
        )

        let snoozeAction = UNNotificationAction(
            identifier: Constants.NotificationIdentifiers.Action.snooze,
            title: "5分後にリマインド",
            options: []
        )

        let dismissAction = UNNotificationAction(
            identifier: Constants.NotificationIdentifiers.Action.dismiss,
            title: "閉じる",
            options: [.destructive]
        )

        // 休憩リマインダーカテゴリ
        let breakReminderCategory = UNNotificationCategory(
            identifier: Constants.NotificationIdentifiers.Category.breakReminder,
            actions: [startStretchAction, snoozeAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )

        notificationCenter.setNotificationCategories([
            postureAlertCategory,
            breakReminderCategory,
        ])
    }

    // MARK: - Private Methods

    /// 姿勢警告のメッセージ本文を作成
    private func createPostureAlertBody(for state: PostureState) -> String {
        var messages: [String] = []

        if state.forwardLeanAngle > Constants.PostureDetection.defaultForwardLeanThreshold {
            messages.append("前かがみになっています")
        }

        if state.neckTiltAngle > Constants.PostureDetection.defaultNeckTiltThreshold {
            messages.append("首が傾いています")
        }

        if messages.isEmpty {
            return "悪い姿勢が \(Int(state.badPostureDuration)) 秒続いています。"
        }

        return messages.joined(separator: "。") + "。姿勢を正しましょう。"
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {
    /// フォアグラウンドで通知を受信した場合の処理
    public func userNotificationCenter(
        _: UNUserNotificationCenter,
        willPresent _: UNNotification,
        withCompletionHandler completionHandler:
        @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // フォアグラウンドでも通知を表示
        completionHandler([.banner, .sound])
    }

    /// 通知のアクションが選択された場合の処理
    public func userNotificationCenter(
        _: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let actionIdentifier = response.actionIdentifier

        switch actionIdentifier {
        case Constants.NotificationIdentifiers.Action.startStretch:
            // ストレッチ開始アクション
            NotificationCenter.default.post(
                name: .startStretchFromNotification,
                object: nil
            )

        case Constants.NotificationIdentifiers.Action.snooze:
            // スヌーズアクション
            Task {
                try? await scheduleSnoozeReminder(
                    delay: Constants.BreakReminder.snoozeDelaySeconds
                )
            }

        case Constants.NotificationIdentifiers.Action.dismiss,
             UNNotificationDefaultActionIdentifier,
             UNNotificationDismissActionIdentifier:
            // 閉じる / デフォルトタップ / スワイプで閉じる
            break

        default:
            break
        }

        completionHandler()
    }
}

// MARK: - Notification Names

public extension Notification.Name {
    /// 通知からストレッチを開始
    static let startStretchFromNotification = Notification.Name(
        "cc.focuswave.Flowease.startStretchFromNotification"
    )
}
