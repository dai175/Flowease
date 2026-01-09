import SwiftUI

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
