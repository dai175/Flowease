// CameraService.swift
// Flowease
//
// カメラ権限の管理とフレームキャプチャを担当するサービス

@preconcurrency import AVFoundation
import Combine
import OSLog

// MARK: - CameraService

/// カメラ権限管理とフレームキャプチャの実装
@MainActor
final class CameraService: NSObject, CameraServiceProtocol, ObservableObject {
    // MARK: - Properties

    /// Note: extension からアクセスするため internal
    let logger = Logger(subsystem: "cc.focuswave.Flowease", category: "CameraService")

    /// カメラデバイスマネージャー（プロトコル経由で依存注入可能）
    private let deviceManager: any CameraDeviceManaging

    /// UserDefaults に保存されるカメラ選択のキー
    /// Note: extension からアクセスするため internal
    static let selectedCameraKey = "selectedCameraDeviceID"

    /// 現在のカメラ権限状態
    var authorizationStatus: CameraAuthorizationStatus {
        let avStatus = AVCaptureDevice.authorizationStatus(for: .video)
        return CameraAuthorizationStatus(from: avStatus)
    }

    /// フレームキャプチャ中かどうか
    /// Note: extension からアクセスするため internal(set)
    var isCapturing = false

    /// フレームを受け取るデリゲート
    weak var frameDelegate: CameraFrameDelegate?

    /// 利用可能なカメラデバイス一覧
    var availableCameras: [CameraDevice] { deviceManager.availableCameras }

    /// 現在選択されているカメラのID
    ///
    /// UserDefaults と同期されます。
    /// nil の場合はシステムデフォルトを使用。
    /// Note: extension からアクセスするため internal(set)
    @Published var selectedCameraID: String?

    // MARK: - Capture Session Properties

    // Note: extension からアクセスするため internal

    /// キャプチャセッション
    var captureSession: AVCaptureSession?

    /// ビデオ出力
    var videoOutput: AVCaptureVideoDataOutput?

    /// キャプチャ入力（クリーンアップ時に削除するために保持）
    var captureInput: AVCaptureDeviceInput?

    /// キャプチャ処理用の専用キュー
    let captureQueue = DispatchQueue(
        label: "cc.focuswave.Flowease.CameraCapture",
        qos: .userInitiated
    )

    /// フレームスキップカウンター（パフォーマンス最適化用、nonisolated でアクセスするため Atomic 使用）
    /// Note: extension からアクセスするため internal
    let frameCounter = OSAllocatedUnfairLock(initialState: 0)

    /// 処理するフレームの間隔（2 = 2フレームに1回処理）
    /// Note: extension からアクセスするため internal
    let frameProcessingInterval = 2

    /// 現在実際に使用中のカメラID（フォールバック判定用）
    /// Note: extension からアクセスするため internal
    var currentCameraID: String?

    /// フォールバック試行中フラグ（無限ループ防止）
    /// Note: extension からアクセスするため internal
    var isAttemptingFallback = false

    // MARK: - Initialization

    /// イニシャライザ
    ///
    /// - Parameter deviceManager: カメラデバイスマネージャー（依存注入によりテスト可能）
    init(deviceManager: any CameraDeviceManaging = CameraDeviceManager()) {
        self.deviceManager = deviceManager
        // UserDefaults から選択カメラIDを復元
        selectedCameraID = UserDefaults.standard.string(forKey: Self.selectedCameraKey)
        super.init()

        // 保存された選択カメラIDを deviceManager に設定
        self.deviceManager.selectedCameraID = selectedCameraID

        // 切断/再接続コールバックを設定
        self.deviceManager.onSelectedCameraDisconnected = { [weak self] in
            self?.handleSelectedCameraDisconnected()
        }
        self.deviceManager.onSelectedCameraReconnected = { [weak self] in
            self?.handleSelectedCameraReconnected()
        }

        self.deviceManager.setupDiscoverySession()
        logger.debug("CameraService initialized")
    }

    // MARK: - Device Change Handlers

    private func handleSelectedCameraDisconnected() {
        logger.warning("Selected camera disconnected: \(self.selectedCameraID ?? "unknown")")
        stopCapturing()
        frameDelegate?.cameraService(self, didEncounterError: CameraServiceError.selectedCameraDisconnected)
    }

    private func handleSelectedCameraReconnected() {
        logger.info("Selected camera reconnected: \(self.selectedCameraID ?? "unknown"), auto-resuming capture")
        startCapturing()
    }

    // MARK: - Public Methods

    /// カメラ権限をリクエスト
    /// - Returns: リクエスト後の権限状態
    func requestAuthorization() async -> CameraAuthorizationStatus {
        let currentStatus = authorizationStatus

        // 既に決定済みの場合はそのまま返す
        guard currentStatus == .notDetermined else {
            logger.info("Camera permission already determined: \(String(describing: currentStatus))")
            return currentStatus
        }

        logger.info("Requesting camera permission...")

        // 権限リクエストを実行
        let granted = await AVCaptureDevice.requestAccess(for: .video)

        let newStatus = authorizationStatus
        logger.info("Camera permission request result: granted=\(granted), status=\(String(describing: newStatus))")

        return newStatus
    }

    /// カメラデバイスが利用可能かチェック
    /// - Returns: カメラが利用可能な場合は true
    func checkCameraAvailability() -> Bool {
        let device = AVCaptureDevice.default(for: .video)
        let isAvailable = device != nil
        logger.debug("Camera device available: \(isAvailable)")
        return isAvailable
    }

    /// 現在の権限状態を MonitoringState に変換
    /// - Returns: 対応する MonitoringState
    func toMonitoringState() -> MonitoringState {
        // カメラデバイスが存在しない場合
        if !checkCameraAvailability() {
            logger.warning("Camera device unavailable")
            return .disabled(.noCameraAvailable)
        }

        // 権限状態に基づいて MonitoringState を決定
        switch authorizationStatus {
        case .authorized:
            // 権限あり → カメラ初期化待ち
            return .paused(.cameraInitializing)

        case .denied:
            return .disabled(.cameraPermissionDenied)

        case .restricted:
            return .disabled(.cameraPermissionRestricted)

        case .notDetermined:
            // 権限未決定 → カメラ初期化待ち（後で権限リクエストが必要）
            return .paused(.cameraInitializing)
        }
    }

    /// フレームキャプチャを開始
    func startCapturing() {
        guard !isCapturing else {
            logger.debug("Already capturing")
            return
        }

        // 先にフラグを立てて重複呼び出しを防ぐ（競合状態対策）
        isCapturing = true

        guard authorizationStatus == .authorized else {
            isCapturing = false
            logger.warning("Cannot start capture: camera permission not granted")
            frameDelegate?.cameraService(self, didEncounterError: CameraServiceError.permissionDenied)
            return
        }

        guard checkCameraAvailability() else {
            isCapturing = false
            logger.warning("Cannot start capture: camera device unavailable")
            frameDelegate?.cameraService(self, didEncounterError: CameraServiceError.noCameraAvailable)
            return
        }

        do {
            try setupCaptureSession()
            let session = captureSession
            // startRunning() はブロッキング呼び出しなのでバックグラウンドで実行
            captureQueue.async { [weak self] in
                session?.startRunning()
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    // セッションが実際に開始されたかチェック
                    guard let session, session.isRunning else {
                        isCapturing = false
                        logger.error("Failed to start frame capture")
                        frameDelegate?.cameraService(self, didEncounterError: CameraServiceError.cameraInUse)
                        return
                    }
                    logger.info("Frame capture started")
                }
            }
        } catch {
            isCapturing = false
            logger.error("Failed to set up capture session: \(error.localizedDescription)")
            frameDelegate?.cameraService(self, didEncounterError: error)
        }
    }

    /// フレームキャプチャを停止
    func stopCapturing() {
        guard isCapturing else {
            logger.debug("Capture already stopped")
            return
        }
        isCapturing = false
        cleanupSession()
        logger.info("Frame capture stopped")
    }

    /// セッションをクリーンアップし、完了後にコールバックを実行
    /// - Parameter completion: クリーンアップ完了後に実行するクロージャ（nil可）
    private func cleanupSession(completion: (@Sendable () -> Void)? = nil) {
        let session = captureSession
        let output = videoOutput
        let input = captureInput

        captureSession = nil
        videoOutput = nil
        captureInput = nil
        currentCameraID = nil
        frameCounter.withLock { $0 = 0 }

        // セッション通知のオブザーバーを削除
        if let session {
            NotificationCenter.default.removeObserver(
                self,
                name: AVCaptureSession.runtimeErrorNotification,
                object: session
            )
        }

        // クリーンアップ処理はバックグラウンドで実行（stopRunning() はブロッキング呼び出し）
        captureQueue.async {
            // デリゲート参照を削除してコールバックを停止
            output?.setSampleBufferDelegate(nil, queue: nil)

            // セッションの入出力を原子的に削除
            session?.beginConfiguration()
            if let input { session?.removeInput(input) }
            if let output { session?.removeOutput(output) }
            session?.commitConfiguration()

            // セッションを停止
            session?.stopRunning()

            // 完了コールバックを実行
            completion?()
        }
    }

    /// カメラを選択
    ///
    /// 選択されたカメラIDをUserDefaultsに永続化します。
    /// キャプチャ中の場合は、新しいカメラでセッションを再起動します。
    /// nil を渡すとシステムデフォルトカメラを使用します。
    ///
    /// - Parameter deviceID: 選択するカメラのuniqueID (nil でシステムデフォルト)
    func selectCamera(_ deviceID: String?) {
        // プロパティを更新
        selectedCameraID = deviceID

        // UserDefaults に保存
        if let deviceID {
            UserDefaults.standard.set(deviceID, forKey: Self.selectedCameraKey)
            logger.info("Camera selected: \(deviceID)")
        } else {
            UserDefaults.standard.removeObject(forKey: Self.selectedCameraKey)
            logger.info("Camera selection cleared (using system default)")
        }

        // deviceManager にも同期
        deviceManager.selectedCameraID = deviceID
        deviceManager.resetDisconnectionState()

        // キャプチャ中であれば新しいカメラでセッションを再起動
        if isCapturing {
            logger.info("Restarting capture session with new camera")
            restartCapturing()
        }
    }

    /// キャプチャを再起動（停止完了を待ってから開始）
    ///
    /// 競合状態を避けるため、古いセッションの停止を待ってから新しいセッションを開始します。
    private func restartCapturing() {
        guard isCapturing else { return }
        isCapturing = false
        cleanupSession { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                logger.info("Old session stopped, starting new session")
                startCapturing()
            }
        }
        logger.info("Frame capture stopping for restart")
    }

    // MARK: - Private Methods

    /// 使用するカメラデバイスを解決
    ///
    /// 選択されたカメラが利用可能であればそれを返し、
    /// 利用不可の場合はシステムデフォルトにフォールバックします。
    ///
    /// - Parameter preferredID: 優先するカメラのID（nil でシステムデフォルト）
    /// - Returns: 使用するデバイスとフォールバックが発生したかどうか
    private func resolveCamera(preferredID: String?) -> (device: AVCaptureDevice?, didFallback: Bool) {
        // 優先IDが指定されている場合
        if let preferredID,
           let device = AVCaptureDevice(uniqueID: preferredID),
           device.isConnected {
            logger.debug("Using preferred camera: \(device.localizedName)")
            return (device, false)
        }

        // フォールバック: システムデフォルトを使用
        let defaultDevice = AVCaptureDevice.default(for: .video)

        // preferredID が指定されていたがフォールバックした場合のみ didFallback = true
        let didFallback = preferredID != nil
        if didFallback {
            logger
                .info(
                    "Preferred camera unavailable, falling back to default: \(defaultDevice?.localizedName ?? "none")"
                )
        } else {
            logger.debug("Using default camera: \(defaultDevice?.localizedName ?? "none")")
        }

        return (defaultDevice, didFallback)
    }

    /// キャプチャセッションをセットアップ
    private func setupCaptureSession() throws {
        let session = AVCaptureSession()
        session.sessionPreset = .medium // 640x480 相当

        // カメラデバイスを解決（選択されたカメラ、またはシステムデフォルト）
        let (resolvedDevice, didFallback) = resolveCamera(preferredID: selectedCameraID)

        guard let device = resolvedDevice else {
            throw CameraServiceError.noCameraAvailable
        }

        // 現在使用中のカメラIDを記録（フォールバック判定用）
        currentCameraID = device.uniqueID

        // フォールバックが発生した場合、ログに記録（FR-004 の通知は View 層で実装）
        if didFallback {
            logger.warning("Camera fallback occurred - selected camera not available")
        }

        // 入力を追加
        let input: AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput(device: device)
        } catch {
            logger.error("Failed to create camera input: \(error.localizedDescription)")
            throw CameraServiceError.sessionConfigurationFailed
        }

        guard session.canAddInput(input) else {
            logger.error("Cannot add input to session")
            throw CameraServiceError.sessionConfigurationFailed
        }
        session.addInput(input)
        captureInput = input

        // 出力を追加
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: captureQueue)

        guard session.canAddOutput(output) else {
            logger.error("Cannot add output to session")
            throw CameraServiceError.sessionConfigurationFailed
        }
        session.addOutput(output)

        captureSession = session
        videoOutput = output

        // セッションランタイムエラーの通知を購読
        // macOS では wasInterruptedNotification が利用できないため、runtimeErrorNotification を使用
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sessionRuntimeError(_:)),
            name: AVCaptureSession.runtimeErrorNotification,
            object: session
        )

        logger.debug("Capture session set up")
    }
}
