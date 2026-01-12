//
//  RealtimeScoreGauge.swift
//  Flowease
//
//  リアルタイムスコアを表示する270度アークゲージ
//

import SwiftUI

// MARK: - ArcShape

/// アーク（円弧）を描画するShape
///
/// 指定された開始角度から終了角度までの円弧を描画する。
/// 角度はSwiftUI標準座標系（3時位置が0度、反時計回りに増加）で指定する。
struct ArcShape: Shape {
    /// 開始角度（度）
    let startAngle: Double
    /// 終了角度（度）
    let endAngle: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(startAngle),
            endAngle: .degrees(endAngle),
            clockwise: false
        )
        return path
    }
}

// MARK: - RealtimeScoreGauge

/// リアルタイムスコアを270度アークゲージで表示するビュー
///
/// スコアに応じて円弧の長さと色が変化する。
/// - 100点: 緑色で270度（フル）
/// - 0点: 赤色で0度（空）
struct RealtimeScoreGauge: View {
    /// リアルタイムスコア (0-100)
    let score: Int

    /// ゲージのサイズ
    private let gaugeSize: CGFloat = 88
    /// 線の太さ
    private let lineWidth: CGFloat = 4
    /// 開始角度（左下、135度）
    private let startAngle: Double = 135
    /// 終了角度（右下、405度 = 135 + 270）
    private let endAngle: Double = 405
    /// アークの角度範囲
    private var arcRange: Double { endAngle - startAngle }

    /// スコアに基づく進捗率 (0.0 - 1.0)
    private var progress: Double {
        Double(min(max(score, 0), 100)) / 100.0
    }

    /// スコアに基づくゲージの色
    private var gaugeColor: Color {
        ColorGradient.color(fromScore: score)
    }

    /// 進捗に応じた終了角度
    private var progressEndAngle: Double {
        startAngle + arcRange * progress
    }

    var body: some View {
        ZStack {
            // 背景アーク（トラック）
            ArcShape(startAngle: startAngle, endAngle: endAngle)
                .stroke(
                    Color.secondary.opacity(0.2),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .frame(width: gaugeSize, height: gaugeSize)

            // 進捗アーク
            ArcShape(startAngle: startAngle, endAngle: progressEndAngle)
                .stroke(
                    gaugeColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .frame(width: gaugeSize, height: gaugeSize)
                .animation(.easeInOut(duration: 0.3), value: score)
        }
        .frame(width: gaugeSize, height: gaugeSize)
    }
}

// MARK: - Preview

#Preview("Score 100") {
    RealtimeScoreGauge(score: 100)
        .padding()
}

#Preview("Score 75") {
    RealtimeScoreGauge(score: 75)
        .padding()
}

#Preview("Score 50") {
    RealtimeScoreGauge(score: 50)
        .padding()
}

#Preview("Score 25") {
    RealtimeScoreGauge(score: 25)
        .padding()
}

#Preview("Score 0") {
    RealtimeScoreGauge(score: 0)
        .padding()
}
