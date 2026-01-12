//
//  CalibrationWindowView.swift
//  Flowease
//
//  キャリブレーションウィンドウ用のビュー
//

import Combine
import SwiftUI

/// キャリブレーションウィンドウ用のビュー
///
/// CalibrationViewModel を使用してキャリブレーションの状態表示と操作を提供する。
struct CalibrationWindowView: View {
    @Bindable var viewModel: CalibrationViewModel
    @Environment(\.dismissWindow) private var dismissWindow

    /// タイマーで進捗を更新（0.1秒ごと）
    @State private var timerTick = 0

    /// 進捗更新用タイマー
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

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
        .onReceive(timer) { _ in
            // タイマーでビューを再描画（進捗更新用）
            if viewModel.isInProgress {
                timerTick += 1
            }
        }
    }

    // MARK: - Content View

    @ViewBuilder
    private var contentView: some View {
        switch viewModel.state {
        case .notCalibrated:
            CalibrationNotCalibratedView()

        case .inProgress:
            // timerTickを使って再描画をトリガー
            CalibrationInProgressView(
                progress: viewModel.progress,
                remainingSeconds: viewModel.remainingSeconds
            )
            .id(timerTick)

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
                    dismissWindow(id: "calibration")
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
                    dismissWindow(id: "calibration")
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}
