import Foundation

/// ユーザー設定モデル
public struct UserSettings: Codable, Sendable {
    /// 選択されたカメラのデバイスID
    public var selectedCameraID: String?

    /// 休憩リマインダー間隔（分）
    public var breakIntervalMinutes: Int

    /// 姿勢判定の感度（0.0〜1.0、高いほど厳しい）
    public var postureSensitivity: Double

    /// 通知が有効か
    public var notificationsEnabled: Bool

    /// 姿勢モニタリングが有効か
    public var postureMonitoringEnabled: Bool

    /// 前かがみ警告の閾値（度）
    public var forwardLeanThreshold: Double

    /// 首傾き警告の閾値（度）
    public var neckTiltThreshold: Double

    /// 悪い姿勢の警告までの時間（秒）
    public var badPostureAlertDelay: TimeInterval

    public init(
        selectedCameraID: String? = nil,
        breakIntervalMinutes: Int = Constants.BreakReminder.defaultIntervalMinutes,
        postureSensitivity: Double = Constants.PostureDetection.defaultSensitivity,
        notificationsEnabled: Bool = true,
        postureMonitoringEnabled: Bool = true,
        forwardLeanThreshold: Double = Constants.PostureDetection.defaultForwardLeanThreshold,
        neckTiltThreshold: Double = Constants.PostureDetection.defaultNeckTiltThreshold,
        badPostureAlertDelay: TimeInterval = Constants.PostureDetection.badPostureAlertDelay
    ) {
        self.selectedCameraID = selectedCameraID
        self.breakIntervalMinutes = max(
            Constants.BreakReminder.minimumIntervalMinutes,
            min(Constants.BreakReminder.maximumIntervalMinutes, breakIntervalMinutes)
        )
        self.postureSensitivity = max(0.0, min(1.0, postureSensitivity))
        self.notificationsEnabled = notificationsEnabled
        self.postureMonitoringEnabled = postureMonitoringEnabled
        self.forwardLeanThreshold = max(5.0, min(30.0, forwardLeanThreshold))
        self.neckTiltThreshold = max(10.0, min(40.0, neckTiltThreshold))
        self.badPostureAlertDelay = max(3.0, min(10.0, badPostureAlertDelay))
    }
}

// MARK: - Default Values

extension UserSettings {
    /// デフォルト設定
    public static let `default` = UserSettings(
        selectedCameraID: nil,
        breakIntervalMinutes: Constants.BreakReminder.defaultIntervalMinutes,
        postureSensitivity: Constants.PostureDetection.defaultSensitivity,
        notificationsEnabled: true,
        postureMonitoringEnabled: true,
        forwardLeanThreshold: Constants.PostureDetection.defaultForwardLeanThreshold,
        neckTiltThreshold: Constants.PostureDetection.defaultNeckTiltThreshold,
        badPostureAlertDelay: Constants.PostureDetection.badPostureAlertDelay
    )
}

// MARK: - Validation

extension UserSettings {
    /// 設定が有効かどうか
    public var isValid: Bool {
        return breakIntervalMinutes >= Constants.BreakReminder.minimumIntervalMinutes
            && breakIntervalMinutes <= Constants.BreakReminder.maximumIntervalMinutes
            && postureSensitivity >= 0.0
            && postureSensitivity <= 1.0
            && forwardLeanThreshold >= 5.0
            && forwardLeanThreshold <= 30.0
            && neckTiltThreshold >= 10.0
            && neckTiltThreshold <= 40.0
            && badPostureAlertDelay >= 3.0
            && badPostureAlertDelay <= 10.0
    }
}
