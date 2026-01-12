//
//  CalibrationStateViews.swift
//  Flowease
//
//  キャリブレーション状態表示の共通コンポーネント
//

import SwiftUI

// MARK: - CalibrationNotCalibratedView

/// キャリブレーション未設定時の表示
struct CalibrationNotCalibratedView: View {
    var body: some View {
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
}

// MARK: - CalibrationCompletedView

/// キャリブレーション完了時の表示
struct CalibrationCompletedView: View {
    var body: some View {
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
}

// MARK: - CalibrationFailedView

/// キャリブレーション失敗時の表示
struct CalibrationFailedView: View {
    let failure: CalibrationFailure

    var body: some View {
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
