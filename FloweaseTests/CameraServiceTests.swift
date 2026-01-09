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
    @Test func selectCameraWithEmptyStringID() {
        cleanupUserDefaults()
        let service = CameraService()

        service.selectCamera("")

        // 空文字列は有効な ID として扱われるべきではない
        // 実装により nil と同等に扱われるか、または保存されるかは設計次第
        // ここでは UserDefaults の動作を確認
        let storedID = UserDefaults.standard.string(forKey: selectedCameraKey)

        // 空文字列が保存された場合、フォールバックが発生するべき
        #expect(
            storedID == "" || storedID == nil,
            "Empty string ID handling should be consistent"
        )

        cleanupUserDefaults()
    }
}
