//
//  FloweaseApp.swift
//  Flowease
//
//  Created by Daisuke Ooba on 2025/12/27.
//

import SwiftUI

/// Flowease アプリケーションのエントリーポイント
/// メニューバー常駐型アプリとして動作し、設定画面のみウィンドウを持つ
@main
struct FloweaseApp: App {
    /// AppDelegate をアダプターとして使用
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        // サービスの登録
        ServiceContainer.shared.registerSettingsService(SettingsService())
    }

    var body: some Scene {
        // 設定画面（メニューバー → 環境設定... から開く）
        Settings {
            SettingsView()
        }
    }
}
