import Foundation

/// 通知設定
///
/// 姿勢アラート通知に関するユーザー設定を保持する構造体。
/// UserDefaultsで永続化される。
struct AlertSettings: Equatable, Codable {
    /// 通知機能の有効/無効
    var isEnabled: Bool

    /// 閾値スコア (20-80)
    /// この値以下の平均スコアで通知をトリガー
    var threshold: Int

    /// 評価期間（秒）(60-600、つまり1-10分)
    /// この期間の平均スコアを計算
    var evaluationPeriodSeconds: Int

    /// 最短通知間隔（秒）(300-3600、つまり5-60分)
    /// 前回通知からこの時間が経過するまで再通知しない
    var minimumIntervalSeconds: Int

    // MARK: - Validation Ranges

    /// 閾値の有効範囲 (20-80)
    static let thresholdRange = 20 ... 80

    /// 評価期間の有効範囲（秒）(60-600)
    static let evaluationPeriodSecondsRange = 60 ... 600

    /// 最短通知間隔の有効範囲（秒）(300-3600)
    static let minimumIntervalSecondsRange = 300 ... 3600

    // MARK: - Default Values

    /// デフォルト設定
    static let `default` = AlertSettings(
        isEnabled: true,
        threshold: 60,
        evaluationPeriodSeconds: 300, // 5分
        minimumIntervalSeconds: 900 // 15分
    )

    // MARK: - Computed Properties

    /// 評価期間（分）- UI表示用
    var evaluationPeriodMinutes: Int {
        get { evaluationPeriodSeconds / 60 }
        set { evaluationPeriodSeconds = newValue * 60 }
    }

    /// 最短通知間隔（分）- UI表示用
    var minimumIntervalMinutes: Int {
        get { minimumIntervalSeconds / 60 }
        set { minimumIntervalSeconds = newValue * 60 }
    }
}
