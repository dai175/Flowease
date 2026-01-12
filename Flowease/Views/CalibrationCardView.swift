//
//  CalibrationCardView.swift
//  Flowease
//
//  Created by Claude on 2025/01/12.
//

import SwiftUI

// MARK: - CalibrationCard

/// キャリブレーション状態を表示するカード
struct CalibrationCard: View {
    let isCalibrated: Bool
    let statusSummary: String
    let recommendationMessage: String?
    let onReset: () -> Void
    let onConfigure: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                // ステータスアイコン（円形バッジ）
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.15))
                        .frame(width: 28, height: 28)
                    Image(systemName: isCalibrated ? "checkmark" : "person.crop.circle.badge.plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(statusColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Calibration")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(statusSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // アクション
                if isCalibrated {
                    Menu {
                        Button("Reconfigure", action: onConfigure)
                        Divider()
                        Button("Reset", role: .destructive, action: onReset)
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                    }
                    .menuStyle(.borderlessButton)
                } else {
                    Button("Configure", action: onConfigure)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
            }

            // 未キャリブレーション時の推奨メッセージ
            if let message = recommendationMessage {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 36)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.controlBackgroundColor))
        )
    }

    private var statusColor: Color {
        isCalibrated ? .green : .blue
    }
}

// MARK: - CompactCalibrationCard

/// コンパクトなキャリブレーションカード（完了時用）
///
/// キャリブレーション完了後に表示される1行のコンパクトなカード。
/// 完了状態と日時を表示し、再設定ボタンを提供する。
struct CompactCalibrationCard: View {
    let statusSummary: String
    let onReconfigure: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // 完了アイコン
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(.green)

            Text("Calibration: \(statusSummary)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            // 再設定メニュー
            Menu {
                Button("Reconfigure", action: onReconfigure)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .help(String(localized: "Reconfigure calibration"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.controlBackgroundColor).opacity(0.5))
        )
    }
}

// MARK: - Previews

#Preview("Not Calibrated") {
    CalibrationCard(
        isCalibrated: false,
        statusSummary: "Not configured",
        recommendationMessage: "Configure calibration for more accurate posture assessment",
        onReset: {},
        onConfigure: {}
    )
    .padding()
}

#Preview("Calibrated") {
    CalibrationCard(
        isCalibrated: true,
        statusSummary: "Complete (Jan 12)",
        recommendationMessage: nil,
        onReset: {},
        onConfigure: {}
    )
    .padding()
}

#Preview("Compact") {
    CompactCalibrationCard(
        statusSummary: "Complete (Jan 12)",
        onReconfigure: {}
    )
    .padding()
}
