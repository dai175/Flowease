//
//  StatusMenuView.swift
//  Flowease
//
//  Created by Claude on 2025/12/31.
//

@preconcurrency import AVFoundation
import SwiftUI

// MARK: - StatusMenuView

/// キャリブレーションウィンドウ表示通知
extension Notification.Name {
    static let showCalibrationWindow = Notification.Name("showCalibrationWindow")
    static let calibrationReset = Notification.Name("calibrationReset")
}

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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Flowease")
                .font(.headline)
            Divider()

            // 監視状態に応じた表示
            switch viewModel.monitoringState {
            case .active:
                Text("\(viewModel.smoothedScore)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(viewModel.iconColor)
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

            Divider()

            // キャリブレーション状態表示
            CalibrationStatusRow(
                isCalibrated: calibrationViewModel.isCalibrated,
                statusSummary: calibrationViewModel.statusSummary,
                recommendationMessage: calibrationViewModel.recommendationMessage,
                onReset: {
                    calibrationViewModel.resetCalibration()
                }
            )
        }
        .padding()
        // 初期化は AppDelegate で実行するため .task は不要
    }
}

// MARK: - CalibrationStatusRow

/// キャリブレーション状態を表示する行
private struct CalibrationStatusRow: View {
    /// キャリブレーション済みかどうか
    let isCalibrated: Bool

    /// キャリブレーション状態のサマリー（日時含む）
    let statusSummary: String

    /// 推奨メッセージ（未キャリブレーション時のみ）
    let recommendationMessage: String?

    /// リセットアクション
    let onReset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                // 状態アイコン
                Image(systemName: isCalibrated ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isCalibrated ? .green : .secondary)

                // 状態テキスト
                Text("キャリブレーション: \(statusSummary)")
                    .font(.subheadline)
                    .foregroundStyle(isCalibrated ? .primary : .secondary)

                Spacer()

                // リセットボタン（キャリブレーション済みの場合のみ表示）
                if isCalibrated {
                    Button("リセット") {
                        onReset()
                        // 通知を送信してPostureViewModelでScoreCalculatorをクリア
                        NotificationCenter.default.post(name: .calibrationReset, object: nil)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .controlSize(.small)
                }

                // キャリブレーションボタン
                Button(isCalibrated ? "再設定" : "設定") {
                    // 通知を送信してAppDelegateでウィンドウを開く
                    NotificationCenter.default.post(name: .showCalibrationWindow, object: nil)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            // 未キャリブレーション時の推奨メッセージ
            if let message = recommendationMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 24) // アイコンの幅に合わせてインデント
            }
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
private struct MockPostureAnalyzer: PostureAnalyzing {
    nonisolated func analyze(sampleBuffer _: sending CMSampleBuffer) async -> AnalysisResult {
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
