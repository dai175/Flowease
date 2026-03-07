//
//  CalibrationStateViews.swift
//  Flowease
//
//  キャリブレーション状態表示の共通コンポーネント
//

@preconcurrency import AVFoundation
import SwiftUI

// MARK: - CalibrationStatusView

/// キャリブレーション状態の統合表示ビュー
///
/// 未設定、完了、失敗の3状態を単一のデータ駆動型ビューで表示
struct CalibrationStatusView: View {
    // MARK: - Dynamic Type Support

    /// アイコンのフォントサイズ（Dynamic Type対応）
    @ScaledMetric(relativeTo: .title2) private var iconFontSize: CGFloat = 20

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

        var titleColor: Color {
            switch self {
            case .notCalibrated: .secondary
            case .completed: .green
            case .failed: .orange
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
    /// アイコンを表示するかどうか（カメラプレビューがある場合は非表示にする）
    var showIcon: Bool = true

    var body: some View {
        VStack(spacing: 12) {
            if !showIcon { Spacer(minLength: 0) }
            if showIcon {
                // StatusBadge スタイルの大きいバージョン
                ZStack {
                    Circle()
                        .fill(status.iconColor.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: status.iconName)
                        .font(.system(size: iconFontSize, weight: .semibold))
                        .foregroundStyle(status.iconColor)
                }
            }

            HStack(spacing: 4) {
                if !showIcon, status != .notCalibrated {
                    Image(systemName: status.iconName)
                        .font(.subheadline)
                        .foregroundStyle(status.iconColor)
                        .accessibilityHidden(true)
                }
                Text(status.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(status.titleColor)
            }
            .multilineTextAlignment(.center)

            if let description = status.description {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(status == .notCalibrated ? .tertiary : .secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: showIcon ? 144 : nil)
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

// MARK: - CalibrationInProgressView

/// キャリブレーション実行中の表示
struct CalibrationInProgressView: View {
    let progress: Double
    let remainingSeconds: Double
    let warningMessage: String?
    /// 円形プログレスを表示するか（false の場合リニアプログレスバー）
    var showCircularProgress: Bool = true

    init(
        progress: Double,
        remainingSeconds: Double,
        warningMessage: String? = nil,
        showCircularProgress: Bool = true
    ) {
        self.progress = progress
        self.remainingSeconds = remainingSeconds
        self.warningMessage = warningMessage
        self.showCircularProgress = showCircularProgress
    }

    private var progressAccessibilityValue: String {
        let pct = Int(progress * 100)
        let secs = Int(ceil(remainingSeconds))
        return String(
            localized: "\(pct) percent complete, \(secs) seconds remaining",
            comment: "Accessibility value for calibration progress"
        )
    }

    var body: some View {
        VStack(spacing: 12) {
            if !showCircularProgress { Spacer(minLength: 0) }
            if showCircularProgress {
                CalibrationProgressView(
                    progress: progress,
                    remainingSeconds: remainingSeconds
                )
            } else {
                // リニアプログレスバー + 残り秒数
                HStack(spacing: 8) {
                    ProgressView(value: min(progress, 1.0))
                        .progressViewStyle(.linear)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: progress)
                    Text(
                        String(
                            localized: "\(Int(ceil(remainingSeconds)))s",
                            comment: "キャリブレーション残り秒数"
                        )
                    )
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    String(
                        localized: "Calibration Progress",
                        comment: "Accessibility label for calibration progress"
                    )
                )
                .accessibilityValue(progressAccessibilityValue)
            }

            Text("Maintain your posture...")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // 警告メッセージ（固定高さでレイアウトのちらつきを防止）
            HStack(spacing: 6) {
                if let warningMessage {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(warningMessage)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(minHeight: 24)
            .background(warningMessage != nil ? .orange.opacity(0.1) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            Spacer(minLength: 0)
        }
        .frame(minHeight: showCircularProgress ? 144 : nil)
    }
}

// MARK: - CalibrationCameraPreview

/// キャリブレーション画面用のカメラプレビュー（顔検出状態に応じた枠線付き）
struct CalibrationCameraPreview: View {
    let postureViewModel: PostureViewModel
    let calibrationViewModel: CalibrationViewModel

    private var showGuide: Bool {
        switch calibrationViewModel.state {
        case .notCalibrated, .inProgress:
            true
        case .completed, .failed:
            false
        }
    }

    var body: some View {
        CameraPreviewView(session: postureViewModel.captureSession)
            .aspectRatio(4 / 3, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor, lineWidth: 3)
            )
            .overlay(
                FaceTrackingOverlayView(
                    facePosition: postureViewModel.currentFacePosition,
                    showGuide: showGuide
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
            )
            .accessibilityLabel(
                String(localized: "Camera Preview", comment: "カメラプレビューのアクセシビリティラベル")
            )
    }

    private var borderColor: Color {
        switch calibrationViewModel.state {
        case .inProgress:
            switch calibrationViewModel.qualityLevel {
            case .good: .green
            case .lowConfidence: .orange
            case .noFaceDetected: .red
            }
        case .completed:
            .green
        case .failed:
            .orange
        case .notCalibrated:
            postureViewModel.isMonitoringActive ? .green : .red
        }
    }
}

// MARK: - CalibrationContentView

/// キャリブレーション状態に応じたコンテンツ表示（カメラプレビューモード用）
struct CalibrationContentView: View {
    let viewModel: CalibrationViewModel

    var body: some View {
        switch viewModel.state {
        case .notCalibrated:
            CalibrationStatusView(status: .notCalibrated, showIcon: false)

        case .inProgress:
            CalibrationInProgressView(
                progress: viewModel.displayProgress,
                remainingSeconds: viewModel.displayRemainingSeconds,
                warningMessage: viewModel.qualityWarningMessage,
                showCircularProgress: false
            )

        case .completed:
            CalibrationStatusView(status: .completed, showIcon: false)

        case let .failed(failure):
            CalibrationStatusView(status: .failed(failure), showIcon: false)
        }
    }
}

// MARK: - Preview

#Preview("Not Calibrated") {
    CalibrationStatusView(status: .notCalibrated)
        .padding()
}

#Preview("Completed") {
    CalibrationStatusView(status: .completed)
        .padding()
}

#Preview("Failed - No Face") {
    CalibrationStatusView(status: .failed(.noFaceDetected))
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
