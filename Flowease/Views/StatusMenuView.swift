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
            // === Primary: スコア + 状態 + モニタリング ===
            heroSection

            // === Secondary: 設定 ===
            VStack(spacing: 8) {
                // 通知設定カード（appStateがある場合のみ表示）
                if let appState {
                    alertSettingsCard(appState: appState)
                }

                // キャリブレーションセクション（コンパクト/フル）
                calibrationSection
            }

            // カメラ選択（authorized 時のみ表示）
            if viewModel.cameraAuthorizationStatus == .authorized {
                let selectedCameraName = viewModel.availableCameras
                    .first { $0.id == viewModel.selectedCameraID }?.name
                    ?? String(localized: "System Default")

                HStack(spacing: 8) {
                    StatusBadge(systemName: "camera", color: .secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Camera")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(selectedCameraName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    CameraSelectionView(
                        availableCameras: viewModel.availableCameras,
                        selectedCameraID: viewModel.selectedCameraID,
                        onSelect: { viewModel.selectCamera($0) }
                    )
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.controlBackgroundColor).opacity(0.5))
                )
            }

            Divider()

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
            .accessibilityLabel(String(localized: "Quit Flowease"))
        }
        .padding(12)
    }

    // MARK: - Calibration Section

    /// キャリブレーションセクション
    ///
    /// キャリブレーション済みの場合はコンパクト表示、未設定の場合はフルカード表示
    @ViewBuilder
    private var calibrationSection: some View {
        if calibrationViewModel.isCalibrated {
            CompactCalibrationCard(
                statusSummary: calibrationViewModel.statusSummary,
                onReconfigure: { openWindow(id: "calibration") }
            )
        } else {
            CalibrationCard(
                isCalibrated: calibrationViewModel.isCalibrated,
                statusSummary: calibrationViewModel.statusSummary,
                recommendationMessage: calibrationViewModel.recommendationMessage,
                onReset: { calibrationViewModel.resetCalibration() },
                onConfigure: { openWindow(id: "calibration") }
            )
        }
    }

    // MARK: - Private Views

    @ViewBuilder
    private var heroSection: some View {
        if case let .disabled(reason) = viewModel.monitoringState {
            CameraPermissionView(reason: reason)
                .frame(height: 80)
        } else {
            let data = heroData
            ScoreHeroSection(
                averageScore: data.averageScore,
                realtimeScore: data.realtimeScore,
                fallbackColor: data.fallbackColor,
                status: data.status,
                pauseReason: data.pauseReason
            )
        }
    }

    // MARK: - Hero Section Data

    private struct HeroData {
        let averageScore: Int?
        let realtimeScore: Int?
        let fallbackColor: Color
        let status: ScoreStatus?
        let pauseReason: String?
    }

    private var heroData: HeroData {
        switch viewModel.monitoringState {
        case .active:
            return HeroData(
                averageScore: viewModel.evaluationPeriodAverageScore.map { Int($0) },
                realtimeScore: viewModel.smoothedScore,
                fallbackColor: viewModel.iconColor,
                status: viewModel.stabilizedScoreStatus,
                pauseReason: nil
            )
        case let .paused(reason):
            return HeroData(
                averageScore: nil,
                realtimeScore: nil,
                fallbackColor: .secondary,
                status: nil,
                pauseReason: reason.description
            )
        case .disabled:
            fatalError("disabled case should be handled in heroSection")
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

#Preview("スコア良好 + キャリブレーション済み") {
    StatusMenuView(
        viewModel: makePreviewViewModel(cameraStatus: .authorized, score: 85, isCalibrated: true),
        calibrationViewModel: makePreviewCalibrationViewModel(isCalibrated: true)
    )
}
