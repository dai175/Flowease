//
//  FloweaseApp.swift
//  Flowease
//
//  Created by Daisuke Ooba on 2025/12/30.
//

import SwiftUI

/// Flowease アプリケーションのエントリポイント
///
/// メニューバーに常駐し、姿勢をモニタリングするアプリケーション。
/// `LSUIElement=true` により Dock には表示されない。
@main
struct FloweaseApp: App {
    /// 姿勢監視の状態を管理する ViewModel
    @State private var viewModel = PostureViewModel()

    var body: some Scene {
        MenuBarExtra {
            StatusMenuView(viewModel: viewModel)
        } label: {
            MenuBarView()
        }
        .menuBarExtraStyle(.menu)
    }
}
