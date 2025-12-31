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
    var body: some Scene {
        MenuBarExtra {
            StatusMenuView()
        } label: {
            MenuBarView()
        }
        .menuBarExtraStyle(.menu)
    }
}
