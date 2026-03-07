//
//  CalibrationWindowView.swift
//  Flowease
//
//  キャリブレーションウィンドウ用のビュー
//

import SwiftUI

/// キャリブレーションウィンドウ用のビュー
///
/// CalibrationViewModel を使用してキャリブレーションの状態表示と操作を提供する。
/// カメラプレビューを表示し、顔検出状態に応じた枠線を表示する。
struct CalibrationWindowView: View {
    @Bindable var viewModel: CalibrationViewModel
    var postureViewModel: PostureViewModel
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        VStack(spacing: 16) {
            // カメラプレビュー
            CalibrationCameraPreview(
                postureViewModel: postureViewModel,
                calibrationViewModel: viewModel
            )

            // 状態に応じたコンテンツ
            CalibrationContentView(viewModel: viewModel)
                .frame(maxHeight: .infinity)

            Divider()

            // アクションボタン
            actionButtons
        }
        .padding()
        .frame(width: 320, height: 380)
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
        switch viewModel.state {
        case .notCalibrated, .failed:
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismissWindow(id: WindowID.calibration)
                }
                .buttonStyle(.bordered)

                Button("Start") {
                    Task {
                        await viewModel.startCalibration()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!postureViewModel.isMonitoringActive)
            }

        case .inProgress:
            Button("Cancel") {
                viewModel.cancelCalibration()
            }
            .buttonStyle(.bordered)

        case .completed:
            HStack(spacing: 12) {
                Button("Recalibrate") {
                    Task {
                        await viewModel.startCalibration()
                    }
                }
                .buttonStyle(.bordered)

                Button("Close") {
                    dismissWindow(id: WindowID.calibration)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}
