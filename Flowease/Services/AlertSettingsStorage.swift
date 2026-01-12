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
    private let logger = Logger.alertSettingsStorage
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
        lock.withLock {
            let settings = AlertSettings(
                isEnabled: loadBool(forKey: AlertSettingsKeys.isEnabled, default: AlertSettings.default.isEnabled),
                threshold: loadInt(
                    forKey: AlertSettingsKeys.threshold,
                    default: AlertSettings.default.threshold,
                    range: AlertSettings.thresholdRange
                ),
                evaluationPeriodSeconds: loadInt(
                    forKey: AlertSettingsKeys.evaluationPeriod,
                    default: AlertSettings.default.evaluationPeriodSeconds,
                    range: AlertSettings.evaluationPeriodSecondsRange
                ),
                minimumIntervalSeconds: loadInt(
                    forKey: AlertSettingsKeys.minimumInterval,
                    default: AlertSettings.default.minimumIntervalSeconds,
                    range: AlertSettings.minimumIntervalSecondsRange
                )
            )

            logger.debug("Alert settings loaded")
            return settings
        }
    }

    /// Bool値を読み込む（存在しない場合はデフォルト値を返す）
    private func loadBool(forKey key: String, default defaultValue: Bool) -> Bool {
        guard userDefaults.object(forKey: key) != nil else { return defaultValue }
        return userDefaults.bool(forKey: key)
    }

    /// Int値を読み込む（存在しない場合はデフォルト値、範囲外はクランプ）
    private func loadInt(forKey key: String, default defaultValue: Int, range: ClosedRange<Int>) -> Int {
        guard userDefaults.object(forKey: key) != nil else { return defaultValue }
        return Self.clamp(userDefaults.integer(forKey: key), to: range)
    }

    /// 設定を保存する
    ///
    /// - Parameter settings: 保存する設定
    func save(_ settings: AlertSettings) {
        lock.withLock {
            userDefaults.set(settings.isEnabled, forKey: AlertSettingsKeys.isEnabled)
            userDefaults.set(settings.threshold, forKey: AlertSettingsKeys.threshold)
            userDefaults.set(settings.evaluationPeriodSeconds, forKey: AlertSettingsKeys.evaluationPeriod)
            userDefaults.set(settings.minimumIntervalSeconds, forKey: AlertSettingsKeys.minimumInterval)

            logger.info("Alert settings saved")
        }
    }

    /// 設定をデフォルトにリセットする
    func reset() {
        lock.withLock {
            userDefaults.removeObject(forKey: AlertSettingsKeys.isEnabled)
            userDefaults.removeObject(forKey: AlertSettingsKeys.threshold)
            userDefaults.removeObject(forKey: AlertSettingsKeys.evaluationPeriod)
            userDefaults.removeObject(forKey: AlertSettingsKeys.minimumInterval)

            logger.info("Settings reset to defaults")
        }
    }

    // MARK: - Private Helpers

    /// 値を指定範囲内にクランプする
    private static func clamp(_ value: Int, to range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }
}
