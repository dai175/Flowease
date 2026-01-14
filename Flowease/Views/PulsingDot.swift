//
//  PulsingDot.swift
//  Flowease
//
//  パルスアニメーション付きのドット
//

import SwiftUI

// MARK: - PulsingDot

/// パルスアニメーション付きのドット（外側に広がるリング効果）
///
/// アクティブ状態を示すインジケーターとして使用。
/// isPaused が false の場合、パルスアニメーションを表示する。
struct PulsingDot: View {
    let color: Color
    var isPaused: Bool = false

    private static let dotSize: CGFloat = 6
    private static let pulseAnimation = Animation.easeOut(duration: 1.2).repeatForever(autoreverses: false)

    @State private var isPulsing = false

    var body: some View {
        ZStack {
            if !isPaused {
                pulseRing
            }
            centerDot
        }
        .frame(width: Self.dotSize * 2.5, height: Self.dotSize * 2.5)
        .onAppear { isPulsing = !isPaused }
        .onChange(of: isPaused) { _, newValue in
            isPulsing = !newValue
        }
    }

    private var pulseRing: some View {
        Circle()
            .stroke(color, lineWidth: 1)
            .frame(width: Self.dotSize, height: Self.dotSize)
            .scaleEffect(isPulsing ? 2.5 : 1.0)
            .opacity(isPulsing ? 0 : 0.8)
            .animation(Self.pulseAnimation, value: isPulsing)
    }

    private var centerDot: some View {
        Circle()
            .fill(color)
            .frame(width: Self.dotSize, height: Self.dotSize)
    }
}

// MARK: - Preview

#Preview("Active") {
    PulsingDot(color: .green, isPaused: false)
        .padding()
}

#Preview("Paused") {
    PulsingDot(color: .secondary, isPaused: true)
        .padding()
}
