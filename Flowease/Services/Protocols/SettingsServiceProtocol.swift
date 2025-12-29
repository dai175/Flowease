import Combine
import Foundation

/// 設定サービスプロトコル
public protocol SettingsServiceProtocol: AnyObject {

    // MARK: - Properties

    /// 現在の設定
    var settings: CurrentValueSubject<UserSettings, Never> { get }

    /// 休憩リマインダー設定
    var breakReminder: CurrentValueSubject<BreakReminder, Never> { get }

    // MARK: - Methods

    /// 設定を読み込み
    func loadSettings()

    /// 設定を保存
    func saveSettings(_ settings: UserSettings)

    /// 休憩リマインダー設定を保存
    func saveBreakReminder(_ reminder: BreakReminder)

    /// 設定をデフォルトにリセット
    func resetToDefaults()

    /// 特定の設定値を更新
    /// - Parameters:
    ///   - keyPath: 設定のキーパス
    ///   - value: 新しい値
    func updateSetting<T>(_ keyPath: WritableKeyPath<UserSettings, T>, value: T)
}
