import AVFoundation
import Foundation

/// カメラデバイスモデル
public struct CameraDevice: Identifiable, Sendable {
    /// デバイスの一意識別子
    public let id: String

    /// デバイス名
    public let name: String

    /// 内蔵カメラか
    public let isBuiltIn: Bool

    /// デバイスの位置
    public let position: AVCaptureDevice.Position

    public init(
        id: String,
        name: String,
        isBuiltIn: Bool,
        position: AVCaptureDevice.Position
    ) {
        self.id = id
        self.name = name
        self.isBuiltIn = isBuiltIn
        self.position = position
    }

    /// AVCaptureDeviceから初期化
    public init(from device: AVCaptureDevice) {
        self.id = device.uniqueID
        self.name = device.localizedName
        self.isBuiltIn = device.deviceType == .builtInWideAngleCamera
        self.position = device.position
    }
}

// MARK: - Hashable

extension CameraDevice: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: CameraDevice, rhs: CameraDevice) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Description

extension CameraDevice: CustomStringConvertible {
    public var description: String {
        "\(name) (\(isBuiltIn ? "内蔵" : "外部"))"
    }
}
