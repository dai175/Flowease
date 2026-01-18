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
    var startAngle: Double
    /// 終了角度（度）
    var endAngle: Double

    /// SwiftUIがアニメーション時に補間するデータ
    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(startAngle, endAngle) }
        set {
            startAngle = newValue.first
            endAngle = newValue.second
        }
    }

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
    // MARK: - Constants

    /// ゲージのサイズ
    private static let gaugeSize: CGFloat = 88
    /// 線の太さ
    private static let lineWidth: CGFloat = 4
    /// 開始角度（左下、135度）
    private static let startAngle: Double = 135
    /// アークの角度範囲（270度）
    private static let arcRange: Double = 270

    // MARK: - Properties

    /// リアルタイムスコア (0-100)
    let score: Int

    /// 現在のカラースキーム（ライト/ダークモード判定）
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Computed Properties

    /// スコアに基づく進捗率 (0.0 - 1.0)
    private var progress: Double {
        Double(min(max(score, 0), 100)) / 100.0
    }

    /// スコアに基づくゲージの色（カラースキーム対応）
    private var gaugeColor: Color {
        ColorGradient.color(fromScore: score, colorScheme: colorScheme)
    }

    /// 進捗に応じた終了角度
    private var progressEndAngle: Double {
        Self.startAngle + Self.arcRange * progress
    }

    /// 終了角度（右下、405度 = 135 + 270）
    private var endAngle: Double {
        Self.startAngle + Self.arcRange
    }

    var body: some View {
        ZStack {
            // 背景アーク（トラック）
            ArcShape(startAngle: Self.startAngle, endAngle: endAngle)
                .stroke(
                    Color.secondary.opacity(0.2),
                    style: StrokeStyle(lineWidth: Self.lineWidth, lineCap: .round)
                )
                .frame(width: Self.gaugeSize, height: Self.gaugeSize)

            // 進捗アーク
            ArcShape(startAngle: Self.startAngle, endAngle: progressEndAngle)
                .stroke(
                    gaugeColor,
                    style: StrokeStyle(lineWidth: Self.lineWidth, lineCap: .round)
                )
                .frame(width: Self.gaugeSize, height: Self.gaugeSize)
                .animation(.easeInOut(duration: 0.3), value: score)
        }
        .frame(width: Self.gaugeSize, height: Self.gaugeSize)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Posture score", comment: "Accessibility label for posture score gauge"))
        .accessibilityValue(String(localized: "\(score) out of 100", comment: "Accessibility value for posture score"))
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
