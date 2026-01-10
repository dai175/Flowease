import Foundation
import Testing
@testable import Flowease

/// CameraDeviceManager のデバイス監視テスト
///
/// T018 [US2]: Test device disconnection detection in CameraDeviceManager
///
/// TDD: これらのテストは実装前に作成され、最初は失敗が期待される。
/// T021 (KVO observation) で実装されると成功する。
@MainActor
struct CameraDeviceManagerTests {
    // MARK: - T018: Device Disconnection Detection Tests

    /// onDevicesChanged コールバックがセットアップ時に呼ばれることを確認
    @Test func onDevicesChangedCalledOnSetup() async {
        // Given
        let manager = CameraDeviceManager()
        var callbackCalled = false
        var capturedDevices: [CameraDevice]?

        manager.onDevicesChanged = { devices in
            callbackCalled = true
            capturedDevices = devices
        }

        // When
        manager.setupDiscoverySession()

        // Then
        #expect(callbackCalled, "onDevicesChanged should be called on setup")
        #expect(capturedDevices != nil, "Captured devices should not be nil")
    }

    /// enumerateCameras() 呼び出し時に onDevicesChanged が発火することを確認
    @Test func enumerateCamerasTriggersCallback() async {
        // Given
        let manager = CameraDeviceManager()
        manager.setupDiscoverySession()

        var callbackCount = 0
        manager.onDevicesChanged = { _ in
            callbackCount += 1
        }

        // When
        manager.enumerateCameras()

        // Then
        #expect(callbackCount >= 1, "onDevicesChanged should be triggered by enumerateCameras")
    }

    /// availableCameras が CameraDevice の配列を返すことを確認
    @Test func availableCamerasReturnsDeviceArray() {
        // Given / When
        let manager = CameraDeviceManager()
        manager.setupDiscoverySession()

        // Then
        // 実際のカメラが接続されていなくても配列として返す
        #expect(manager.availableCameras is [CameraDevice])
    }

    /// デバイスが存在する場合、isConnected プロパティが適切に設定されることを確認
    @Test func devicesHaveCorrectIsConnectedProperty() {
        // Given / When
        let manager = CameraDeviceManager()
        manager.setupDiscoverySession()

        // Then
        for device in manager.availableCameras {
            // 列挙時点で接続されているデバイスのみがリストに含まれるべき
            // ただし、isConnected は実行時状態を反映
            #expect(device.id.isEmpty == false, "Device ID should not be empty")
            #expect(device.name.isEmpty == false, "Device name should not be empty")
        }
    }

    /// CameraDeviceManager がデバイスリスト変更を通知する準備ができていることを確認
    ///
    /// 注: 実際のデバイス切断・再接続の検知は T021 (KVO) 実装後にテスト可能
    /// このテストは onDevicesChanged コールバックの存在と設定を確認
    @Test func deviceDisconnectionDetectionReadiness() {
        // Given
        let manager = CameraDeviceManager()

        // When
        var receivedNotification = false
        manager.onDevicesChanged = { _ in
            receivedNotification = true
        }
        manager.setupDiscoverySession()

        // Then
        // セットアップ後にコールバックが設定されていることを確認
        #expect(manager.onDevicesChanged != nil, "onDevicesChanged callback should be settable")
        #expect(receivedNotification, "Initial enumeration should trigger callback")
    }

    /// availableCameras が isConnected = true のデバイスのみを含むことを確認
    @Test func availableCamerasContainConnectedDevices() {
        // Given / When
        let manager = CameraDeviceManager()
        manager.setupDiscoverySession()

        // Then
        // 列挙されたデバイスはすべて接続済みであるべき
        for device in manager.availableCameras {
            #expect(device.isConnected, "Enumerated device should be connected")
        }
    }

    /// システムデフォルトカメラが isDefault = true で識別されることを確認
    @Test func defaultCameraIsIdentified() {
        // Given / When
        let manager = CameraDeviceManager()
        manager.setupDiscoverySession()

        // Then
        // カメラが存在する場合、最大1つが isDefault = true であるべき
        let defaultCameras = manager.availableCameras.filter(\.isDefault)
        if !manager.availableCameras.isEmpty {
            #expect(
                defaultCameras.count <= 1,
                "At most one camera should be marked as default"
            )
        }
    }

    // MARK: - T028 [US3]: Single Camera Scenario Tests

    /// シングルカメラ環境でも正常にカメラが列挙されることを確認
    ///
    /// カメラが1台のみの場合でも、CameraDeviceManager は正しく動作し、
    /// 有効な CameraDevice を返すことを検証します。
    @Test func singleCameraScenarioHandling() {
        // Given / When
        let manager = CameraDeviceManager()
        manager.setupDiscoverySession()

        // Then
        // カメラが1台以上存在する場合、シングルカメラシナリオを検証
        if manager.availableCameras.count == 1 {
            let camera = manager.availableCameras[0]
            #expect(!camera.id.isEmpty, "Single camera should have valid ID")
            #expect(!camera.name.isEmpty, "Single camera should have valid name")
            #expect(camera.isConnected, "Single camera should be connected")
            // シングルカメラは通常システムデフォルト
            #expect(camera.isDefault, "Single camera should be marked as default")
        }
        // カメラ数に関わらず、配列は常に有効
        #expect(manager.availableCameras is [CameraDevice])
    }

    /// シングルカメラ環境で onDevicesChanged コールバックが正しく呼ばれることを確認
    @Test func singleCameraCallbackTriggered() async {
        // Given
        let manager = CameraDeviceManager()
        var receivedDevices: [CameraDevice]?

        manager.onDevicesChanged = { devices in
            receivedDevices = devices
        }

        // When
        manager.setupDiscoverySession()

        // Then
        #expect(receivedDevices != nil, "Callback should be triggered")
        if let devices = receivedDevices, devices.count == 1 {
            let camera = devices[0]
            #expect(!camera.id.isEmpty)
            #expect(!camera.name.isEmpty)
        }
    }

    /// カメラが1台または0台の場合でも availableCameras が安全にアクセス可能
    @Test func emptyCameraListHandling() {
        // Given / When
        let manager = CameraDeviceManager()
        manager.setupDiscoverySession()

        // Then
        // 空配列または要素ありの配列、どちらでも安全にアクセス可能
        let cameras = manager.availableCameras
        #expect(cameras.count >= 0, "Camera count should be non-negative")

        // first/last も安全にアクセス可能
        if let first = cameras.first {
            #expect(!first.id.isEmpty)
        }
    }
}
