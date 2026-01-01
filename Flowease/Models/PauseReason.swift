import Foundation

// MARK: - PauseReason

/// 監視一時停止の理由
///
/// 姿勢監視が一時的に停止している理由を表す。
/// これらの状態は自動的に解消される可能性がある。
enum PauseReason: Sendable, Equatable {
    /// カメラの準備中
    ///
    /// AVCaptureSession の初期化・設定中に発生。
    case cameraInitializing

    /// 人物が検出されない
    ///
    /// カメラに人物が映っていない、または照明条件などにより検出に失敗した場合。
    case noPersonDetected

    /// カメラが他のアプリで使用中
    ///
    /// 他のアプリケーションがカメラを排他的に使用している場合。
    /// AVCaptureSession.InterruptionReason.videoDeviceInUseByAnotherClient で検出。
    case cameraInUse

    /// 検出精度が低下している
    ///
    /// カメラに人物が映っているが、照明条件や姿勢などの理由で
    /// 関節の検出精度が低い場合。
    case lowDetectionQuality
}

// MARK: CustomStringConvertible

extension PauseReason: CustomStringConvertible {
    /// ユーザー向けの説明文
    var description: String {
        switch self {
        case .cameraInitializing:
            "カメラを準備中..."
        case .noPersonDetected:
            "人物が検出されません"
        case .cameraInUse:
            "カメラが他のアプリで使用中です"
        case .lowDetectionQuality:
            "検出精度が低下しています"
        }
    }
}
