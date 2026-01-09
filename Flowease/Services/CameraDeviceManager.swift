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

    // MARK: - Private Properties

    /// デバイス検出セッション
    private var discoverySession: AVCaptureDevice.DiscoverySession?

    // MARK: - Initialization

    init() {
        logger.debug("CameraDeviceManager initialized")
    }

    deinit {
        logger.debug("CameraDeviceManager deinitialized")
    }

    // MARK: - Setup Methods

    /// DiscoverySession を初期化
    ///
    /// 内蔵カメラと外部カメラの両方を検出するセッションを作成します。
    /// 初期化後、カメラデバイスを列挙します。
    func setupDiscoverySession() {
        discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .externalUnknown],
            mediaType: .video,
            position: .unspecified
        )
        logger.debug("DiscoverySession initialized")

        // 初期デバイス列挙
        enumerateCameras()
    }

    // MARK: - Camera Enumeration

    /// 利用可能なカメラデバイスを列挙
    ///
    /// DiscoverySession からデバイスを取得し、CameraDevice 配列に変換します。
    /// システムデフォルトカメラを特定し、isDefault フラグを設定します。
    func enumerateCameras() {
        guard let session = discoverySession else {
            logger.warning("DiscoverySession not initialized")
            return
        }

        let devices = session.devices
        let defaultDevice = AVCaptureDevice.default(for: .video)

        availableCameras = devices.map { device in
            CameraDevice(
                id: device.uniqueID,
                name: device.localizedName,
                isConnected: device.isConnected,
                isDefault: device.uniqueID == defaultDevice?.uniqueID
            )
        }

        logger.debug("Enumerated \(self.availableCameras.count) camera(s)")

        // デバイスリスト変更を通知
        onDevicesChanged?(availableCameras)
    }
}
