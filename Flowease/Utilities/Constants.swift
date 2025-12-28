import AVFoundation
import Foundation

/// Flowease アプリケーション全体で使用される定数
public enum Constants {

    // MARK: - App Info

    public enum App {
        public static let bundleIdentifier = "cc.focuswave.Flowease"
        public static let name = "Flowease"
    }

    // MARK: - Posture Detection

    public enum PostureDetection {
        /// 姿勢検知の間隔（秒）
        public static let detectionInterval: TimeInterval = 2.0

        /// 前かがみ警告のデフォルト閾値（度）
        public static let defaultForwardLeanThreshold: Double = 15.0

        /// 首傾き警告のデフォルト閾値（度）
        public static let defaultNeckTiltThreshold: Double = 20.0

        /// 悪い姿勢が続いたときに通知するまでの時間（秒）
        public static let badPostureAlertDelay: TimeInterval = 5.0

        /// 姿勢判定のデフォルト感度（0.0〜1.0）
        public static let defaultSensitivity: Double = 0.5

        /// 姿勢スコアの閾値
        public enum ScoreThreshold {
            /// 良い姿勢の下限スコア
            public static let good: Double = 0.8
            /// 警告状態の下限スコア
            public static let warning: Double = 0.6
            /// それ以下は悪い姿勢
            public static let bad: Double = 0.4
        }

        /// Vision Framework の信頼度閾値
        public static let confidenceThreshold: Float = 0.5
    }

    // MARK: - Camera

    public enum Camera {
        /// カメラ解像度プリセット
        public static let sessionPreset: AVCaptureSession.Preset = .vga640x480

        /// フレームレート（fps）
        public static let frameRate: Int32 = 15
    }

    // MARK: - Break Reminder

    public enum BreakReminder {
        /// デフォルトの休憩間隔（分）
        public static let defaultIntervalMinutes: Int = 30

        /// 最小休憩間隔（分）
        public static let minimumIntervalMinutes: Int = 30

        /// 最大休憩間隔（分）
        public static let maximumIntervalMinutes: Int = 60

        /// スヌーズ時間（秒）
        public static let snoozeDelaySeconds: TimeInterval = 300 // 5分
    }

    // MARK: - Stretch

    public enum Stretch {
        /// デフォルトのストレッチ時間（秒）
        public static let defaultDurationSeconds: Int = 30

        /// 最小ストレッチ時間（秒）
        public static let minimumDurationSeconds: Int = 10

        /// 最大ストレッチ時間（秒）
        public static let maximumDurationSeconds: Int = 120
    }

    // MARK: - UI

    public enum UI {
        /// ポップオーバーのサイズ
        public enum Popover {
            public static let width: CGFloat = 300
            public static let height: CGFloat = 400
        }

        /// ステータスバーアイコンのサイズ
        public static let statusBarIconSize: CGFloat = 18
    }

    // MARK: - UserDefaults Keys

    public enum UserDefaultsKeys {
        public static let userSettings = "cc.focuswave.Flowease.userSettings"
        public static let breakReminder = "cc.focuswave.Flowease.breakReminder"
        public static let lastVersion = "cc.focuswave.Flowease.lastVersion"
        public static let onboardingCompleted = "cc.focuswave.Flowease.onboardingCompleted"
    }

    // MARK: - Notification Identifiers

    public enum NotificationIdentifiers {
        /// 通知カテゴリ
        public enum Category {
            public static let postureAlert = "POSTURE_ALERT"
            public static let breakReminder = "BREAK_REMINDER"
        }

        /// 通知アクション
        public enum Action {
            public static let startStretch = "START_STRETCH_ACTION"
            public static let snooze = "SNOOZE_ACTION"
            public static let dismiss = "DISMISS_ACTION"
        }
    }
}
