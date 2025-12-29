import Foundation

/// 休憩リマインダーモデル
public struct BreakReminder: Codable, Sendable {
    /// 休憩間隔（分）
    public var intervalMinutes: Int

    /// 次回通知予定時刻
    public var nextReminderTime: Date?

    /// リマインダーが有効か
    public var isEnabled: Bool

    /// 最後に休憩した時刻
    public var lastBreakTime: Date?

    /// スヌーズ回数（現在のセッション）
    public var snoozeCount: Int

    public init(
        intervalMinutes: Int = Constants.BreakReminder.defaultIntervalMinutes,
        nextReminderTime: Date? = nil,
        isEnabled: Bool = true,
        lastBreakTime: Date? = nil,
        snoozeCount: Int = 0
    ) {
        self.intervalMinutes = max(
            Constants.BreakReminder.minimumIntervalMinutes,
            min(Constants.BreakReminder.maximumIntervalMinutes, intervalMinutes)
        )
        self.nextReminderTime = nextReminderTime
        self.isEnabled = isEnabled
        self.lastBreakTime = lastBreakTime
        self.snoozeCount = max(0, snoozeCount)
    }

    /// 次の休憩までの残り時間（秒）
    public var timeUntilNextBreak: TimeInterval? {
        guard let nextTime = nextReminderTime else { return nil }
        let remaining = nextTime.timeIntervalSinceNow
        return remaining > 0 ? remaining : nil
    }

    /// 次の休憩までの残り時間をフォーマット済みで返す
    public var formattedTimeUntilNextBreak: String? {
        guard let remaining = timeUntilNextBreak else { return nil }
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Default Values

extension BreakReminder {
    /// デフォルト設定
    public static let `default` = BreakReminder(
        intervalMinutes: Constants.BreakReminder.defaultIntervalMinutes,
        nextReminderTime: nil,
        isEnabled: true,
        lastBreakTime: nil,
        snoozeCount: 0
    )
}
