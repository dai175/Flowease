// CameraService.swift
// Flowease
//
// カメラ権限の管理とフレームキャプチャを担当するサービス

@preconcurrency import AVFoundation
import OSLog

// MARK: - CameraService

/// カメラ権限管理とフレームキャプチャの実装
@MainActor
final class CameraService: NSObject, CameraServiceProtocol {
    // MARK: - Properties

    private let logger = Logger(subsystem: "cc.focuswave.Flowease", category: "CameraService")

    /// カメラデバイスマネージャー（内部実装）
    private let deviceManager = CameraDeviceManager()

    /// 現在のカメラ権限状態
    var authorizationStatus: CameraAuthorizationStatus {
        let avStatus = AVCaptureDevice.authorizationStatus(for: .video)
        return CameraAuthorizationStatus(from: avStatus)
    }

    /// フレームキャプチャ中かどうか
    private(set) var isCapturing = false

    /// フレームを受け取るデリゲート
    weak var frameDelegate: CameraFrameDelegate?

    /// 利用可能なカメラデバイス一覧
    var availableCameras: [CameraDevice] { deviceManager.availableCameras }

    /// 現在選択されているカメラのID（スタブ実装）
    var selectedCameraID: String? { nil }

    // MARK: - Capture Session Properties

    /// キャプチャセッション
    private var captureSession: AVCaptureSession?

    /// ビデオ出力
    private var videoOutput: AVCaptureVideoDataOutput?

    /// キャプチャ入力（クリーンアップ時に削除するために保持）
    private var captureInput: AVCaptureDeviceInput?

    /// キャプチャ処理用の専用キュー
    private let captureQueue = DispatchQueue(
        label: "cc.focuswave.Flowease.CameraCapture",
        qos: .userInitiated
    )

    /// フレームスキップカウンター（パフォーマンス最適化用、nonisolated でアクセスするため Atomic 使用）
    private let frameCounter = OSAllocatedUnfairLock(initialState: 0)

    /// 処理するフレームの間隔（2 = 2フレームに1回処理）
    private let frameProcessingInterval = 2

    // MARK: - Initialization

    override init() {
        super.init()
        deviceManager.setupDiscoverySession()
        logger.debug("CameraService initialized")
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

        // 先にフラグを下げて新しいフレーム処理を止める
        isCapturing = false
        let session = captureSession
        let output = videoOutput
        let input = captureInput

        captureSession = nil
        videoOutput = nil
        captureInput = nil
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
            if let input {
                session?.removeInput(input)
            }
            if let output {
                session?.removeOutput(output)
            }
            session?.commitConfiguration()

            // セッションを停止
            session?.stopRunning()
        }
        logger.info("Frame capture stopped")
    }

    /// カメラを選択（スタブ実装）
    /// - Parameter deviceID: 選択するカメラのuniqueID (nil でシステムデフォルト)
    func selectCamera(_ deviceID: String?) {
        logger.debug("selectCamera called with deviceID: \(deviceID ?? "nil") (stub implementation)")
    }

    // MARK: - Private Methods

    /// キャプチャセッションをセットアップ
    private func setupCaptureSession() throws {
        let session = AVCaptureSession()
        session.sessionPreset = .medium // 640x480 相当

        // カメラデバイスを取得
        guard let device = AVCaptureDevice.default(for: .video) else {
            throw CameraServiceError.noCameraAvailable
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

    // MARK: - Session Error Handlers

    /// セッションでランタイムエラーが発生した時に呼ばれる
    ///
    /// カメラが他のアプリで使用中の場合や、デバイスエラーが発生した場合に発火する。
    /// macOS では wasInterruptedNotification が利用できないため、この通知でエラーを検出する。
    @objc private func sessionRuntimeError(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let error = userInfo[AVCaptureSessionErrorKey] as? AVError else {
            return
        }

        Task { @MainActor [weak self] in
            guard let self else { return }

            // エラーの内容をログ出力
            logger.warning("Camera session error: code=\(error.code.rawValue), \(error.localizedDescription)")

            // エラーコードに基づいて適切な CameraServiceError を決定
            let cameraError: CameraServiceError = switch error.code {
            case .deviceInUseByAnotherApplication:
                // 他のアプリがカメラを使用中
                .cameraInUse
            default:
                // その他のエラー（セッション設定エラーとして扱う）
                .sessionConfigurationFailed
            }

            // セッションが停止している場合はリカバリーのためにクリーンアップ
            if let session = captureSession, !session.isRunning {
                // キャプチャ状態をリセットして再開可能にする
                isCapturing = false

                // セッションの参照をクリア（次回 startCapturing で新しいセッションを作成）
                captureSession = nil
                videoOutput = nil
                captureInput = nil
                frameCounter.withLock { $0 = 0 }

                // オブザーバーを削除
                NotificationCenter.default.removeObserver(
                    self,
                    name: AVCaptureSession.runtimeErrorNotification,
                    object: session
                )

                logger.info("Capture state reset due to session error")
                frameDelegate?.cameraService(self, didEncounterError: cameraError)
            } else if captureSession != nil {
                // セッションが実行中でもエラーが発生した場合は停止してクリーンアップ
                logger.warning("Stopping due to session runtime error")
                stopCapturing()
                frameDelegate?.cameraService(self, didEncounterError: cameraError)
            } else {
                // セッションが既に nil の場合（すでにクリーンアップ済み）
                frameDelegate?.cameraService(self, didEncounterError: cameraError)
            }
        }
    }
}

// MARK: - SendableSampleBuffer

/// CMSampleBuffer を Sendable としてラップするヘルパー
///
/// CMSampleBuffer は Core Foundation 型でスレッドセーフではないが、
/// カメラキャプチャからメインスレッドへの受け渡しは即時処理されるため安全。
/// nonisolated により非同期コンテキストからもアクセス可能。
private nonisolated struct SendableSampleBuffer: @unchecked Sendable {
    let buffer: CMSampleBuffer
}

// MARK: - CameraService + AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from _: AVCaptureConnection
    ) {
        // フレームスキップ（パフォーマンス最適化）
        let shouldProcess = frameCounter.withLock { counter -> Bool in
            counter += 1
            return counter % frameProcessingInterval == 0
        }
        guard shouldProcess else {
            return
        }

        // Sendable ラッパーでメインスレッドに送信
        let sendableBuffer = SendableSampleBuffer(buffer: sampleBuffer)

        // メインスレッドでデリゲートに通知
        Task { @MainActor [weak self] in
            guard let self, isCapturing else { return }
            frameDelegate?.cameraService(self, didCaptureFrame: sendableBuffer.buffer)
        }
    }

    nonisolated func captureOutput(
        _: AVCaptureOutput,
        didDrop _: CMSampleBuffer,
        from _: AVCaptureConnection
    ) {
        // フレームがドロップされた場合は警告ログ（過剰にならないよう制限）
        Task { @MainActor [weak self] in
            self?.logger.debug("Frame dropped")
        }
    }
}
