// CameraServiceProtocol.swift
// Flowease
//
// カメラサービスのプロトコルと関連型

@preconcurrency import AVFoundation

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
    ///   - sampleBuffer: キャプチャされたフレームのサンプルバッファ
    func cameraService(_ service: any CameraServiceProtocol, didCaptureFrame sampleBuffer: CMSampleBuffer)

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
    /// 利用可能なカメラデバイス一覧
    var availableCameras: [CameraDevice] { get }
    /// 現在選択されているカメラのID
    var selectedCameraID: String? { get }

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
    /// カメラを選択
    /// - Parameter deviceID: 選択するカメラのuniqueID (nil でシステムデフォルト)
    func selectCamera(_ deviceID: String?)
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
    /// 選択されたカメラが切断された
    case selectedCameraDisconnected
    /// 選択されたカメラが失敗し、システムデフォルトにフォールバックした
    case selectedCameraFailed

    /// MonitoringStateへの変換
    /// selectedCameraFailedはフォールバック成功を意味するためnilを返す
    var asMonitoringState: MonitoringState? {
        switch self {
        case .noCameraAvailable:
            .disabled(.noCameraAvailable)
        case .permissionDenied:
            .disabled(.cameraPermissionDenied)
        case .cameraInUse:
            .paused(.cameraInUse)
        case .sessionConfigurationFailed:
            .paused(.cameraInitializing)
        case .selectedCameraDisconnected:
            .paused(.selectedCameraDisconnected)
        case .selectedCameraFailed:
            nil // フォールバック成功、状態変更なし
        }
    }
}
