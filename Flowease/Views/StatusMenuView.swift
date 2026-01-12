//
//  StatusMenuView.swift
//  Flowease
//
//  Created by Claude on 2025/12/31.
//

@preconcurrency import AVFoundation
import SwiftUI

// MARK: - StatusMenuView

/// メニューバーアイコンクリック時に表示されるメニュー
///
/// `PostureViewModel` の `monitoringState` に応じた UI を表示する。
/// - `active`: 姿勢モニタリング中（スコア表示）
/// - `paused`: 一時停止理由を表示
/// - `disabled`: `CameraPermissionView` でエラーメッセージを表示
struct StatusMenuView: View {
    /// 姿勢監視の状態を管理する ViewModel
    let viewModel: PostureViewModel

    /// キャリブレーション ViewModel
    let calibrationViewModel: CalibrationViewModel

    /// アプリケーション状態（プレビュー時はnil）
    var appState: AppState?

    /// ウィンドウを開くための Environment
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 12) {
            // ヒーローセクション（スコア or 状態表示）
            heroSection

            // キャリブレーションカード
            CalibrationCard(
                isCalibrated: calibrationViewModel.isCalibrated,
                statusSummary: calibrationViewModel.statusSummary,
                recommendationMessage: calibrationViewModel.recommendationMessage,
                onReset: {
                    calibrationViewModel.resetCalibration()
                },
                onConfigure: {
                    openWindow(id: "calibration")
                }
            )

            // 通知設定カード（appStateがある場合のみ表示）
            if let appState {
                alertSettingsCard(appState: appState)
            }

            // カメラ選択（authorized 時のみ表示）
            if viewModel.cameraAuthorizationStatus == .authorized {
                HStack {
                    Image(systemName: "camera")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    CameraSelectionView(
                        availableCameras: viewModel.availableCameras,
                        selectedCameraID: viewModel.selectedCameraID,
                        onSelect: { viewModel.selectCamera($0) }
                    )
                }
            }

            // 終了ボタン
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack {
                    Text("Quit")
                        .font(.subheadline)
                    Spacer()
                    Text("⌘Q")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            .keyboardShortcut("q")
        }
        .padding(12)
    }

    // MARK: - Private Views

    @ViewBuilder
    private var heroSection: some View {
        switch viewModel.monitoringState {
        case .active:
            ScoreHeroSection(score: viewModel.smoothedScore, color: viewModel.iconColor)
        case let .paused(reason):
            PausedStateView(reason: reason)
        case let .disabled(reason):
            CameraPermissionView(reason: reason)
                .frame(height: 80)
        }
    }

    /// 通知設定カードを生成
    private func alertSettingsCard(appState: AppState) -> some View {
        AlertSettingsCard(
            settings: Binding(
                get: { appState.alertSettings },
                set: { appState.alertSettings = $0 }
            ),
            onSettingsChanged: { appState.updateAlertSettings($0) }
        )
    }
}

// MARK: - ScoreHeroSection

/// スコアを大きく表示するヒーローセクション
private struct ScoreHeroSection: View {
    let score: Int
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(score)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .contentTransition(.numericText())

            HStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                Text("Monitoring")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: 80)
    }
}

// MARK: - PausedStateView

/// 一時停止状態を表示するビュー
private struct PausedStateView: View {
    let reason: PauseReason

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: reason.iconName)
                .font(.system(size: 28))
                .foregroundStyle(reason.isWarning ? .orange : .secondary)

            Text(reason.description)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
        }
        .frame(height: 80)
    }
}

// MARK: - CalibrationCard

/// キャリブレーション状態を表示するカード
private struct CalibrationCard: View {
    let isCalibrated: Bool
    let statusSummary: String
    let recommendationMessage: String?
    let onReset: () -> Void
    let onConfigure: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                // ステータスアイコン（円形バッジ）
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.15))
                        .frame(width: 28, height: 28)
                    Image(systemName: isCalibrated ? "checkmark" : "person.crop.circle.badge.plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(statusColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Calibration")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(statusSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // アクション
                if isCalibrated {
                    Menu {
                        Button("Reconfigure", action: onConfigure)
                        Divider()
                        Button("Reset", role: .destructive, action: onReset)
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                    }
                    .menuStyle(.borderlessButton)
                } else {
                    Button("Configure", action: onConfigure)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
            }

            // 未キャリブレーション時の推奨メッセージ
            if let message = recommendationMessage {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 36)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.controlBackgroundColor))
        )
    }

    private var statusColor: Color {
        isCalibrated ? .green : .blue
    }
}

// MARK: - Notification.Name

/// キャリブレーションリセット通知
extension Notification.Name {
    static let calibrationReset = Notification.Name("calibrationReset")
}

// MARK: - MockCameraService

/// Preview 用のモック CameraService
@MainActor
private final class MockCameraService: CameraServiceProtocol {
    var authorizationStatus: CameraAuthorizationStatus
    var isCapturing = false
    weak var frameDelegate: CameraFrameDelegate?
    var availableCameras: [CameraDevice]
    var selectedCameraID: String?
    private let cameraAvailable: Bool

    init(status: CameraAuthorizationStatus, cameraAvailable: Bool = true) {
        authorizationStatus = status
        self.cameraAvailable = cameraAvailable
        // Preview 用のダミーカメラリスト
        availableCameras = [
            CameraDevice(id: "camera-1", name: "FaceTime HD Camera", isConnected: true, isDefault: true),
            CameraDevice(id: "camera-2", name: "Logitech C920", isConnected: true, isDefault: false)
        ]
        selectedCameraID = "camera-1"
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

    func selectCamera(_: String?) {
        // No-op for preview
    }
}

// MARK: - MockPostureAnalyzer

/// Preview 用のモック PostureAnalyzer
private struct MockPostureAnalyzer: PostureAnalyzing {
    nonisolated func analyze(sampleBuffer _: CMSampleBuffer) async -> AnalysisResult {
        .noFaceDetected
    }
}

// MARK: - MockCalibrationStorage

/// Preview 用のモック CalibrationStorage
private struct MockCalibrationStorage: CalibrationStorageProtocol {
    var savedFacePosture: FaceReferencePosture?

    var isCalibrated: Bool { savedFacePosture != nil }
    var lastCalibratedAt: Date? { savedFacePosture?.calibratedAt }

    func loadFaceReferencePosture() -> FaceReferencePosture? { savedFacePosture }
    func loadFaceReferencePostureWithAutoClean() -> FaceReferencePosture? { savedFacePosture }
    @discardableResult
    func saveFaceReferencePosture(_: FaceReferencePosture) -> Bool { true }
    func deleteFaceReferencePosture() {}
}

// MARK: - Preview Helper

@MainActor
private func makePreviewCalibrationService(isCalibrated: Bool = false) -> CalibrationService {
    if isCalibrated {
        // キャリブレーション済み用のダミーデータ
        let dummyPosture = FaceReferencePosture(
            calibratedAt: Date(),
            frameCount: 90,
            averageQuality: 0.9,
            baselineMetrics: FaceBaselineMetrics(baselineY: 0.5, baselineArea: 0.1, baselineRoll: 0.0)
        )
        return CalibrationService(storage: MockCalibrationStorage(savedFacePosture: dummyPosture))
    }
    return CalibrationService(storage: MockCalibrationStorage())
}

@MainActor
private func makePreviewViewModel(
    cameraStatus: CameraAuthorizationStatus,
    cameraAvailable: Bool = true,
    score: Int? = nil,
    isCalibrated: Bool = false
) -> PostureViewModel {
    let viewModel = PostureViewModel(
        cameraService: MockCameraService(status: cameraStatus, cameraAvailable: cameraAvailable),
        postureAnalyzer: MockPostureAnalyzer(),
        faceScoreCalculator: FaceScoreCalculator(),
        calibrationService: makePreviewCalibrationService(isCalibrated: isCalibrated)
    )
    // スコアが指定されている場合は active 状態にする
    if let score {
        let breakdown = ScoreBreakdown(verticalPosition: score, sizeChange: score, tilt: score)
        let postureScore = PostureScore(value: score, timestamp: Date(), breakdown: breakdown, confidence: 1.0)
        viewModel.addScore(postureScore)
    }
    return viewModel
}

@MainActor
private func makePreviewCalibrationViewModel(isCalibrated: Bool = false) -> CalibrationViewModel {
    CalibrationViewModel(calibrationService: makePreviewCalibrationService(isCalibrated: isCalibrated))
}

#Preview("初期化中") {
    StatusMenuView(
        viewModel: makePreviewViewModel(cameraStatus: .authorized),
        calibrationViewModel: makePreviewCalibrationViewModel()
    )
}

#Preview("権限拒否") {
    StatusMenuView(
        viewModel: makePreviewViewModel(cameraStatus: .denied),
        calibrationViewModel: makePreviewCalibrationViewModel()
    )
}

#Preview("カメラなし") {
    StatusMenuView(
        viewModel: makePreviewViewModel(cameraStatus: .authorized, cameraAvailable: false),
        calibrationViewModel: makePreviewCalibrationViewModel()
    )
}

#Preview("スコア良好 (85)") {
    StatusMenuView(
        viewModel: makePreviewViewModel(cameraStatus: .authorized, score: 85),
        calibrationViewModel: makePreviewCalibrationViewModel()
    )
}

#Preview("スコア良好 + キャリブレーション済み") {
    StatusMenuView(
        viewModel: makePreviewViewModel(cameraStatus: .authorized, score: 85),
        calibrationViewModel: makePreviewCalibrationViewModel(isCalibrated: true)
    )
}

#Preview("スコア中程度 (50)") {
    StatusMenuView(
        viewModel: makePreviewViewModel(cameraStatus: .authorized, score: 50),
        calibrationViewModel: makePreviewCalibrationViewModel()
    )
}

#Preview("スコア低下 (25)") {
    StatusMenuView(
        viewModel: makePreviewViewModel(cameraStatus: .authorized, score: 25),
        calibrationViewModel: makePreviewCalibrationViewModel()
    )
}
