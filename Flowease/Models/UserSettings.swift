import Foundation

/// ユーザー設定モデル
public struct UserSettings: Codable, Sendable, Equatable {
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
        self.postureSensitivity = max(
            Constants.PostureDetection.minimumSensitivity,
            min(Constants.PostureDetection.maximumSensitivity, postureSensitivity)
        )
        self.notificationsEnabled = notificationsEnabled
        self.postureMonitoringEnabled = postureMonitoringEnabled
        self.forwardLeanThreshold = max(
            Constants.PostureDetection.minimumForwardLeanThreshold,
            min(Constants.PostureDetection.maximumForwardLeanThreshold, forwardLeanThreshold)
        )
        self.neckTiltThreshold = max(
            Constants.PostureDetection.minimumNeckTiltThreshold,
            min(Constants.PostureDetection.maximumNeckTiltThreshold, neckTiltThreshold)
        )
        self.badPostureAlertDelay = max(
            Constants.PostureDetection.minimumBadPostureAlertDelay,
            min(Constants.PostureDetection.maximumBadPostureAlertDelay, badPostureAlertDelay)
        )
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let selectedCameraID = try container.decodeIfPresent(String.self, forKey: .selectedCameraID)
        let breakIntervalMinutes = try container.decode(Int.self, forKey: .breakIntervalMinutes)
        let postureSensitivity = try container.decode(Double.self, forKey: .postureSensitivity)
        let notificationsEnabled = try container.decode(Bool.self, forKey: .notificationsEnabled)
        let postureMonitoringEnabled = try container.decode(Bool.self, forKey: .postureMonitoringEnabled)
        let forwardLeanThreshold = try container.decode(Double.self, forKey: .forwardLeanThreshold)
        let neckTiltThreshold = try container.decode(Double.self, forKey: .neckTiltThreshold)
        let badPostureAlertDelay = try container.decode(TimeInterval.self, forKey: .badPostureAlertDelay)

        self.init(
            selectedCameraID: selectedCameraID,
            breakIntervalMinutes: breakIntervalMinutes,
            postureSensitivity: postureSensitivity,
            notificationsEnabled: notificationsEnabled,
            postureMonitoringEnabled: postureMonitoringEnabled,
            forwardLeanThreshold: forwardLeanThreshold,
            neckTiltThreshold: neckTiltThreshold,
            badPostureAlertDelay: badPostureAlertDelay
        )
    }

    private enum CodingKeys: String, CodingKey {
        case selectedCameraID
        case breakIntervalMinutes
        case postureSensitivity
        case notificationsEnabled
        case postureMonitoringEnabled
        case forwardLeanThreshold
        case neckTiltThreshold
        case badPostureAlertDelay
    }
}

// MARK: - Default Values

public extension UserSettings {
    /// デフォルト設定
    static let `default` = UserSettings(
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

public extension UserSettings {
    /// 設定が有効かどうか
    var isValid: Bool {
        breakIntervalMinutes >= Constants.BreakReminder.minimumIntervalMinutes
            && breakIntervalMinutes <= Constants.BreakReminder.maximumIntervalMinutes
            && postureSensitivity >= Constants.PostureDetection.minimumSensitivity
            && postureSensitivity <= Constants.PostureDetection.maximumSensitivity
            && forwardLeanThreshold >= Constants.PostureDetection.minimumForwardLeanThreshold
            && forwardLeanThreshold <= Constants.PostureDetection.maximumForwardLeanThreshold
            && neckTiltThreshold >= Constants.PostureDetection.minimumNeckTiltThreshold
            && neckTiltThreshold <= Constants.PostureDetection.maximumNeckTiltThreshold
            && badPostureAlertDelay >= Constants.PostureDetection.minimumBadPostureAlertDelay
            && badPostureAlertDelay <= Constants.PostureDetection.maximumBadPostureAlertDelay
    }
}
