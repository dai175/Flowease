// AppDelegate.swift
// Flowease
//
// アプリケーションのライフサイクル管理と NSStatusItem の設定

import AppKit
import OSLog
import SwiftUI

// MARK: - AppDelegate

/// アプリケーションデリゲート
///
/// NSStatusItem を使用してメニューバーアイコンを管理する。
/// MenuBarExtra では動的なアイコン更新ができないため、AppKit を使用。
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - Properties

    private let logger = Logger(subsystem: "cc.focuswave.Flowease", category: "AppDelegate")

    /// ステータスバーアイテム（メモリ保持必須）
    private var statusItem: NSStatusItem?

    /// 姿勢監視 ViewModel
    private var viewModel: PostureViewModel?

    /// ステータスアイテム管理
    private var statusItemManager: StatusItemManager?

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_: Notification) {
        logger.info("アプリケーション起動")
        setupStatusItem()
    }

    func applicationWillTerminate(_: Notification) {
        logger.info("アプリケーション終了")
        // 観察タスクを停止
        statusItemManager?.stopObserving()
        // 姿勢監視を停止（カメラリソースを解放）
        viewModel?.stopMonitoring()
    }

    // MARK: - Private Methods

    private func setupStatusItem() {
        // ViewModel を作成
        let viewModel = PostureViewModel()
        self.viewModel = viewModel

        // NSStatusItem を作成
        let statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.squareLength
        )
        self.statusItem = statusItem

        // StatusItemManager を作成してアイコン管理を委譲
        let manager = StatusItemManager(
            statusItem: statusItem,
            viewModel: viewModel
        )
        statusItemManager = manager

        // メニューを設定
        statusItem.menu = createMenu(viewModel: viewModel)

        logger.debug("NSStatusItem をセットアップしました")

        // ViewModel の初期化を開始
        Task {
            await viewModel.initialize()
        }
    }

    private func createMenu(viewModel: PostureViewModel) -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self

        // SwiftUI ビューを NSMenuItem に埋め込む
        let hostingView = NSHostingView(rootView: StatusMenuView(viewModel: viewModel))
        hostingView.frame.size = hostingView.fittingSize

        let menuItem = NSMenuItem()
        menuItem.view = hostingView
        menu.addItem(menuItem)

        // 区切り線
        menu.addItem(NSMenuItem.separator())

        // 終了ボタン
        let quitItem = NSMenuItem(
            title: "終了",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)

        return menu
    }
}

// MARK: NSMenuDelegate

extension AppDelegate: NSMenuDelegate {
    /// メニューが開く直前にホスティングビューのサイズを更新
    func menuWillOpen(_ menu: NSMenu) {
        // 最初のアイテムの view (NSHostingView) のサイズを更新
        if let hostingView = menu.items.first?.view as? NSHostingView<StatusMenuView> {
            hostingView.frame.size = hostingView.fittingSize
        }
    }
}
