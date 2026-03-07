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

    /// 姿勢ViewModel（カメラプレビュー・顔検出状態用）
    var postureViewModel: PostureViewModel

    /// ウィンドウを閉じるアクション
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            // タイトル
            Text("Posture Calibration")
                .font(.headline)

            Divider()

            // カメラプレビュー
            CalibrationCameraPreview(
                postureViewModel: postureViewModel,
                calibrationViewModel: viewModel
            )

            // 状態に応じたコンテンツ
            CalibrationContentView(viewModel: viewModel)

            Divider()

            // アクションボタン
            actionButtons
        }
        .padding()
        .frame(width: 280)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            switch viewModel.state {
            case .notCalibrated, .failed:
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
                .disabled(!postureViewModel.isMonitoringActive)

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
    var faceReferencePosture: FaceReferencePosture? {
        nil
    }

    func prepareForRecalibration() {
        state = .notCalibrated
    }
}
