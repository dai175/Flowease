//
//  CameraService.swift
//  Flowease
//
//  Created by Daisuke Ooba on 2025/12/29.
//

import AVFoundation
import Combine
import CoreVideo
import Foundation

/// カメラサービスの実装
/// AVFoundation を使用してカメラの制御とフレーム取得を行う
@MainActor
public final class CameraService: NSObject, CameraServiceProtocol {
    // MARK: - Properties

    /// 利用可能なカメラ一覧
    public private(set) var availableCameras: [CameraDevice] = []

    /// 現在選択されているカメラ
    public private(set) var currentCamera: CameraDevice?

    /// カメラがアクティブか
    public private(set) var isActive = false

    /// カメラフレームのPublisher
    public var framePublisher: AnyPublisher<CVPixelBuffer, Never> {
        frameSubject.eraseToAnyPublisher()
    }

    // MARK: - Private Properties

    /// フレーム送信用のSubject
    private let frameSubject = PassthroughSubject<CVPixelBuffer, Never>()

    /// キャプチャセッション
    private var captureSession: AVCaptureSession?

    /// ビデオ出力
    private var videoOutput: AVCaptureVideoDataOutput?

    /// フレーム処理用のキュー
    private let sessionQueue = DispatchQueue(label: "cc.focuswave.Flowease.CameraService.session")
    private let videoOutputQueue = DispatchQueue(
        label: "cc.focuswave.Flowease.CameraService.videoOutput"
    )

    // MARK: - Initialization

    override public init() {
        super.init()
        refreshAvailableCameras()
    }

    // MARK: - CameraServiceProtocol

    /// カメラアクセス権限を確認
    /// - Returns: 権限状態
    public func checkAuthorization() async -> AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .video)
    }

    /// カメラアクセス権限をリクエスト
    /// - Returns: 許可されたか
    public func requestAuthorization() async -> Bool {
        let status = await checkAuthorization()

        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    /// カメラを開始
    /// - Parameter deviceID: デバイスID（nilの場合は自動選択）
    /// - Throws: カメラエラー
    public func startCamera(deviceID: String?) async throws {
        // 権限チェック
        let authorized = await requestAuthorization()
        guard authorized else {
            throw CameraError.accessDenied
        }

        // 既に実行中の場合はエラー
        if isActive {
            throw CameraError.alreadyRunning
        }

        // カメラリストを更新
        refreshAvailableCameras()

        // デバイスを選択
        let device: AVCaptureDevice?
        if let deviceID = deviceID {
            device = AVCaptureDevice(uniqueID: deviceID)
            if device == nil {
                throw CameraError.deviceNotFound(deviceID: deviceID)
            }
        } else {
            // デフォルトカメラを選択
            device = AVCaptureDevice.default(for: .video)
        }

        guard let selectedDevice = device else {
            throw CameraError.deviceNotFound(deviceID: deviceID ?? "default")
        }

        // セッションを設定
        try await configureSession(with: selectedDevice)

        // カメラ情報を更新
        currentCamera = CameraDevice(from: selectedDevice)

        // セッションを開始
        await startSession()
    }

    /// カメラを停止
    public func stopCamera() {
        sessionQueue.async { [weak self] in
            self?.captureSession?.stopRunning()
            Task { @MainActor in
                self?.isActive = false
                self?.currentCamera = nil
            }
        }
    }

    /// カメラを切り替え
    /// - Parameter deviceID: 新しいカメラのデバイスID
    public func switchCamera(to deviceID: String) async throws {
        stopCamera()
        try await startCamera(deviceID: deviceID)
    }

    /// 利用可能なカメラ一覧を更新
    public func refreshAvailableCameras() {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .externalUnknown],
            mediaType: .video,
            position: .unspecified
        )

        availableCameras = discoverySession.devices.map { CameraDevice(from: $0) }
    }

    // MARK: - Private Methods

    /// セッションを設定
    private func configureSession(with device: AVCaptureDevice) async throws {
        let session = AVCaptureSession()

        session.beginConfiguration()

        // 解像度を設定
        session.sessionPreset = Constants.Camera.sessionPreset

        // 入力を追加
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            } else {
                session.commitConfiguration()
                throw CameraError.inputAddFailed
            }
        } catch let error as CameraError {
            session.commitConfiguration()
            throw error
        } catch {
            session.commitConfiguration()
            throw CameraError.startFailed(error)
        }

        // 出力を追加
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        ]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: videoOutputQueue)

        if session.canAddOutput(output) {
            session.addOutput(output)
        } else {
            session.commitConfiguration()
            throw CameraError.outputAddFailed
        }

        // フレームレートを設定
        configureFrameRate(for: device)

        session.commitConfiguration()

        captureSession = session
        videoOutput = output
    }

    /// フレームレートを設定
    private func configureFrameRate(for device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()

            let frameRate = CMTimeMake(value: 1, timescale: Constants.Camera.frameRate)
            device.activeVideoMinFrameDuration = frameRate
            device.activeVideoMaxFrameDuration = frameRate

            device.unlockForConfiguration()
        } catch {
            // フレームレート設定に失敗してもカメラ自体は動作可能
            print("Warning: Failed to configure frame rate: \(error.localizedDescription)")
        }
    }

    /// セッションを開始
    private func startSession() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            sessionQueue.async { [weak self] in
                self?.captureSession?.startRunning()
                Task { @MainActor in
                    self?.isActive = true
                }
                continuation.resume()
            }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    public nonisolated func captureOutput(
        _: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from _: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        frameSubject.send(pixelBuffer)
    }
}
