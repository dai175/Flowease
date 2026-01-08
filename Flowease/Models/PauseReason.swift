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

    /// 顔が検出されない
    ///
    /// カメラに顔が映っていない、または照明条件などにより検出に失敗した場合。
    case noFaceDetected

    /// カメラが他のアプリで使用中
    ///
    /// 他のアプリケーションがカメラを排他的に使用している場合。
    /// AVCaptureSession.InterruptionReason.videoDeviceInUseByAnotherClient で検出。
    case cameraInUse

    /// 検出精度が低下している
    ///
    /// カメラに顔が映っているが、照明条件や角度などの理由で
    /// 顔の検出品質が低い場合。
    case lowDetectionQuality

    /// 選択されたカメラが切断された
    ///
    /// ユーザーが選択したカメラが物理的に切断された場合。
    /// 再接続されるか、別のカメラを選択するまで一時停止。
    case selectedCameraDisconnected
}

// MARK: CustomStringConvertible

extension PauseReason: CustomStringConvertible {
    /// ユーザー向けの説明文
    var description: String {
        switch self {
        case .cameraInitializing:
            String(localized: "Initializing camera...")
        case .noFaceDetected:
            String(localized: "Face not detected")
        case .cameraInUse:
            String(localized: "Camera is being used by another app")
        case .lowDetectionQuality:
            String(localized: "Detection quality is low")
        case .selectedCameraDisconnected:
            String(localized: "Selected camera disconnected")
        }
    }
}
