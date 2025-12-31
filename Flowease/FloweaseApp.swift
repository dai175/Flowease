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
/// NSStatusItem を使用してメニューバーアイコンを動的に更新する。
@main
struct FloweaseApp: App {
    /// AppDelegate を使用して NSStatusItem を管理
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {}
}
