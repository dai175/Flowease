import AVFoundation
import Combine
import CoreVideo
import Foundation

/// カメラサービスプロトコル
public protocol CameraServiceProtocol: AnyObject {
    // MARK: - Properties

    /// 利用可能なカメラ一覧
    var availableCameras: [CameraDevice] { get }

    /// 現在選択されているカメラ
    var currentCamera: CameraDevice? { get }

    /// カメラがアクティブか
    var isActive: Bool { get }

    /// カメラフレームのPublisher
    var framePublisher: AnyPublisher<CVPixelBuffer, Never> { get }

    // MARK: - Methods

    /// カメラアクセス権限を確認
    /// - Returns: 権限状態
    func checkAuthorization() async -> AVAuthorizationStatus

    /// カメラアクセス権限をリクエスト
    /// - Returns: 許可されたか
    func requestAuthorization() async -> Bool

    /// カメラを開始
    /// - Parameter deviceID: デバイスID（nilの場合は自動選択）
    /// - Throws: カメラエラー
    func startCamera(deviceID: String?) async throws

    /// カメラを停止
    func stopCamera() async

    /// カメラを切り替え
    /// - Parameter deviceID: 新しいカメラのデバイスID
    func switchCamera(to deviceID: String) async throws

    /// 利用可能なカメラ一覧を更新
    func refreshAvailableCameras()
}
