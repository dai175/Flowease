//
//  StatusMenuView.swift
//  Flowease
//
//  Created by Claude on 2025/12/31.
//

import CoreVideo
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
    var isCapturing = false
    weak var frameDelegate: CameraFrameDelegate?
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

    func startCapturing() {
        isCapturing = true
    }

    func stopCapturing() {
        isCapturing = false
    }
}

// MARK: - MockPostureAnalyzer

/// Preview 用のモック PostureAnalyzer
@MainActor
private struct MockPostureAnalyzer: PostureAnalyzing {
    func analyze(pixelBuffer _: CVPixelBuffer) async -> BodyPose? {
        nil
    }
}

// MARK: - Preview Helper

@MainActor
private func makePreviewViewModel(
    cameraStatus: CameraAuthorizationStatus,
    cameraAvailable: Bool = true
) -> PostureViewModel {
    PostureViewModel(
        cameraService: MockCameraService(status: cameraStatus, cameraAvailable: cameraAvailable),
        postureAnalyzer: MockPostureAnalyzer(),
        scoreCalculator: ScoreCalculator()
    )
}

#Preview("初期化中") {
    StatusMenuView(viewModel: makePreviewViewModel(cameraStatus: .authorized))
}

#Preview("権限拒否") {
    StatusMenuView(viewModel: makePreviewViewModel(cameraStatus: .denied))
}

#Preview("カメラなし") {
    StatusMenuView(viewModel: makePreviewViewModel(cameraStatus: .authorized, cameraAvailable: false))
}
