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
            notCalibratedView

        case .inProgress:
            inProgressView

        case .completed:
            completedView

        case let .failed(failure):
            failedView(failure: failure)
        }
    }

    // MARK: - Not Calibrated View

    private var notCalibratedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("Please assume good posture")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text("Face the camera and maintain a relaxed, good posture for 3 seconds.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 8)
    }

    // MARK: - In Progress View

    private var inProgressView: some View {
        VStack(spacing: 16) {
            // timerTickを使って再描画をトリガー（見えない形で）
            CalibrationProgressView(
                progress: viewModel.progress,
                remainingSeconds: viewModel.remainingSeconds
            )
            .id(timerTick)

            Text("Maintain your posture...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Completed View

    private var completedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.green)

            Text("Calibration Complete")
                .font(.subheadline)
                .foregroundStyle(.primary)

            Text("Your good posture has been recorded as the baseline.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Failed View

    private func failedView(failure: CalibrationFailure) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.orange)

            Text("Calibration Failed")
                .font(.subheadline)
                .foregroundStyle(.primary)

            if !failure.userMessage.isEmpty {
                Text(failure.userMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 8)
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
