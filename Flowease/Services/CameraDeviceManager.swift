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

    /// 現在選択されているカメラのID（CameraService から設定される）
    var selectedCameraID: String?

    /// デバイスリスト変更時のコールバック
    var onDevicesChanged: (([CameraDevice]) -> Void)?

    /// 選択されたカメラが切断された時のコールバック
    var onSelectedCameraDisconnected: (() -> Void)?

    /// 選択されたカメラが再接続された時のコールバック
    var onSelectedCameraReconnected: (() -> Void)?

    /// ロガー
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.flowease",
        category: "CameraDeviceManager"
    )

    // MARK: - Private Properties

    /// デバイス検出セッション
    private var discoverySession: AVCaptureDevice.DiscoverySession?

    /// KVO 監視のトークン
    private var deviceObservation: NSKeyValueObservation?

    /// 選択されたカメラが切断された状態かどうか
    private var isSelectedCameraDisconnected = false

    // MARK: - Initialization

    init() {
        logger.debug("CameraDeviceManager initialized")
    }

    deinit {
        deviceObservation?.invalidate()
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

        // KVO でデバイスリスト変更を監視
        deviceObservation = discoverySession?.observe(\.devices, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in
                self?.enumerateCameras()
            }
        }

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

        // 選択されたカメラの切断/再接続を検出
        checkSelectedCameraConnection()
    }

    // MARK: - Device Connection Handling

    /// 選択されたカメラの接続状態をチェックし、切断/再接続を検出
    private func checkSelectedCameraConnection() {
        guard let selectedID = selectedCameraID else { return }

        let isSelectedConnected = availableCameras.contains { $0.id == selectedID }

        if !isSelectedConnected, !isSelectedCameraDisconnected {
            // 切断検出
            isSelectedCameraDisconnected = true
            logger.warning("Selected camera disconnected: \(selectedID)")
            onSelectedCameraDisconnected?()
        } else if isSelectedConnected, isSelectedCameraDisconnected {
            // 再接続検出
            isSelectedCameraDisconnected = false
            logger.info("Selected camera reconnected: \(selectedID)")
            onSelectedCameraReconnected?()
        }
    }

    /// 選択カメラの切断状態をリセット（カメラ選択変更時に呼び出す）
    func resetDisconnectionState() {
        isSelectedCameraDisconnected = false
    }
}
