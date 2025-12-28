import Foundation

/// Flowease アプリケーション全体で使用される定数
enum Constants {

    // MARK: - App Info

    enum App {
        static let bundleIdentifier = "cc.focuswave.Flowease"
        static let name = "Flowease"
    }

    // MARK: - Posture Detection

    enum PostureDetection {
        /// 姿勢検知の間隔（秒）
        static let detectionInterval: TimeInterval = 2.0

        /// 前かがみ警告のデフォルト閾値（度）
        static let defaultForwardLeanThreshold: Double = 15.0

        /// 首傾き警告のデフォルト閾値（度）
        static let defaultNeckTiltThreshold: Double = 20.0

        /// 悪い姿勢が続いたときに通知するまでの時間（秒）
        static let badPostureAlertDelay: TimeInterval = 5.0

        /// 姿勢判定のデフォルト感度（0.0〜1.0）
        static let defaultSensitivity: Double = 0.5

        /// 姿勢スコアの閾値
        enum ScoreThreshold {
            /// 良い姿勢の下限スコア
            static let good: Double = 0.8
            /// 警告状態の下限スコア
            static let warning: Double = 0.6
            /// それ以下は悪い姿勢
            static let bad: Double = 0.4
        }

        /// Vision Framework の信頼度閾値
        static let confidenceThreshold: Float = 0.5
    }

    // MARK: - Camera

    enum Camera {
        /// カメラ解像度プリセット
        static let sessionPreset = "AVCaptureSessionPresetVGA640x480"

        /// フレームレート（fps）
        static let frameRate: Int32 = 15
    }

    // MARK: - Break Reminder

    enum BreakReminder {
        /// デフォルトの休憩間隔（分）
        static let defaultIntervalMinutes: Int = 30

        /// 最小休憩間隔（分）
        static let minimumIntervalMinutes: Int = 30

        /// 最大休憩間隔（分）
        static let maximumIntervalMinutes: Int = 60

        /// スヌーズ時間（秒）
        static let snoozeDelaySeconds: TimeInterval = 300 // 5分
    }

    // MARK: - Stretch

    enum Stretch {
        /// デフォルトのストレッチ時間（秒）
        static let defaultDurationSeconds: Int = 30

        /// 最小ストレッチ時間（秒）
        static let minimumDurationSeconds: Int = 10

        /// 最大ストレッチ時間（秒）
        static let maximumDurationSeconds: Int = 120
    }

    // MARK: - UI

    enum UI {
        /// ポップオーバーのサイズ
        enum Popover {
            static let width: CGFloat = 300
            static let height: CGFloat = 400
        }

        /// ステータスバーアイコンのサイズ
        static let statusBarIconSize: CGFloat = 18
    }

    // MARK: - UserDefaults Keys

    enum UserDefaultsKeys {
        static let userSettings = "cc.focuswave.Flowease.userSettings"
        static let breakReminder = "cc.focuswave.Flowease.breakReminder"
        static let lastVersion = "cc.focuswave.Flowease.lastVersion"
        static let onboardingCompleted = "cc.focuswave.Flowease.onboardingCompleted"
    }

    // MARK: - Notification Identifiers

    enum NotificationIdentifiers {
        /// 通知カテゴリ
        enum Category {
            static let postureAlert = "POSTURE_ALERT"
            static let breakReminder = "BREAK_REMINDER"
        }

        /// 通知アクション
        enum Action {
            static let startStretch = "START_STRETCH_ACTION"
            static let snooze = "SNOOZE_ACTION"
            static let dismiss = "DISMISS_ACTION"
        }
    }
}
