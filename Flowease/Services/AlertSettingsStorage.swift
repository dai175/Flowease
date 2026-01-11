import Foundation
import OSLog

// MARK: - AlertSettingsKeys

/// ストレージキーの定数
///
/// 既存のCalibrationStorageKeysパターンに準拠
enum AlertSettingsKeys {
    static let isEnabled = "flowease.alert.isEnabled"
    static let threshold = "flowease.alert.threshold"
    static let evaluationPeriod = "flowease.alert.evaluationPeriod"
    static let minimumInterval = "flowease.alert.minimumInterval"
}

// MARK: - AlertSettingsStorageProtocol

/// 通知設定ストレージプロトコル
protocol AlertSettingsStorageProtocol: Sendable {
    /// 設定を読み込む
    func load() -> AlertSettings

    /// 設定を保存する
    func save(_ settings: AlertSettings)

    /// 設定をデフォルトにリセットする
    func reset()
}

// MARK: - AlertSettingsStorage

/// 通知設定のUserDefaults永続化
///
/// CalibrationStorageパターンを踏襲し、スレッドセーフな実装を提供。
final class AlertSettingsStorage: AlertSettingsStorageProtocol, @unchecked Sendable {
    private let userDefaults: UserDefaults
    private let logger = Logger(subsystem: "cc.focuswave.Flowease", category: "AlertSettingsStorage")
    private let lock = NSLock()

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        logger.debug("AlertSettingsStorage initialized")
    }

    /// 設定を読み込む
    ///
    /// UserDefaultsから各設定値を読み込む。
    /// 値が存在しない場合はデフォルト値を使用。
    func load() -> AlertSettings {
        lock.lock()
        defer { lock.unlock() }

        // isEnabledの読み込み（存在しない場合はデフォルト）
        let isEnabled: Bool = if userDefaults.object(forKey: AlertSettingsKeys.isEnabled) != nil {
            userDefaults.bool(forKey: AlertSettingsKeys.isEnabled)
        } else {
            AlertSettings.default.isEnabled
        }

        // thresholdの読み込み（存在しない場合はデフォルト、範囲外はクランプ）
        let threshold: Int
        if userDefaults.object(forKey: AlertSettingsKeys.threshold) != nil {
            let rawValue = userDefaults.integer(forKey: AlertSettingsKeys.threshold)
            threshold = Self.clamp(rawValue, to: AlertSettings.thresholdRange)
        } else {
            threshold = AlertSettings.default.threshold
        }

        // evaluationPeriodの読み込み（存在しない場合はデフォルト、範囲外はクランプ）
        let evaluationPeriod: Int
        if userDefaults.object(forKey: AlertSettingsKeys.evaluationPeriod) != nil {
            let rawValue = userDefaults.integer(forKey: AlertSettingsKeys.evaluationPeriod)
            evaluationPeriod = Self.clamp(rawValue, to: AlertSettings.evaluationPeriodSecondsRange)
        } else {
            evaluationPeriod = AlertSettings.default.evaluationPeriodSeconds
        }

        // minimumIntervalの読み込み（存在しない場合はデフォルト、範囲外はクランプ）
        let minimumInterval: Int
        if userDefaults.object(forKey: AlertSettingsKeys.minimumInterval) != nil {
            let rawValue = userDefaults.integer(forKey: AlertSettingsKeys.minimumInterval)
            minimumInterval = Self.clamp(rawValue, to: AlertSettings.minimumIntervalSecondsRange)
        } else {
            minimumInterval = AlertSettings.default.minimumIntervalSeconds
        }

        let settings = AlertSettings(
            isEnabled: isEnabled,
            threshold: threshold,
            evaluationPeriodSeconds: evaluationPeriod,
            minimumIntervalSeconds: minimumInterval
        )

        logger.debug("Alert settings loaded")

        return settings
    }

    /// 設定を保存する
    ///
    /// - Parameter settings: 保存する設定
    func save(_ settings: AlertSettings) {
        lock.lock()
        defer { lock.unlock() }

        userDefaults.set(settings.isEnabled, forKey: AlertSettingsKeys.isEnabled)
        userDefaults.set(settings.threshold, forKey: AlertSettingsKeys.threshold)
        userDefaults.set(settings.evaluationPeriodSeconds, forKey: AlertSettingsKeys.evaluationPeriod)
        userDefaults.set(settings.minimumIntervalSeconds, forKey: AlertSettingsKeys.minimumInterval)

        logger.info("Alert settings saved")
    }

    /// 設定をデフォルトにリセットする
    func reset() {
        lock.lock()
        defer { lock.unlock() }

        userDefaults.removeObject(forKey: AlertSettingsKeys.isEnabled)
        userDefaults.removeObject(forKey: AlertSettingsKeys.threshold)
        userDefaults.removeObject(forKey: AlertSettingsKeys.evaluationPeriod)
        userDefaults.removeObject(forKey: AlertSettingsKeys.minimumInterval)

        logger.info("Settings reset to defaults")
    }

    // MARK: - Private Helpers

    /// 値を指定範囲内にクランプする
    private static func clamp(_ value: Int, to range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }
}
