import Combine
import Foundation
import os

/// ユーザー設定を管理するサービス
public final class SettingsService: SettingsServiceProtocol {
    // MARK: - Properties

    public let settings: CurrentValueSubject<UserSettings, Never>
    public let breakReminder: CurrentValueSubject<BreakReminder, Never>

    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.flowease", category: "SettingsService")

    // MARK: - Initialization

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        // 初期値をデフォルトに設定（loadSettingsで上書きされる）
        self.settings = CurrentValueSubject<UserSettings, Never>(.default)
        self.breakReminder = CurrentValueSubject<BreakReminder, Never>(.default)

        // 保存された設定を読み込み
        loadSettings()
    }

    // MARK: - SettingsServiceProtocol

    public func loadSettings() {
        // UserSettingsの読み込み
        if let data = userDefaults.data(forKey: Constants.UserDefaultsKeys.userSettings) {
            do {
                let loadedSettings = try decoder.decode(UserSettings.self, from: data)
                settings.send(loadedSettings)
            } catch {
                logger.error("Failed to decode UserSettings: \(error.localizedDescription)")
                settings.send(.default)
            }
        }

        // BreakReminderの読み込み
        if let data = userDefaults.data(forKey: Constants.UserDefaultsKeys.breakReminder) {
            do {
                let loadedReminder = try decoder.decode(BreakReminder.self, from: data)
                breakReminder.send(loadedReminder)
            } catch {
                logger.error("Failed to decode BreakReminder: \(error.localizedDescription)")
                breakReminder.send(.default)
            }
        }
    }

    public func saveSettings(_ newSettings: UserSettings) {
        do {
            let data = try encoder.encode(newSettings)
            userDefaults.set(data, forKey: Constants.UserDefaultsKeys.userSettings)
            settings.send(newSettings)
        } catch {
            logger.error("Failed to encode UserSettings: \(error.localizedDescription)")
        }
    }

    public func saveBreakReminder(_ reminder: BreakReminder) {
        do {
            let data = try encoder.encode(reminder)
            userDefaults.set(data, forKey: Constants.UserDefaultsKeys.breakReminder)
            breakReminder.send(reminder)
        } catch {
            logger.error("Failed to encode BreakReminder: \(error.localizedDescription)")
        }
    }

    public func resetToDefaults() {
        // UserDefaultsからキーを削除
        userDefaults.removeObject(forKey: Constants.UserDefaultsKeys.userSettings)
        userDefaults.removeObject(forKey: Constants.UserDefaultsKeys.breakReminder)

        // デフォルト値を送信
        settings.send(.default)
        breakReminder.send(.default)
    }

    public func updateSetting<T>(_ keyPath: WritableKeyPath<UserSettings, T>, value: T) {
        var currentSettings = settings.value
        currentSettings[keyPath: keyPath] = value
        saveSettings(currentSettings)
    }
}

// MARK: - Convenience Methods

public extension SettingsService {
    /// カメラIDを更新
    func updateSelectedCamera(_ deviceID: String?) {
        updateSetting(\.selectedCameraID, value: deviceID)
    }

    /// 休憩間隔を更新
    func updateBreakInterval(_ minutes: Int) {
        let clampedMinutes = max(
            Constants.BreakReminder.minimumIntervalMinutes,
            min(Constants.BreakReminder.maximumIntervalMinutes, minutes)
        )
        updateSetting(\.breakIntervalMinutes, value: clampedMinutes)
    }

    /// 姿勢感度を更新
    func updatePostureSensitivity(_ sensitivity: Double) {
        let clampedSensitivity = max(0.0, min(1.0, sensitivity))
        updateSetting(\.postureSensitivity, value: clampedSensitivity)
    }

    /// 通知の有効/無効を切り替え
    func updateNotificationsEnabled(_ enabled: Bool) {
        updateSetting(\.notificationsEnabled, value: enabled)
    }

    /// 姿勢モニタリングの有効/無効を切り替え
    func updatePostureMonitoringEnabled(_ enabled: Bool) {
        updateSetting(\.postureMonitoringEnabled, value: enabled)
    }

    /// 前かがみ閾値を更新
    func updateForwardLeanThreshold(_ threshold: Double) {
        let clampedThreshold = max(5.0, min(30.0, threshold))
        updateSetting(\.forwardLeanThreshold, value: clampedThreshold)
    }

    /// 首傾き閾値を更新
    func updateNeckTiltThreshold(_ threshold: Double) {
        let clampedThreshold = max(10.0, min(40.0, threshold))
        updateSetting(\.neckTiltThreshold, value: clampedThreshold)
    }
}
