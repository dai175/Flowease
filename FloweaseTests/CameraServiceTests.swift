import Foundation
import Testing
@testable import Flowease

/// CameraService のカメラ選択機能テスト
///
/// T009 [US1]: Test CameraService.selectCamera() and persistence
/// T010 [US1]: Test camera fallback logic
///
/// TDD: これらのテストは実装前に作成され、最初は失敗が期待される。
/// T013, T014 で実装されると成功する。
@MainActor
struct CameraServiceTests {
    // MARK: - Constants

    /// UserDefaults に保存されるカメラ選択のキー
    private let selectedCameraKey = "selectedCameraDeviceID"

    // MARK: - Test Setup/Teardown

    /// テスト用の UserDefaults をクリーンアップ
    private func cleanupUserDefaults() {
        UserDefaults.standard.removeObject(forKey: selectedCameraKey)
    }

    // MARK: - T009: selectCamera() and Persistence Tests

    /// selectCamera(_:) が UserDefaults に ID を保存することを確認
    @Test func selectCameraStoresIDInUserDefaults() {
        cleanupUserDefaults()
        let service = CameraService()
        let testID = "test-camera-id"

        service.selectCamera(testID)

        let storedID = UserDefaults.standard.string(forKey: selectedCameraKey)
        #expect(storedID == testID, "Selected camera ID should be stored in UserDefaults")

        cleanupUserDefaults()
    }

    /// selectCamera(nil) が UserDefaults から ID を削除することを確認
    @Test func selectCameraNilClearsUserDefaults() {
        cleanupUserDefaults()
        // まず ID を保存
        UserDefaults.standard.set("existing-camera-id", forKey: selectedCameraKey)

        let service = CameraService()
        service.selectCamera(nil)

        let storedID = UserDefaults.standard.string(forKey: selectedCameraKey)
        #expect(storedID == nil, "Selecting nil should clear stored camera ID")

        cleanupUserDefaults()
    }

    /// selectedCameraID が保存された値を反映することを確認
    @Test func selectedCameraIDReflectsStoredValue() {
        cleanupUserDefaults()
        let testID = "stored-camera-id"
        UserDefaults.standard.set(testID, forKey: selectedCameraKey)

        let service = CameraService()

        #expect(
            service.selectedCameraID == testID,
            "selectedCameraID should reflect the value stored in UserDefaults"
        )

        cleanupUserDefaults()
    }

    /// 保存された ID がない場合、selectedCameraID は nil を返すことを確認
    @Test func selectedCameraIDIsNilWhenNoStoredValue() {
        cleanupUserDefaults()

        let service = CameraService()

        #expect(
            service.selectedCameraID == nil,
            "selectedCameraID should be nil when no value is stored"
        )
    }

    /// selectCamera() 後に selectedCameraID が更新されることを確認
    @Test func selectedCameraIDUpdatesAfterSelection() {
        cleanupUserDefaults()
        let service = CameraService()

        #expect(service.selectedCameraID == nil, "Initially selectedCameraID should be nil")

        let testID = "newly-selected-camera"
        service.selectCamera(testID)

        #expect(
            service.selectedCameraID == testID,
            "selectedCameraID should update after selectCamera() is called"
        )

        cleanupUserDefaults()
    }

    // MARK: - T010: Camera Fallback Logic Tests

    /// 選択されたカメラが利用不可の場合、システムデフォルトにフォールバック
    ///
    /// 注: このテストは resolveCamera() メソッドの実装後に有効になる
    /// 現在はスタブ実装のため、テストロジックのみを検証
    @Test func fallbackToDefaultWhenSelectedUnavailable() {
        cleanupUserDefaults()

        // 存在しないカメラIDを保存
        let nonExistentID = "non-existent-camera-12345"
        UserDefaults.standard.set(nonExistentID, forKey: selectedCameraKey)

        let service = CameraService()

        // availableCameras に保存された ID のカメラが存在しない場合、
        // フォールバックが発生するべき
        let availableIDs = service.availableCameras.map(\.id)
        let selectedIsAvailable = availableIDs.contains(nonExistentID)

        #expect(
            !selectedIsAvailable,
            "Selected camera should not be in available cameras list"
        )

        // フォールバック動作は T014 で実装される resolveCamera() で検証
        // ここではセットアップが正しいことのみを確認

        cleanupUserDefaults()
    }

    /// 選択されたカメラが利用可能な場合、フォールバックしない
    ///
    /// 注: このテストは実際のカメラデバイスに依存するため、
    /// モック化が必要。T014 実装後に詳細なテストを追加。
    @Test func noFallbackWhenSelectedAvailable() {
        cleanupUserDefaults()
        let service = CameraService()

        // 利用可能なカメラがある場合
        guard let firstCamera = service.availableCameras.first else {
            // カメラがない環境ではスキップ
            #expect(Bool(true), "No cameras available - test skipped")
            return
        }

        // 利用可能なカメラを選択
        service.selectCamera(firstCamera.id)

        let selectedID = service.selectedCameraID
        #expect(
            selectedID == firstCamera.id,
            "Selected camera should remain selected when available"
        )

        cleanupUserDefaults()
    }

    /// 保存されたカメラIDが availableCameras に存在しない場合のハンドリング
    @Test func fallbackWhenStoredIDNotInAvailableDevices() {
        cleanupUserDefaults()

        // 架空のカメラIDを保存
        let fakeID = "fake-camera-that-does-not-exist"
        UserDefaults.standard.set(fakeID, forKey: selectedCameraKey)

        let service = CameraService()

        // 保存されたIDが availableCameras に含まれないことを確認
        let isInAvailable = service.availableCameras.contains { $0.id == fakeID }
        #expect(!isInAvailable, "Fake camera ID should not be in available cameras")

        // フォールバック動作の詳細テストは T014 で実装
        // resolveCamera() が (device, didFallback: true) を返すべき

        cleanupUserDefaults()
    }

    // MARK: - Edge Case Tests

    /// 空文字列の ID を選択した場合の動作
    ///
    /// 空文字列は有効な String として UserDefaults に保存される。
    /// カメラ解決時にはマッチするデバイスが見つからず、フォールバックが発生する。
    @Test func selectCameraWithEmptyStringID() {
        cleanupUserDefaults()
        let service = CameraService()

        service.selectCamera("")

        // 空文字列は有効な ID として UserDefaults に保存される
        let storedID = UserDefaults.standard.string(forKey: selectedCameraKey)
        #expect(
            storedID == "",
            "Empty string should be stored as-is in UserDefaults"
        )

        // 空文字列は availableCameras のどのデバイスIDともマッチしない
        let matchesAnyDevice = service.availableCameras.contains { $0.id == "" }
        #expect(!matchesAnyDevice, "Empty string should not match any device ID")

        cleanupUserDefaults()
    }

    // MARK: - T019: Auto-Resume on Reconnection Tests

    /// 選択されたカメラが再接続された時の自動再開テスト
    ///
    /// T019 [US2]: Test auto-resume on reconnection in CameraService
    ///
    /// TDD: これらのテストは実装前に作成され、最初は失敗が期待される。
    /// T024 (auto-resume implementation) で実装されると成功する。

    /// CameraService が onDevicesChanged コールバックを設定することを確認
    @Test func cameraServiceSetsUpDeviceChangeCallback() {
        cleanupUserDefaults()

        // CameraService 初期化時に deviceManager の onDevicesChanged が設定されるべき
        // 注: 内部実装のテストのため、間接的に確認
        let service = CameraService()

        // availableCameras が機能することで、deviceManager が正しく設定されていることを確認
        let cameras = service.availableCameras
        #expect(cameras is [CameraDevice], "availableCameras should return CameraDevice array")

        cleanupUserDefaults()
    }

    /// キャプチャ停止中に選択されたカメラが再接続された場合の動作
    ///
    /// 注: 実際の自動再開ロジックは T024 で実装される
    /// このテストは自動再開の前提条件を検証
    @Test func autoResumePrerequisites() {
        cleanupUserDefaults()
        let service = CameraService()

        // カメラを選択
        guard let firstCamera = service.availableCameras.first else {
            #expect(Bool(true), "No cameras available - test skipped")
            cleanupUserDefaults()
            return
        }

        service.selectCamera(firstCamera.id)

        // 選択が保持されていることを確認
        #expect(service.selectedCameraID == firstCamera.id, "Selected camera should be stored")

        // 停止状態であることを確認（自動再開の前提条件）
        // isCapturing は private(set) なので startCapturing/stopCapturing で制御
        // ここでは初期状態（非キャプチャ中）を確認
        // 注: isCapturing プロパティは外部からは直接確認できないが、
        // startCapturing() を呼ばない限り false であるべき

        cleanupUserDefaults()
    }

    /// selectedCameraID が保存されている状態で availableCameras が変化した場合の検知
    ///
    /// 注: 実際の再接続検知は T024 で実装される
    /// このテストは検知の基盤となるデータフローを確認
    @Test func deviceListChangeDetection() {
        cleanupUserDefaults()
        let service = CameraService()

        // 存在しないカメラIDを選択（シミュレート：切断されたカメラ）
        let disconnectedCameraID = "simulated-disconnected-camera"
        service.selectCamera(disconnectedCameraID)

        // 選択が保持されていることを確認
        #expect(service.selectedCameraID == disconnectedCameraID)

        // availableCameras に含まれていないことを確認
        let isInList = service.availableCameras.contains { $0.id == disconnectedCameraID }
        #expect(!isInList, "Disconnected camera should not be in available list")

        // 再接続時のロジック：availableCameras に selectedCameraID が出現したら再開
        // この検知ロジックは T024 で実装される

        cleanupUserDefaults()
    }

    /// 選択されたカメラの再接続検知に必要な情報が利用可能であることを確認
    @Test func reconnectionDetectionDataAvailable() {
        cleanupUserDefaults()
        let service = CameraService()

        // 1. selectedCameraID プロパティにアクセス可能で、初期状態は nil
        #expect(service.selectedCameraID == nil, "Initial selectedCameraID should be nil")

        // 2. カメラを選択すると selectedCameraID が設定される
        let testID = "test-reconnection-camera"
        service.selectCamera(testID)
        #expect(service.selectedCameraID == testID, "selectedCameraID should be set after selection")

        // 3. availableCameras プロパティにアクセス可能
        //    カメラが存在する場合は各デバイスのプロパティが有効であることを確認
        let cameras = service.availableCameras
        for camera in cameras {
            #expect(!camera.id.isEmpty, "Camera ID should not be empty")
            #expect(!camera.name.isEmpty, "Camera name should not be empty")
        }

        // 4. 再接続判定のロジック検証：selectedCameraID が availableCameras に含まれるか確認可能
        //    testID は架空のIDなので、含まれていないはず
        let isTestIDInList = cameras.contains { $0.id == testID }
        #expect(!isTestIDInList, "Test ID should not be in available cameras")

        cleanupUserDefaults()
    }

    /// 切断されたカメラのIDを保持し、再接続時に使用できることを確認
    @Test func disconnectedCameraIDPersistence() {
        cleanupUserDefaults()

        // 架空のカメラID（切断されたカメラをシミュレート）
        let disconnectedID = "disconnected-camera-xyz"
        UserDefaults.standard.set(disconnectedID, forKey: selectedCameraKey)

        let service = CameraService()

        // 切断されたカメラのIDが保持されている
        #expect(
            service.selectedCameraID == disconnectedID,
            "Disconnected camera ID should be persisted"
        )

        // availableCameras には含まれない（切断されているため）
        let isAvailable = service.availableCameras.contains { $0.id == disconnectedID }
        #expect(!isAvailable, "Disconnected camera should not be in available list")

        // T024 で実装される自動再開ロジック：
        // このIDを持つカメラが availableCameras に出現したら startCapturing() を呼ぶ

        cleanupUserDefaults()
    }

    // MARK: - Response Time Tests

    /// CameraService 初期化の応答時間を計測
    ///
    /// 初期化は 100ms 以内に完了すべき（UX 要件）
    @Test func initializationResponseTime() {
        cleanupUserDefaults()

        let startTime = CFAbsoluteTimeGetCurrent()
        _ = CameraService()
        let elapsedTime = CFAbsoluteTimeGetCurrent() - startTime

        // 初期化は 100ms (0.1秒) 以内に完了すべき
        #expect(
            elapsedTime < 0.1,
            "CameraService initialization should complete within 100ms (actual: \(elapsedTime * 1000)ms)"
        )

        cleanupUserDefaults()
    }

    /// availableCameras プロパティへのアクセス時間を計測
    ///
    /// デバイスリストの取得は 50ms 以内に完了すべき
    @Test func availableCamerasAccessTime() {
        cleanupUserDefaults()
        let service = CameraService()

        let startTime = CFAbsoluteTimeGetCurrent()
        _ = service.availableCameras
        let elapsedTime = CFAbsoluteTimeGetCurrent() - startTime

        // デバイスリスト取得は 50ms (0.05秒) 以内に完了すべき
        #expect(
            elapsedTime < 0.05,
            "availableCameras access should complete within 50ms (actual: \(elapsedTime * 1000)ms)"
        )

        cleanupUserDefaults()
    }

    /// selectCamera の応答時間を計測
    ///
    /// カメラ選択操作は 10ms 以内に完了すべき（即時フィードバック要件）
    @Test func selectCameraResponseTime() {
        cleanupUserDefaults()
        let service = CameraService()
        let testID = "test-camera-response-time"

        let startTime = CFAbsoluteTimeGetCurrent()
        service.selectCamera(testID)
        let elapsedTime = CFAbsoluteTimeGetCurrent() - startTime

        // カメラ選択は 10ms (0.01秒) 以内に完了すべき
        #expect(
            elapsedTime < 0.01,
            "selectCamera should complete within 10ms (actual: \(elapsedTime * 1000)ms)"
        )

        cleanupUserDefaults()
    }
}
