//
//  MenuBarView.swift
//  Flowease
//
//  Created by Claude on 2025/12/31.
//

import SwiftUI

/// メニューバーに表示されるアイコン
///
/// 姿勢スコアに応じてアイコンの色が変化する。
/// Phase 3 では静的なアイコンを表示し、後続のフェーズでスコア連動を追加する。
struct MenuBarView: View {
    var body: some View {
        Image(systemName: "figure.stand")
    }
}

#Preview {
    MenuBarView()
}
