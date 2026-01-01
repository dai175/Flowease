import Foundation

/// キャリブレーション失敗の理由
///
/// キャリブレーションが完了できなかった場合の原因を表す。
/// ユーザーへのメッセージ表示に使用。
enum CalibrationFailure: Sendable, Equatable {
    /// 人物が検出されなかった
    case noPersonDetected

    /// 信頼度が低い状態が続いた（約1秒間）
    case lowConfidence

    /// 十分なフレームが収集できなかった
    case insufficientFrames

    /// ユーザーがキャンセルした
    case cancelled

    /// ユーザー向けのエラーメッセージ
    var userMessage: String {
        switch self {
        case .noPersonDetected:
            return "カメラに映るようにしてください"
        case .lowConfidence:
            return "照明を調整してください"
        case .insufficientFrames:
            return "もう一度お試しください"
        case .cancelled:
            return ""
        }
    }

    /// ログ出力用の説明
    var logDescription: String {
        switch self {
        case .noPersonDetected:
            return "No person detected during calibration"
        case .lowConfidence:
            return "Low confidence streak exceeded threshold"
        case .insufficientFrames:
            return "Insufficient frames collected for calibration"
        case .cancelled:
            return "Calibration cancelled by user"
        }
    }
}
