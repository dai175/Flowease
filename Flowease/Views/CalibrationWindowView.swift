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
struct CalibrationWindowView: View {
    @Bindable var viewModel: CalibrationViewModel
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        VStack(spacing: 16) {
            // 状態に応じたコンテンツ
            contentView

            Divider()

            // アクションボタン
            actionButtons
        }
        .padding()
        .frame(width: 280, height: 240)
    }

    // MARK: - Content View

    @ViewBuilder
    private var contentView: some View {
        switch viewModel.state {
        case .notCalibrated:
            CalibrationStatusView(status: .notCalibrated)

        case .inProgress:
            CalibrationInProgressView(
                progress: viewModel.displayProgress,
                remainingSeconds: viewModel.displayRemainingSeconds,
                warningMessage: viewModel.qualityWarningMessage
            )

        case .completed:
            CalibrationStatusView(status: .completed)

        case let .failed(failure):
            CalibrationStatusView(status: .failed(failure))
        }
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
