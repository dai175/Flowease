//
//  StatusMenuView.swift
//  Flowease
//
//  Created by Claude on 2025/12/31.
//

import SwiftUI

// MARK: - StatusMenuView

/// メニューバーアイコンクリック時に表示されるメニュー
///
/// `PostureViewModel` の `monitoringState` に応じた UI を表示する。
/// - `active`: 姿勢モニタリング中（スコア表示は Phase 5 で追加）
/// - `paused`: 一時停止理由を表示
/// - `disabled`: `CameraPermissionView` でエラーメッセージを表示
struct StatusMenuView: View {
    /// 姿勢監視の状態を管理する ViewModel
    let viewModel: PostureViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Flowease")
                .font(.headline)
            Divider()

            // 監視状態に応じた表示
            switch viewModel.monitoringState {
            case .active:
                // Phase 5 で実装: スコア表示
                Text("姿勢モニタリング中")
                    .foregroundStyle(.secondary)

            case let .paused(reason):
                HStack {
                    Image(systemName: "pause.circle")
                        .foregroundStyle(.secondary)
                    Text(reason.description)
                        .foregroundStyle(.secondary)
                }

            case let .disabled(reason):
                CameraPermissionView(reason: reason)
            }
        }
        .padding()
        .task {
            await viewModel.initialize()
        }
    }
}

// MARK: - MockCameraService

/// Preview 用のモック CameraService
@MainActor
private final class MockCameraService: CameraServiceProtocol {
    var authorizationStatus: CameraAuthorizationStatus
    private let cameraAvailable: Bool

    init(status: CameraAuthorizationStatus, cameraAvailable: Bool = true) {
        authorizationStatus = status
        self.cameraAvailable = cameraAvailable
    }

    func requestAuthorization() async -> CameraAuthorizationStatus {
        authorizationStatus
    }

    func checkCameraAvailability() -> Bool {
        cameraAvailable
    }

    func toMonitoringState() -> MonitoringState {
        if !cameraAvailable {
            return .disabled(.noCameraAvailable)
        }
        switch authorizationStatus {
        case .authorized:
            return .paused(.cameraInitializing)
        case .denied:
            return .disabled(.cameraPermissionDenied)
        case .restricted:
            return .disabled(.cameraPermissionRestricted)
        case .notDetermined:
            return .paused(.cameraInitializing)
        }
    }
}

#Preview("初期化中") {
    let viewModel = PostureViewModel(
        cameraService: MockCameraService(status: .authorized)
    )
    return StatusMenuView(viewModel: viewModel)
}

#Preview("権限拒否") {
    let viewModel = PostureViewModel(
        cameraService: MockCameraService(status: .denied)
    )
    return StatusMenuView(viewModel: viewModel)
}

#Preview("カメラなし") {
    let viewModel = PostureViewModel(
        cameraService: MockCameraService(status: .authorized, cameraAvailable: false)
    )
    return StatusMenuView(viewModel: viewModel)
}
