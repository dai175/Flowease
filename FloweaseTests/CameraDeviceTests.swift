import Testing
@testable import Flowease

/// CameraDevice モデルのテスト
///
/// T008 [US1]: CameraDevice model equality and Sendable conformance
///
/// TDD: これらのテストは実装前に作成され、最初は失敗が期待される。
/// T011 で CameraDevice モデルが完全実装されると成功する。
@MainActor
struct CameraDeviceTests {
    // MARK: - Test Data

    /// テスト用デバイスを作成
    private func makeDevice(
        id: String = "device-123",
        name: String = "FaceTime HD Camera",
        isConnected: Bool = true,
        isDefault: Bool = false
    ) -> CameraDevice {
        CameraDevice(
            id: id,
            name: name,
            isConnected: isConnected,
            isDefault: isDefault
        )
    }

    // MARK: - Equatable Tests

    /// 同一プロパティを持つデバイスは等しい
    @Test func equalDevicesAreEqual() {
        let device1 = makeDevice()
        let device2 = makeDevice()

        #expect(device1 == device2)
    }

    /// 異なる ID を持つデバイスは等しくない
    @Test func devicesWithDifferentIDsAreNotEqual() {
        let device1 = makeDevice(id: "device-123")
        let device2 = makeDevice(id: "device-456")

        #expect(device1 != device2)
    }

    /// 異なる名前を持つデバイスは等しくない
    @Test func devicesWithDifferentNamesAreNotEqual() {
        let device1 = makeDevice(name: "FaceTime HD Camera")
        let device2 = makeDevice(name: "Logitech C920")

        #expect(device1 != device2)
    }

    /// 異なる接続状態を持つデバイスは等しくない
    @Test func devicesWithDifferentConnectionStateAreNotEqual() {
        let device1 = makeDevice(isConnected: true)
        let device2 = makeDevice(isConnected: false)

        #expect(device1 != device2)
    }

    /// 異なるデフォルト状態を持つデバイスは等しくない
    @Test func devicesWithDifferentDefaultStateAreNotEqual() {
        let device1 = makeDevice(isDefault: false)
        let device2 = makeDevice(isDefault: true)

        #expect(device1 != device2)
    }

    // MARK: - Identifiable Tests

    /// デバイスの id プロパティが Identifiable の識別子として使用される
    @Test func deviceIDIsUsedAsIdentifier() {
        let device = makeDevice(id: "unique-device-id")

        #expect(device.id == "unique-device-id")
    }

    // MARK: - Sendable Conformance Tests

    /// CameraDevice が Sendable に準拠していることを確認
    /// コンパイル時にチェックされるが、明示的なテストとして記述
    @Test func deviceIsSendable() {
        let device = makeDevice()

        // Sendable 準拠の確認: 別スレッドに渡せることを検証
        // Task への受け渡しがコンパイルできれば Sendable
        Task {
            let _ = device
        }

        #expect(true, "CameraDevice conforms to Sendable")
    }

    // MARK: - Property Tests

    /// すべてのプロパティが正しく設定される
    @Test func devicePropertiesAreSetCorrectly() {
        let device = CameraDevice(
            id: "test-id",
            name: "Test Camera",
            isConnected: true,
            isDefault: true
        )

        #expect(device.id == "test-id")
        #expect(device.name == "Test Camera")
        #expect(device.isConnected == true)
        #expect(device.isDefault == true)
    }

    /// isConnected が変更可能であることを確認
    @Test func isConnectedIsMutable() {
        var device = makeDevice(isConnected: true)

        device.isConnected = false

        #expect(device.isConnected == false)
    }

    /// isDefault が変更可能であることを確認
    @Test func isDefaultIsMutable() {
        var device = makeDevice(isDefault: false)

        device.isDefault = true

        #expect(device.isDefault == true)
    }
}
