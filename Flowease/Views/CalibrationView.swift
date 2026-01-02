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
            Text("姿勢キャリブレーション")
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

            Text("良い姿勢を取ってください")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text("3秒間、カメラに向かって正面を向き、リラックスした良い姿勢を維持してください。")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 8)
    }

    // MARK: - In Progress View

    private var inProgressView: some View {
        VStack(spacing: 16) {
            CalibrationProgressView(
                progress: viewModel.progress,
                remainingSeconds: viewModel.remainingSeconds
            )

            Text("そのままの姿勢を維持...")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // 検出品質警告
            if let warningMessage = viewModel.qualityWarningMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(warningMessage)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Completed View

    private var completedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.green)

            Text("キャリブレーション完了")
                .font(.subheadline)
                .foregroundStyle(.primary)

            Text("あなたの良い姿勢が基準として記録されました。")
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

            Text("キャリブレーション失敗")
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
                Button("キャンセル") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button("開始") {
                    Task {
                        await viewModel.startCalibration()
                    }
                }
                .buttonStyle(.borderedProminent)
            }

        case .inProgress:
            Button("キャンセル") {
                viewModel.cancelCalibration()
            }
            .buttonStyle(.bordered)

        case .completed:
            Button("閉じる") {
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
    var referencePosture: ReferencePosture? { nil }

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

    func processFrame(_: BodyPose) {}
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

#Preview("失敗 - 人物未検出") {
    CalibrationView(viewModel: makePreviewViewModel(state: .failed(.noPersonDetected)))
}

#Preview("失敗 - 低信頼度") {
    CalibrationView(viewModel: makePreviewViewModel(state: .failed(.lowConfidence)))
}
