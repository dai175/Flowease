import Foundation

// MARK: - CalibrationState

/// キャリブレーションの現在状態
///
/// キャリブレーションのライフサイクルを表す列挙型。
/// 状態遷移: notCalibrated → inProgress → completed/failed → notCalibrated (reset)
///
/// Note: この状態は永続化されない。アプリ再起動時は`referencePosture`の有無から
/// `notCalibrated`または`completed`に復帰する。
enum CalibrationState: Equatable {
    /// キャリブレーション未実行
    /// 初回起動時、またはリセット後の状態
    case notCalibrated

    /// キャリブレーション実行中
    /// 関連値: 進行状況
    case inProgress(CalibrationProgress)

    /// キャリブレーション完了
    /// 基準姿勢が正常に記録された状態
    case completed

    /// キャリブレーション失敗
    /// 関連値: 失敗理由
    case failed(CalibrationFailure)

    // MARK: - Convenience Properties

    /// キャリブレーション未実行かどうか
    var isNotCalibrated: Bool {
        self == .notCalibrated
    }

    /// キャリブレーション実行中かどうか
    var isInProgress: Bool {
        guard case .inProgress = self else { return false }
        return true
    }

    /// キャリブレーション完了かどうか
    var isCompleted: Bool {
        self == .completed
    }

    /// キャリブレーション失敗かどうか
    var isFailed: Bool {
        guard case .failed = self else { return false }
        return true
    }

    /// 進行状況（実行中の場合のみ）
    var progress: CalibrationProgress? {
        guard case let .inProgress(progress) = self else { return nil }
        return progress
    }

    /// 失敗理由（失敗の場合のみ）
    var failure: CalibrationFailure? {
        guard case let .failed(failure) = self else { return nil }
        return failure
    }

    /// ユーザー向けの状態説明
    var statusDescription: String {
        switch self {
        case .notCalibrated:
            return "未設定"
        case .inProgress:
            return "設定中..."
        case .completed:
            return "設定済み"
        case .failed:
            return "設定失敗"
        }
    }
}
