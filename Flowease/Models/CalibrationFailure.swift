import Foundation

/// キャリブレーション失敗の理由
///
/// キャリブレーションが完了できなかった場合の原因を表す。
/// ユーザーへのメッセージ表示に使用。
enum CalibrationFailure: Equatable {
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
            return String(localized: "Please adjust your position so your face is visible in the camera preview.")
        case .lowConfidence:
            return String(localized: "Please brighten the lighting and ensure your face is clearly visible.")
        case .insufficientFrames:
            return String(localized: "Please hold still in a good posture for 3 seconds and try again.")
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
