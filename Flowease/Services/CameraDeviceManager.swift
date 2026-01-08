import AVFoundation
import OSLog

/// カメラデバイスの列挙と監視を担当する内部サービス
///
/// CameraService の内部実装として機能し、AVCaptureDevice.DiscoverySession を使用して
/// ビデオデバイスを列挙・監視します。
/// View からは直接参照せず、CameraServiceProtocol 経由でアクセスします。
@MainActor
final class CameraDeviceManager {
    // MARK: - Properties

    /// 利用可能なカメラデバイス一覧
    private(set) var availableCameras: [CameraDevice] = []

    /// デバイスリスト変更時のコールバック
    ///
    /// - Warning: 循環参照を避けるため、クロージャ内で `[weak self]` を使用してください
    var onDevicesChanged: (([CameraDevice]) -> Void)?

    /// ロガー
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.flowease",
        category: "CameraDeviceManager"
    )

    // MARK: - Initialization

    init() {
        logger.debug("CameraDeviceManager initialized")
    }

    deinit {
        logger.debug("CameraDeviceManager deinitialized")
    }
}
