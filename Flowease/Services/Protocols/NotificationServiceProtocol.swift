import Foundation

/// 通知サービスプロトコル
public protocol NotificationServiceProtocol: AnyObject {
    // MARK: - Properties

    /// 通知が許可されているか
    /// - Note: 非同期プロパティ。呼び出し側は `await` を使用してアクセスする必要があります。
    var isAuthorized: Bool { get async }

    // MARK: - Methods

    /// 通知権限をリクエスト
    /// - Returns: 許可されたか
    func requestAuthorization() async throws -> Bool

    /// 姿勢警告通知を送信
    /// - Parameter postureState: 現在の姿勢状態
    func sendPostureAlert(postureState: PostureState) async throws

    /// 休憩リマインダー通知を送信
    func sendBreakReminder() async throws

    /// スヌーズ通知をスケジュール
    /// - Parameter delay: 遅延時間（秒）
    func scheduleSnoozeReminder(delay: TimeInterval) async throws

    /// 保留中の通知をキャンセル
    /// - Parameter identifier: 通知の識別子（nilの場合は全てキャンセル）
    func cancelNotification(identifier: String?)

    /// 通知カテゴリとアクションを設定
    func setupNotificationCategories()
}
