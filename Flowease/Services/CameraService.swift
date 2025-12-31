// CameraService.swift
// Flowease
//
// カメラ権限の管理とフレームキャプチャを担当するサービス

import AVFoundation
import CoreVideo
import OSLog

// MARK: - CameraAuthorizationStatus

/// カメラ権限の状態
/// AVAuthorizationStatus をアプリ内で扱いやすい形にラップ
enum CameraAuthorizationStatus: Sendable, Equatable {
    /// カメラアクセスが許可されている
    case authorized

    /// カメラアクセスが拒否されている
    case denied

    /// カメラアクセスが制限されている（ペアレンタルコントロール等）
    case restricted

    /// まだ権限を要求していない
    case notDetermined

    /// AVAuthorizationStatus から変換
    init(from avStatus: AVAuthorizationStatus) {
        switch avStatus {
        case .authorized:
            self = .authorized
        case .denied:
            self = .denied
        case .restricted:
            self = .restricted
        case .notDetermined:
            self = .notDetermined
        @unknown default:
            self = .denied
        }
    }
}

// MARK: - CameraFrameDelegate

/// カメラフレームを受け取るデリゲートプロトコル
@MainActor
protocol CameraFrameDelegate: AnyObject {
    /// フレームがキャプチャされた時に呼ばれる
    /// - Parameters:
    ///   - service: フレームを提供した CameraService
    ///   - pixelBuffer: キャプチャされたフレームのピクセルバッファ
    func cameraService(_ service: any CameraServiceProtocol, didCaptureFrame pixelBuffer: CVPixelBuffer)

    /// エラーが発生した時に呼ばれる
    /// - Parameters:
    ///   - service: エラーが発生した CameraService
    ///   - error: 発生したエラー
    func cameraService(_ service: any CameraServiceProtocol, didEncounterError error: Error)
}

// MARK: - CameraServiceProtocol

/// カメラサービスのプロトコル
/// テスト時にモックへ差し替え可能
@MainActor
protocol CameraServiceProtocol: AnyObject, Sendable {
    /// 現在のカメラ権限状態
    var authorizationStatus: CameraAuthorizationStatus { get }

    /// フレームキャプチャ中かどうか
    var isCapturing: Bool { get }

    /// フレームを受け取るデリゲート
    var frameDelegate: CameraFrameDelegate? { get set }

    /// カメラ権限をリクエスト
    /// - Returns: リクエスト後の権限状態
    func requestAuthorization() async -> CameraAuthorizationStatus

    /// カメラデバイスが利用可能かチェック
    /// - Returns: カメラが利用可能な場合は true
    func checkCameraAvailability() -> Bool

    /// 現在の権限状態を MonitoringState に変換
    /// - Returns: 対応する MonitoringState
    func toMonitoringState() -> MonitoringState

    /// フレームキャプチャを開始
    func startCapturing()

    /// フレームキャプチャを停止
    func stopCapturing()
}

// MARK: - CameraServiceError

/// CameraService のエラー型
enum CameraServiceError: Error, Sendable, Equatable {
    /// カメラデバイスが利用できない
    case noCameraAvailable
    /// カメラ権限がない
    case permissionDenied
    /// セッションの設定に失敗
    case sessionConfigurationFailed
    /// 他のアプリがカメラを使用中
    case cameraInUse
}

// MARK: - CameraService

/// カメラ権限管理とフレームキャプチャの実装
@MainActor
final class CameraService: NSObject, CameraServiceProtocol {
    // MARK: - Properties

    private let logger = Logger(subsystem: "cc.focuswave.Flowease", category: "CameraService")

    /// 現在のカメラ権限状態
    var authorizationStatus: CameraAuthorizationStatus {
        let avStatus = AVCaptureDevice.authorizationStatus(for: .video)
        return CameraAuthorizationStatus(from: avStatus)
    }

    /// フレームキャプチャ中かどうか
    private(set) var isCapturing = false

    /// フレームを受け取るデリゲート
    weak var frameDelegate: CameraFrameDelegate?

    // MARK: - Capture Session Properties

    /// キャプチャセッション
    private var captureSession: AVCaptureSession?

    /// ビデオ出力
    private var videoOutput: AVCaptureVideoDataOutput?

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
        logger.debug("CameraService 初期化完了")
    }

    // MARK: - Public Methods

    /// カメラ権限をリクエスト
    /// - Returns: リクエスト後の権限状態
    func requestAuthorization() async -> CameraAuthorizationStatus {
        let currentStatus = authorizationStatus

        // 既に決定済みの場合はそのまま返す
        guard currentStatus == .notDetermined else {
            logger.info("カメラ権限は既に決定済み: \(String(describing: currentStatus))")
            return currentStatus
        }

        logger.info("カメラ権限をリクエスト中...")

        // 権限リクエストを実行
        let granted = await AVCaptureDevice.requestAccess(for: .video)

        let newStatus = authorizationStatus
        logger.info("カメラ権限リクエスト結果: granted=\(granted), status=\(String(describing: newStatus))")

        return newStatus
    }

    /// カメラデバイスが利用可能かチェック
    /// - Returns: カメラが利用可能な場合は true
    func checkCameraAvailability() -> Bool {
        let device = AVCaptureDevice.default(for: .video)
        let isAvailable = device != nil
        logger.debug("カメラデバイス利用可能: \(isAvailable)")
        return isAvailable
    }

    /// 現在の権限状態を MonitoringState に変換
    /// - Returns: 対応する MonitoringState
    func toMonitoringState() -> MonitoringState {
        // カメラデバイスが存在しない場合
        if !checkCameraAvailability() {
            logger.warning("カメラデバイスが利用不可")
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
            logger.debug("既にキャプチャ中")
            return
        }

        guard authorizationStatus == .authorized else {
            logger.warning("カメラ権限がないためキャプチャを開始できません")
            frameDelegate?.cameraService(self, didEncounterError: CameraServiceError.permissionDenied)
            return
        }

        guard checkCameraAvailability() else {
            logger.warning("カメラデバイスが利用できないためキャプチャを開始できません")
            frameDelegate?.cameraService(self, didEncounterError: CameraServiceError.noCameraAvailable)
            return
        }

        do {
            try setupCaptureSession()
            let session = captureSession
            // startRunning() はブロッキング呼び出しなのでバックグラウンドで実行
            captureQueue.async { [weak self] in
                session?.startRunning()
                Task { @MainActor in
                    self?.isCapturing = true
                    self?.logger.info("フレームキャプチャを開始しました")
                }
            }
        } catch {
            logger.error("キャプチャセッションのセットアップに失敗: \(error.localizedDescription)")
            frameDelegate?.cameraService(self, didEncounterError: error)
        }
    }

    /// フレームキャプチャを停止
    func stopCapturing() {
        guard isCapturing else {
            logger.debug("キャプチャは既に停止中")
            return
        }

        // 先にフラグを下げて新しいフレーム処理を止める
        isCapturing = false
        let session = captureSession
        captureSession = nil
        videoOutput = nil
        frameCounter.withLock { $0 = 0 }

        // stopRunning() はブロッキング呼び出しなのでバックグラウンドで実行
        captureQueue.async {
            session?.stopRunning()
        }
        logger.info("フレームキャプチャを停止しました")
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
            logger.error("カメラ入力の作成に失敗: \(error.localizedDescription)")
            throw CameraServiceError.sessionConfigurationFailed
        }

        guard session.canAddInput(input) else {
            logger.error("セッションに入力を追加できません")
            throw CameraServiceError.sessionConfigurationFailed
        }
        session.addInput(input)

        // 出力を追加
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: captureQueue)

        guard session.canAddOutput(output) else {
            logger.error("セッションに出力を追加できません")
            throw CameraServiceError.sessionConfigurationFailed
        }
        session.addOutput(output)

        captureSession = session
        videoOutput = output

        logger.debug("キャプチャセッションをセットアップしました")
    }
}

// MARK: - SendablePixelBuffer

/// CVPixelBuffer を Sendable としてラップするヘルパー
///
/// CVPixelBuffer は Core Foundation 型でスレッドセーフではないが、
/// カメラキャプチャからメインスレッドへの受け渡しは即時処理されるため安全。
/// nonisolated により非同期コンテキストからもアクセス可能。
private nonisolated struct SendablePixelBuffer: @unchecked Sendable {
    let buffer: CVPixelBuffer
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

        // ピクセルバッファを取得
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        // Sendable ラッパーでメインスレッドに送信
        let sendableBuffer = SendablePixelBuffer(buffer: pixelBuffer)

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
            self?.logger.debug("フレームがドロップされました")
        }
    }
}
