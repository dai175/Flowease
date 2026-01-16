import Foundation

/// キャリブレーション失敗の理由
///
/// キャリブレーションが完了できなかった場合の原因を表す。
/// ユーザーへのメッセージ表示に使用。
enum CalibrationFailure: Sendable, Equatable {
    /// 顔が検出されなかった
    case noFaceDetected

    /// 信頼度が低い状態が続いた（約1秒間）
    case lowConfidence

    /// 十分なフレームが収集できなかった
    case insufficientFrames

    /// ユーザー向けのエラーメッセージ
    var userMessage: String {
        switch self {
        case .noFaceDetected:
            return String(localized: "Please ensure your face is visible to the camera")
        case .lowConfidence:
            return String(localized: "Please adjust the lighting")
        case .insufficientFrames:
            return String(localized: "Please try again")
        }
    }

    /// ログ出力用の説明
    var logDescription: String {
        switch self {
        case .noFaceDetected:
            return "No face detected during calibration"
        case .lowConfidence:
            return "Low confidence streak exceeded threshold"
        case .insufficientFrames:
            return "Insufficient frames collected for calibration"
        }
    }
}
