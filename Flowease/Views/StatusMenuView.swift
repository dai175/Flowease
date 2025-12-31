//
//  StatusMenuView.swift
//  Flowease
//
//  Created by Claude on 2025/12/31.
//

import SwiftUI

/// メニューバーアイコンクリック時に表示されるメニュー
///
/// メニューの内容を表示する。Phase 3 では最小限の UI を実装し、
/// 後続のフェーズでカメラ状態やスコア表示を追加する。
struct StatusMenuView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Flowease")
                .font(.headline)
            Divider()
            Text("姿勢モニタリング")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    StatusMenuView()
}
