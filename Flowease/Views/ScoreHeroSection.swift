//
//  ScoreHeroSection.swift
//  Flowease
//
//  スコアを大きく表示するヒーローセクション
//

import SwiftUI

// MARK: - ScoreHeroSection

/// スコアを大きく表示するヒーローセクション
///
/// 評価期間平均をメインに表示し、リアルタイムスコアをアークゲージで補助表示する。
/// active/paused 状態間でインスタンスを維持し、スムーズなアニメーション遷移を実現する。
struct ScoreHeroSection: View {
    /// 評価期間平均スコア（メイン表示）
    let averageScore: Int?
    /// リアルタイムスコア（ゲージ表示）
    let realtimeScore: Int?
    /// フォールバック用の色（paused時など）
    let fallbackColor: Color
    /// 外部から渡された安定化されたステータス（3秒平均）
    var status: ScoreStatus?
    var pauseReason: String?

    /// 最後に表示したリアルタイムスコア（アニメーション継続用）
    @State private var lastRealtimeScore: Int = 0

    private var isPaused: Bool { pauseReason != nil }

    /// ゲージに渡すスコア（nilの場合は最後のスコアを使用してアニメーション継続）
    private var gaugeScore: Int {
        realtimeScore ?? lastRealtimeScore
    }

    /// スコアに基づくグラデーション色
    private var scoreColor: Color {
        if let avg = averageScore {
            return ColorGradient.color(fromScore: avg)
        }
        if let realtime = realtimeScore {
            return ColorGradient.color(fromScore: realtime)
        }
        return fallbackColor
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // リアルタイムスコアのアークゲージ（常に同一インスタンスでアニメーション継続）
                RealtimeScoreGauge(score: gaugeScore)
                    .opacity(realtimeScore != nil ? 1.0 : 0.3)
                    .animation(.easeInOut(duration: 0.3), value: realtimeScore != nil)

                // 評価期間平均スコア（中央）
                VStack(spacing: 0) {
                    Text(scoreDisplay)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(scoreColor)

                    Text(statusLabel)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(scoreColor.opacity(0.8))
                }
            }

            HStack(spacing: 4) {
                PulsingDot(color: scoreColor, isPaused: isPaused)
                Text(pauseReason ?? String(localized: "Monitoring"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(height: 100)
        .onAppear {
            // 初期表示時に lastRealtimeScore を設定（onChange は初回は呼ばれないため）
            if let score = realtimeScore {
                lastRealtimeScore = score
            }
        }
        .onChange(of: realtimeScore) { oldValue, newValue in
            if let score = newValue {
                // 新しいスコアが来たら保持
                lastRealtimeScore = score
            } else if oldValue != nil {
                // nil になった場合、lastRealtimeScore から 0 へアニメーション
                withAnimation(.easeInOut(duration: 0.5)) {
                    lastRealtimeScore = 0
                }
            }
        }
    }

    private var scoreDisplay: String {
        (averageScore ?? realtimeScore).map { "\($0)" } ?? "--"
    }

    private var statusLabel: String {
        // 外部から渡されたステータスを優先（3秒平均の安定化された状態）
        if let status { return status.label }
        if let averageScore { return ScoreStatus(score: averageScore).label }
        if let realtimeScore { return ScoreStatus(score: realtimeScore).label }
        return String(localized: "Paused")
    }
}

// MARK: - Preview

#Preview("Active") {
    ScoreHeroSection(
        averageScore: 85,
        realtimeScore: 82,
        fallbackColor: .green,
        status: .good,
        pauseReason: nil
    )
    .padding()
}

#Preview("Paused") {
    ScoreHeroSection(
        averageScore: nil,
        realtimeScore: nil,
        fallbackColor: .secondary,
        status: nil,
        pauseReason: "Initializing camera"
    )
    .padding()
}
