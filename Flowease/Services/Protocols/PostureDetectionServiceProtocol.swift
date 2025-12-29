import Combine
import CoreVideo
import Foundation

/// 姿勢検知サービスプロトコル
public protocol PostureDetectionServiceProtocol: AnyObject {

    // MARK: - Properties

    /// 現在の姿勢状態（リアルタイム更新）
    var currentPosture: CurrentValueSubject<PostureState?, Never> { get }

    /// 検知が実行中か
    var isDetecting: Bool { get }

    // MARK: - Methods

    /// 姿勢検知を開始
    /// - Parameter cameraDeviceID: 使用するカメラのデバイスID（nilの場合は自動選択）
    /// - Throws: カメラアクセスエラー、Vision Frameworkエラー
    func startDetection(cameraDeviceID: String?) async throws

    /// 姿勢検知を停止
    func stopDetection()

    /// 単一フレームから姿勢を検知（テスト用）
    /// - Parameter pixelBuffer: カメラからのフレーム
    /// - Returns: 検知結果
    func detectPosture(from pixelBuffer: CVPixelBuffer) async throws -> PostureState

    /// 姿勢判定の閾値を更新
    /// - Parameters:
    ///   - forwardLeanThreshold: 前かがみ閾値（度）
    ///   - neckTiltThreshold: 首傾き閾値（度）
    func updateThresholds(forwardLeanThreshold: Double, neckTiltThreshold: Double)
}
