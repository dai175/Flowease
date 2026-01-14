//
//  StatusBadge.swift
//  Flowease
//
//  設定セクション用の円形バッジアイコン
//

import SwiftUI

// MARK: - StatusBadge

/// 円形バッジアイコン（設定セクション用）
///
/// Alert Settings、Calibration、Camera セクションで使用される
/// 統一されたアイコンスタイルを提供する。
struct StatusBadge: View {
    /// SF Symbol 名
    let systemName: String

    /// バッジの色（背景とアイコンの両方に適用）
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: 28, height: 28)
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
        }
    }
}

// MARK: - Preview

#Preview("Blue (Alert)") {
    StatusBadge(systemName: "bell.fill", color: .blue)
}

#Preview("Green (Calibration)") {
    StatusBadge(systemName: "checkmark", color: .green)
}

#Preview("Secondary (Camera)") {
    StatusBadge(systemName: "camera", color: .secondary)
}
