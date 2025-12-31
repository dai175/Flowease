// CameraService.swift
// Flowease
//
// カメラ権限の管理とデバイスアクセスを担当するサービス

import AVFoundation
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

// MARK: - CameraServiceProtocol

/// カメラサービスのプロトコル
/// テスト時にモックへ差し替え可能
@MainActor
protocol CameraServiceProtocol: AnyObject, Sendable {
    /// 現在のカメラ権限状態
    var authorizationStatus: CameraAuthorizationStatus { get }

    /// カメラ権限をリクエスト
    /// - Returns: リクエスト後の権限状態
    func requestAuthorization() async -> CameraAuthorizationStatus

    /// カメラデバイスが利用可能かチェック
    /// - Returns: カメラが利用可能な場合は true
    func checkCameraAvailability() -> Bool
}

// MARK: - CameraService

/// カメラ権限管理の実装
@MainActor
final class CameraService: CameraServiceProtocol {
    // MARK: - Properties

    private let logger = Logger(subsystem: "cc.focuswave.Flowease", category: "CameraService")

    /// 現在のカメラ権限状態
    var authorizationStatus: CameraAuthorizationStatus {
        let avStatus = AVCaptureDevice.authorizationStatus(for: .video)
        return CameraAuthorizationStatus(from: avStatus)
    }

    // MARK: - Initialization

    init() {
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
}
