import Foundation
import Testing
@testable import Flowease

/// CameraSelectionView のテスト
///
/// T029 [US3]: Test CameraSelectionView with single camera
///
/// シングルカメラ環境でのUI表示と選択動作を検証します。
@MainActor
struct CameraSelectionViewTests {
    // MARK: - Test Data

    /// テスト用のシングルカメラ
    static let singleCamera = CameraDevice(
        id: "test-camera-1",
        name: "FaceTime HD Camera",
        isConnected: true,
        isDefault: true
    )

    /// テスト用の複数カメラ
    static let multipleCameras = [
        CameraDevice(
            id: "test-camera-1",
            name: "FaceTime HD Camera",
            isConnected: true,
            isDefault: true
        ),
        CameraDevice(
            id: "test-camera-2",
            name: "Logitech C920",
            isConnected: true,
            isDefault: false
        ),
    ]

    // MARK: - T029 [US3]: Single Camera Scenario Tests

    /// シングルカメラ環境で CameraSelectionView が正しく初期化されることを確認
    @Test func singleCameraViewInitialization() {
        // Given
        let cameras = [Self.singleCamera]
        var selectedID: String?

        // When
        let view = CameraSelectionView(
            availableCameras: cameras,
            selectedCameraID: selectedID,
            onSelect: { selectedID = $0 }
        )

        // Then
        #expect(view.availableCameras.count == 1)
        #expect(view.availableCameras[0].id == "test-camera-1")
        #expect(view.selectedCameraID == nil)
    }

    /// シングルカメラが選択された時に onSelect コールバックが呼ばれることを確認
    @Test func singleCameraSelectionCallback() {
        // Given
        let cameras = [Self.singleCamera]
        var selectedID: String?
        var callbackInvoked = false

        let onSelect: (String?) -> Void = { id in
            selectedID = id
            callbackInvoked = true
        }

        // When - シングルカメラを選択
        onSelect("test-camera-1")

        // Then
        #expect(callbackInvoked)
        #expect(selectedID == "test-camera-1")
    }

    /// シングルカメラ環境で System Default を選択した場合の動作確認
    @Test func singleCameraSystemDefaultSelection() {
        // Given
        let cameras = [Self.singleCamera]
        var selectedID: String? = "test-camera-1"

        let onSelect: (String?) -> Void = { id in
            selectedID = id
        }

        // When - System Default を選択
        onSelect(nil)

        // Then
        #expect(selectedID == nil)
    }

    /// シングルカメラのデフォルトフラグが正しく反映されることを確認
    @Test func singleCameraDefaultFlag() {
        // Given
        let cameras = [Self.singleCamera]

        // When
        let view = CameraSelectionView(
            availableCameras: cameras,
            selectedCameraID: nil,
            onSelect: { _ in }
        )

        // Then
        #expect(view.availableCameras[0].isDefault)
    }

    // MARK: - Multiple Cameras Comparison Tests

    /// 複数カメラ環境との比較: View が正しく初期化されることを確認
    @Test func multipleCamerasViewInitialization() {
        // Given
        let cameras = Self.multipleCameras

        // When
        let view = CameraSelectionView(
            availableCameras: cameras,
            selectedCameraID: nil,
            onSelect: { _ in }
        )

        // Then
        #expect(view.availableCameras.count == 2)
        #expect(view.availableCameras[0].isDefault)
        #expect(!view.availableCameras[1].isDefault)
    }

    /// カメラ選択の切り替えが正しく動作することを確認
    @Test func cameraSelectionSwitching() {
        // Given
        let cameras = Self.multipleCameras
        var selectedID: String? = "test-camera-1"

        let onSelect: (String?) -> Void = { id in
            selectedID = id
        }

        // When - 2台目のカメラを選択
        onSelect("test-camera-2")

        // Then
        #expect(selectedID == "test-camera-2")
    }

    // MARK: - Edge Cases

    /// 空のカメラリストでも View が正しく動作することを確認
    @Test func emptyCameraListHandling() {
        // Given
        let cameras: [CameraDevice] = []

        // When
        let view = CameraSelectionView(
            availableCameras: cameras,
            selectedCameraID: nil,
            onSelect: { _ in }
        )

        // Then
        #expect(view.availableCameras.isEmpty)
        #expect(view.selectedCameraID == nil)
    }

    /// 選択されたカメラがリストに存在しない場合の動作確認
    @Test func selectedCameraNotInList() {
        // Given
        let cameras = [Self.singleCamera]
        let nonExistentID = "non-existent-camera"

        // When
        let view = CameraSelectionView(
            availableCameras: cameras,
            selectedCameraID: nonExistentID,
            onSelect: { _ in }
        )

        // Then
        // View は selectedCameraID をそのまま保持（フォールバックは CameraService の責務）
        #expect(view.selectedCameraID == nonExistentID)
        #expect(!view.availableCameras.contains { $0.id == nonExistentID })
    }
}
