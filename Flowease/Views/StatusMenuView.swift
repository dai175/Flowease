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

// MARK: - ScoreHeroSection

/// スコアを大きく表示するヒーローセクション
///
/// 評価期間平均をメインに表示し、リアルタイムスコアをアークゲージで補助表示する。
/// active/paused 状態間でインスタンスを維持し、スムーズなアニメーション遷移を実現する。
private struct ScoreHeroSection: View {
    /// 評価期間平均スコア（メイン表示）
    let averageScore: Int?
    /// リアルタイムスコア（ゲージ表示）
    let realtimeScore: Int?
    /// フォールバック用の色（paused時など）
    let fallbackColor: Color
    /// 外部から渡された安定化されたステータス（3秒平均）
    var status: ScoreStatus?
    var pauseReason: String?

    /// 最後に表示したリアルタイムスコア（アニメーション継続用）
    @State private var lastRealtimeScore: Int = 0

    private var isPaused: Bool { pauseReason != nil }

    /// ゲージに渡すスコア（nilの場合は最後のスコアを使用してアニメーション継続）
    private var gaugeScore: Int {
        realtimeScore ?? lastRealtimeScore
    }

    /// スコアに基づくグラデーション色
    private var scoreColor: Color {
        if let avg = averageScore {
            return ColorGradient.color(fromScore: avg)
        }
        if let realtime = realtimeScore {
            return ColorGradient.color(fromScore: realtime)
        }
        return fallbackColor
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // リアルタイムスコアのアークゲージ（常に同一インスタンスでアニメーション継続）
                RealtimeScoreGauge(score: gaugeScore)
                    .opacity(realtimeScore != nil ? 1.0 : 0.3)
                    .animation(.easeInOut(duration: 0.3), value: realtimeScore != nil)

                // 評価期間平均スコア（中央）
                VStack(spacing: 0) {
                    Text(scoreDisplay)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(scoreColor)

                    Text(statusLabel)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(scoreColor.opacity(0.8))
                }
            }

            HStack(spacing: 4) {
                PulsingDot(color: scoreColor, isPaused: isPaused)
                Text(pauseReason ?? String(localized: "Monitoring"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(height: 100)
        .onAppear {
            // 初期表示時に lastRealtimeScore を設定（onChange は初回は呼ばれないため）
            if let score = realtimeScore {
                lastRealtimeScore = score
            }
        }
        .onChange(of: realtimeScore) { oldValue, newValue in
            if let score = newValue {
                // 新しいスコアが来たら保持
                lastRealtimeScore = score
            } else if oldValue != nil {
                // nil になった場合、lastRealtimeScore から 0 へアニメーション
                withAnimation(.easeInOut(duration: 0.5)) {
                    lastRealtimeScore = 0
                }
            }
        }
    }

    private var scoreDisplay: String {
        (averageScore ?? realtimeScore).map { "\($0)" } ?? "--"
    }

    private var statusLabel: String {
        // 外部から渡されたステータスを優先（3秒平均の安定化された状態）
        if let status { return status.label }
        if let averageScore { return ScoreStatus(score: averageScore).label }
        if let realtimeScore { return ScoreStatus(score: realtimeScore).label }
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

#Preview("スコア良好 + キャリブレーション済み") {
    StatusMenuView(
        viewModel: makePreviewViewModel(cameraStatus: .authorized, score: 85, isCalibrated: true),
        calibrationViewModel: makePreviewCalibrationViewModel(isCalibrated: true)
    )
}
