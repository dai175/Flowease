//
//  CalibrationStateViews.swift
//  Flowease
//
//  キャリブレーション状態表示の共通コンポーネント
//

import SwiftUI

// MARK: - CalibrationStatusView

/// キャリブレーション状態の統合表示ビュー
///
/// 未設定、完了、失敗の3状態を単一のデータ駆動型ビューで表示
struct CalibrationStatusView: View {
    /// 表示する状態
    enum Status {
        case notCalibrated
        case completed
        case failed(CalibrationFailure)

        var iconName: String {
            switch self {
            case .notCalibrated: "person.fill"
            case .completed: "checkmark"
            case .failed: "exclamationmark.triangle.fill"
            }
        }

        var iconColor: Color {
            switch self {
            case .notCalibrated: .secondary
            case .completed: .green
            case .failed: .orange
            }
        }

        var title: LocalizedStringKey {
            switch self {
            case .notCalibrated: "Please assume good posture"
            case .completed: "Calibration Complete"
            case .failed: "Calibration Failed"
            }
        }

        var titleStyle: HierarchicalShapeStyle {
            switch self {
            case .notCalibrated: .secondary
            case .completed, .failed: .primary
            }
        }

        var description: String? {
            switch self {
            case .notCalibrated:
                String(localized: "Face the camera and maintain a relaxed, good posture for 3 seconds.")
            case .completed:
                String(localized: "Your good posture has been recorded as the baseline.")
            case let .failed(failure):
                failure.userMessage.isEmpty ? nil : failure.userMessage
            }
        }
    }

    let status: Status

    var body: some View {
        VStack(spacing: 12) {
            // StatusBadge スタイルの大きいバージョン
            ZStack {
                Circle()
                    .fill(status.iconColor.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: status.iconName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(status.iconColor)
            }

            Text(status.title)
                .font(.subheadline)
                .foregroundStyle(status.titleStyle)
                .multilineTextAlignment(.center)

            if let description = status.description {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(status == .notCalibrated ? .tertiary : .secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - CalibrationStatusView.Status + Equatable

extension CalibrationStatusView.Status: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.notCalibrated, .notCalibrated), (.completed, .completed):
            true
        case let (.failed(lhsFailure), .failed(rhsFailure)):
            lhsFailure == rhsFailure
        default:
            false
        }
    }
}

// MARK: - CalibrationNotCalibratedView

/// キャリブレーション未設定時の表示
struct CalibrationNotCalibratedView: View {
    var body: some View {
        CalibrationStatusView(status: .notCalibrated)
    }
}

// MARK: - CalibrationCompletedView

/// キャリブレーション完了時の表示
struct CalibrationCompletedView: View {
    var body: some View {
        CalibrationStatusView(status: .completed)
    }
}

// MARK: - CalibrationFailedView

/// キャリブレーション失敗時の表示
struct CalibrationFailedView: View {
    let failure: CalibrationFailure

    var body: some View {
        CalibrationStatusView(status: .failed(failure))
    }
}

// MARK: - CalibrationInProgressView

/// キャリブレーション実行中の表示
struct CalibrationInProgressView: View {
    let progress: Double
    let remainingSeconds: Double
    let warningMessage: String?

    init(progress: Double, remainingSeconds: Double, warningMessage: String? = nil) {
        self.progress = progress
        self.remainingSeconds = remainingSeconds
        self.warningMessage = warningMessage
    }

    var body: some View {
        VStack(spacing: 16) {
            CalibrationProgressView(
                progress: progress,
                remainingSeconds: remainingSeconds
            )

            Text("Maintain your posture...")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let warningMessage {
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
}

// MARK: - Preview

#Preview("Not Calibrated") {
    CalibrationNotCalibratedView()
        .padding()
}

#Preview("Completed") {
    CalibrationCompletedView()
        .padding()
}

#Preview("Failed - No Face") {
    CalibrationFailedView(failure: .noFaceDetected)
        .padding()
}

#Preview("In Progress") {
    CalibrationInProgressView(
        progress: 0.5,
        remainingSeconds: 1.5
    )
    .padding()
}

#Preview("In Progress with Warning") {
    CalibrationInProgressView(
        progress: 0.3,
        remainingSeconds: 2.1,
        warningMessage: "Posture detection quality is low"
    )
    .padding()
}
