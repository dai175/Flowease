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

            Divider()

            // === Utility: カメラ選択 + 終了 ===
            HStack {
                // カメラ選択（authorized 時のみ表示）
                if viewModel.cameraAuthorizationStatus == .authorized {
                    HStack(spacing: 4) {
                        Image(systemName: "camera")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                        CameraSelectionView(
                            availableCameras: viewModel.availableCameras,
                            selectedCameraID: viewModel.selectedCameraID,
                            onSelect: { viewModel.selectCamera($0) }
                        )
                    }
                }

                Spacer()

                // 終了ボタン
                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    HStack(spacing: 4) {
                        Text("Quit")
                            .font(.caption)
                        Text("⌘Q")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
                .keyboardShortcut("q")
            }
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
        switch viewModel.monitoringState {
        case .active:
            ScoreHeroSection(
                score: viewModel.smoothedScore,
                color: viewModel.iconColor,
                status: viewModel.stabilizedScoreStatus
            )
        case let .paused(reason):
            ScoreHeroSection(
                score: nil,
                color: .secondary,
                pauseReason: reason.description
            )
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
    let score: Int?
    let color: Color
    /// 外部から渡された安定化されたステータス（3秒平均）
    var status: ScoreStatus?
    var pauseReason: String?

    private var isPaused: Bool { pauseReason != nil }

    var body: some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(scoreDisplay)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                    .contentTransition(.numericText())

                Text(statusLabel)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(color.opacity(0.8))
            }

            HStack(spacing: 4) {
                PulsingDot(color: color, isPaused: isPaused)
                Text(pauseReason ?? String(localized: "Monitoring"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(width: 140, alignment: .leading)
            }
        }
        .frame(height: 80)
    }

    private var scoreDisplay: String {
        score.map { "\($0)" } ?? "--"
    }

    private var statusLabel: String {
        // 外部から渡されたステータスを優先（3秒平均の安定化された状態）
        if let status { return status.label }
        if let score { return ScoreStatus(score: score).label }
        return String(localized: "Paused")
    }
}

// MARK: - PulsingDot

/// パルスアニメーション付きのドット（外側に広がるリング効果）
private struct PulsingDot: View {
    let color: Color
    var isPaused: Bool = false

    private static let dotSize: CGFloat = 6
    private static let pulseAnimation = Animation.easeOut(duration: 1.2).repeatForever(autoreverses: false)

    @State private var isPulsing = false

    var body: some View {
        ZStack {
            if !isPaused {
                pulseRing
            }
            centerDot
        }
        .frame(width: Self.dotSize * 2.5, height: Self.dotSize * 2.5)
        .onAppear { isPulsing = !isPaused }
        .onChange(of: isPaused) { _, newValue in
            isPulsing = !newValue
        }
    }

    private var pulseRing: some View {
        Circle()
            .stroke(color, lineWidth: 1)
            .frame(width: Self.dotSize, height: Self.dotSize)
            .scaleEffect(isPulsing ? 2.5 : 1.0)
            .opacity(isPulsing ? 0 : 0.8)
            .animation(Self.pulseAnimation, value: isPulsing)
    }

    private var centerDot: some View {
        Circle()
            .fill(color)
            .frame(width: Self.dotSize, height: Self.dotSize)
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
