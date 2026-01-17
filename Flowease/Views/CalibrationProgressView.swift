//
//  CalibrationProgressView.swift
//  Flowease
//
//  キャリブレーション進捗を表示するコンポーネント
//

import SwiftUI

// MARK: - CalibrationProgressView

/// キャリブレーション進捗を表示する円形プログレスビュー
///
/// 3秒間のキャリブレーション中に円形のプログレスインジケーターと
/// 残り秒数のカウントダウンを表示する。
struct CalibrationProgressView: View {
    /// 進捗率 (0.0 〜 1.0)
    let progress: Double

    /// 残り秒数
    let remainingSeconds: Double

    /// プログレスバーの太さ
    private let lineWidth: CGFloat = 4

    /// プログレスサークルのサイズ
    private let circleSize: CGFloat = 64

    /// 内側の塗りつぶし円のサイズ
    private let innerCircleSize: CGFloat = 48

    var body: some View {
        ZStack {
            // 塗りつぶし背景（StatusBadge スタイル）
            Circle()
                .fill(Color.accentColor.opacity(0.15))
                .frame(width: innerCircleSize, height: innerCircleSize)

            // 背景の円（トラック）
            Circle()
                .stroke(
                    Color.secondary.opacity(0.2),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .frame(width: circleSize, height: circleSize)

            // プログレス円
            Circle()
                .trim(from: 0, to: CGFloat(min(progress, 1.0)))
                .stroke(
                    Color.accentColor,
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
                )
                .frame(width: circleSize, height: circleSize)
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: progress)

            // 残り秒数
            Text("\(Int(ceil(remainingSeconds)))")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            String(localized: "Calibration Progress", comment: "Accessibility label for calibration progress")
        )
        .accessibilityValue(
            String(
                localized: "\(Int(progress * 100)) percent complete, \(Int(ceil(remainingSeconds))) seconds remaining",
                comment: "Accessibility value for calibration progress"
            )
        )
    }
}

// MARK: - Preview

#Preview("進捗 0%") {
    CalibrationProgressView(progress: 0.0, remainingSeconds: 3.0)
        .padding()
}

#Preview("進捗 33%") {
    CalibrationProgressView(progress: 0.33, remainingSeconds: 2.0)
        .padding()
}

#Preview("進捗 66%") {
    CalibrationProgressView(progress: 0.66, remainingSeconds: 1.0)
        .padding()
}

#Preview("進捗 100%") {
    CalibrationProgressView(progress: 1.0, remainingSeconds: 0.0)
        .padding()
}
