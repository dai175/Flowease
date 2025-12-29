import Combine
import Foundation

/// 休憩リマインダーサービスプロトコル
public protocol BreakReminderServiceProtocol: AnyObject {

    // MARK: - Properties

    /// 現在の休憩リマインダー状態
    var reminder: CurrentValueSubject<BreakReminder, Never> { get }

    /// 次の休憩までの残り時間（秒）
    var timeUntilNextBreak: CurrentValueSubject<TimeInterval?, Never> { get }

    /// リマインダーが動作中か
    var isRunning: Bool { get }

    // MARK: - Methods

    /// リマインダーを開始
    func start()

    /// リマインダーを停止
    func stop()

    /// 休憩を記録
    func recordBreak()

    /// スヌーズ（5分後に再通知）
    func snooze()

    /// 休憩間隔を更新
    /// - Parameter minutes: 新しい間隔（分）
    func updateInterval(minutes: Int)
}
