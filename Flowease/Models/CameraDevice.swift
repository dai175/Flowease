import Foundation

/// カメラデバイスを表すモデル
///
/// AVCaptureDevice のラッパーとして機能し、UI表示に必要な情報を提供します。
/// Sendable に準拠しており、並行処理環境で安全に使用できます。
struct CameraDevice: Identifiable, Equatable {
    /// デバイスの一意識別子（AVCaptureDevice.uniqueID）
    let id: String

    /// デバイス名（AVCaptureDevice.localizedName）
    let name: String

    /// 接続状態
    var isConnected: Bool

    /// システムデフォルトカメラかどうか
    var isDefault: Bool
}
