//
//  CalibrationView.swift
//  Flowease
//
//  キャリブレーション画面
//

import SwiftUI

// MARK: - CalibrationView

/// キャリブレーション画面
///
/// ユーザーが「良い姿勢」を基準として登録するための画面。
/// キャリブレーションの開始・キャンセル・完了・失敗を表示。
struct CalibrationView: View {
    /// キャリブレーションViewModel
    @Bindable var viewModel: CalibrationViewModel

    /// ウィンドウを閉じるアクション
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            // タイトル
            Text("Posture Calibration")
                .font(.headline)

            Divider()

            // 状態に応じたコンテンツ
            contentView

            Divider()

            // アクションボタン
            actionButtons
        }
        .padding()
        .frame(width: 280)
    }

    // MARK: - Content View

    @ViewBuilder
    private var contentView: some View {
        switch viewModel.state {
        case .notCalibrated:
            CalibrationNotCalibratedView()

        case .inProgress:
            CalibrationInProgressView(
                progress: viewModel.progress,
                remainingSeconds: viewModel.remainingSeconds,
                warningMessage: viewModel.qualityWarningMessage
            )

        case .completed:
            CalibrationCompletedView()

        case let .failed(failure):
            CalibrationFailedView(failure: failure)
        }
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
        switch viewModel.state {
        case .notCalibrated, .failed:
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button("Start") {
                    Task {
                        await viewModel.startCalibration()
                    }
                }
                .buttonStyle(.borderedProminent)
            }

        case .inProgress:
            Button("Cancel") {
                viewModel.cancelCalibration()
            }
            .buttonStyle(.bordered)

        case .completed:
            Button("Close") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Mock ViewModel for Preview

@MainActor
private func makePreviewViewModel(state: CalibrationState) -> CalibrationViewModel {
    let mockService = MockCalibrationServiceForPreview(initialState: state)
    return CalibrationViewModel(calibrationService: mockService)
}

// MARK: - MockCalibrationServiceForPreview

@MainActor
private final class MockCalibrationServiceForPreview: CalibrationServiceProtocol {
    var state: CalibrationState

    init(initialState: CalibrationState) {
        state = initialState
    }

    func startCalibration() async throws {
        state = .inProgress(CalibrationProgress())
    }

    func cancelCalibration() {
        state = .notCalibrated
    }

    func resetCalibration() {
        state = .notCalibrated
    }

    func processFaceFrame(_: FacePosition) {}
    func processNoFaceFrame() {}
    var faceReferencePosture: FaceReferencePosture? { nil }
    func prepareForRecalibration() {
        state = .notCalibrated
    }
}

// MARK: - Preview

#Preview("未キャリブレーション") {
    CalibrationView(viewModel: makePreviewViewModel(state: .notCalibrated))
}

#Preview("実行中") {
    CalibrationView(viewModel: makePreviewViewModel(
        state: .inProgress(CalibrationProgress(
            startTime: Date().addingTimeInterval(-1),
            collectedFrames: 30
        ))
    ))
}

#Preview("完了") {
    CalibrationView(viewModel: makePreviewViewModel(state: .completed))
}

#Preview("失敗 - 顔未検出") {
    CalibrationView(viewModel: makePreviewViewModel(state: .failed(.noFaceDetected)))
}

#Preview("失敗 - 低信頼度") {
    CalibrationView(viewModel: makePreviewViewModel(state: .failed(.lowConfidence)))
}
