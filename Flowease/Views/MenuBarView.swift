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
/// - 良い姿勢: 緑系
/// - 悪い姿勢: 赤系
/// - 監視停止時: グレー
struct MenuBarView: View {
    /// 姿勢監視の状態を管理する ViewModel
    @Bindable var viewModel: PostureViewModel

    var body: some View {
        Image(systemName: "figure.stand")
            .foregroundColor(viewModel.iconColor)
    }
}

#Preview {
    MenuBarView(viewModel: PostureViewModel())
}
