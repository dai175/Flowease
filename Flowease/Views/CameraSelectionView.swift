import SwiftUI

// MARK: - CameraSelectionView

/// カメラ選択コンポーネント
///
/// メニューバーに統合されるカメラ選択UI。
/// Picker を使用して利用可能なカメラを一覧表示し、選択を受け付けます。
struct CameraSelectionView: View {
    /// 利用可能なカメラデバイス一覧
    let availableCameras: [CameraDevice]

    /// 現在選択されているカメラのID
    let selectedCameraID: String?

    /// カメラ選択時のコールバック
    let onSelect: (String?) -> Void

    var body: some View {
        Picker(
            String(localized: "Camera", comment: "Camera selection picker label"),
            selection: Binding(
                get: { selectedCameraID },
                set: { onSelect($0) }
            )
        ) {
            // システムデフォルトオプション
            Text(String(localized: "System Default", comment: "System default camera option"))
                .tag(nil as String?)

            Divider()

            // 各カメラオプション
            ForEach(availableCameras) { camera in
                cameraLabel(for: camera)
                    .tag(camera.id as String?)
            }
        }
        .labelsHidden()
    }

    // MARK: - Private Views

    @ViewBuilder
    private func cameraLabel(for camera: CameraDevice) -> some View {
        if camera.isDefault {
            Text("\(camera.name) (\(String(localized: "Default", comment: "Default camera indicator")))")
        } else {
            Text(camera.name)
        }
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Multiple Cameras") {
        CameraSelectionView(
            availableCameras: [
                CameraDevice(
                    id: "camera-1",
                    name: "FaceTime HD Camera",
                    isConnected: true,
                    isDefault: true
                ),
                CameraDevice(
                    id: "camera-2",
                    name: "Logitech C920",
                    isConnected: true,
                    isDefault: false
                ),
                CameraDevice(
                    id: "camera-3",
                    name: "OBS Virtual Camera",
                    isConnected: true,
                    isDefault: false
                )
            ],
            selectedCameraID: "camera-1",
            onSelect: { _ in }
        )
        .frame(width: 250)
    }

    #Preview("Single Camera") {
        CameraSelectionView(
            availableCameras: [
                CameraDevice(
                    id: "camera-1",
                    name: "FaceTime HD Camera",
                    isConnected: true,
                    isDefault: true
                )
            ],
            selectedCameraID: nil,
            onSelect: { _ in }
        )
        .frame(width: 250)
    }

    #Preview("No Cameras") {
        CameraSelectionView(
            availableCameras: [],
            selectedCameraID: nil,
            onSelect: { _ in }
        )
        .frame(width: 250)
    }

    #Preview("Duplicate Camera Names") {
        CameraSelectionView(
            availableCameras: [
                CameraDevice(
                    id: "camera-1",
                    name: "Logitech C920",
                    isConnected: true,
                    isDefault: true
                ),
                CameraDevice(
                    id: "camera-2",
                    name: "Logitech C920 (2)",
                    isConnected: true,
                    isDefault: false
                )
            ],
            selectedCameraID: "camera-1",
            onSelect: { _ in }
        )
        .frame(width: 250)
    }
#endif
