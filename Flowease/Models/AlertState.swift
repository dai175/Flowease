import Foundation

/// 通知状態
///
/// 通知の状態管理を担う構造体。再通知判定に使用。
///
/// ## 状態遷移
/// ```
/// [Initial] ──通知送信──▶ [Notified]
///     ▲                      │
///     │                      │
///     │                 ┌────┴────┐
///     │                 ▼         ▼
///     │           [姿勢改善]  [間隔経過]
///     │                 │         │
///     └──────────通知送信◀─────────┘
/// ```
///
/// 1. Initial → Notified: 平均スコアが閾値以下で通知送信
/// 2. Notified → 姿勢改善: 平均スコアが閾値を超える → hasImprovedSinceLastNotification = true
/// 3. 姿勢改善 → Notified: 再度平均スコアが閾値以下 → 通知送信
/// 4. Notified → 間隔経過: 姿勢改善なしで最短間隔経過 → リマインド通知送信
struct AlertState: Equatable {
    /// 最後に通知を送信した時刻（nil = 未送信）
    var lastNotificationTime: Date?

    /// 姿勢改善済みフラグ
    /// - true: 前回通知後に姿勢が改善された（再度悪化したら通知可能）
    /// - false: 前回通知後、まだ姿勢が改善されていない
    var hasImprovedSinceLastNotification: Bool

    /// 初期状態
    ///
    /// - lastNotificationTime: nil（未送信）
    /// - hasImprovedSinceLastNotification: true（初回は通知可能）
    static let initial = AlertState(
        lastNotificationTime: nil,
        hasImprovedSinceLastNotification: true
    )
}
