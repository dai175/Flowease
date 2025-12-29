//
//  AppDelegate.swift
//  Flowease
//
//  Created by Daisuke Ooba on 2025/12/28.
//

import AppKit
import Combine
import SwiftUI

/// メニューバーアプリケーションのデリゲート
/// NSStatusBar と NSPopover を管理し、アプリのライフサイクルを制御
public final class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - Properties

    /// メニューバーのステータスアイテム
    private var statusItem: NSStatusItem?

    /// ポップオーバー
    private var popover: NSPopover?

    /// 設定サービス
    private var settingsService: SettingsServiceProtocol {
        ServiceContainer.shared.settingsService
    }

    /// キャンセラブルの保持用
    private var cancellables = Set<AnyCancellable>()

    /// 現在の姿勢状態（Phase 4で姿勢検知サービスと連携）
    @Published private var currentPostureLevel: PostureLevel = .unknown

    // MARK: - NSApplicationDelegate

    public func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopover()

        // 姿勢レベルの変更を監視してアイコンを更新
        $currentPostureLevel
            .receive(on: RunLoop.main)
            .sink { [weak self] level in
                self?.updateStatusItemIcon(for: level)
            }
            .store(in: &cancellables)
    }

    public func applicationWillTerminate(_ notification: Notification) {
        // クリーンアップ処理
        cancellables.removeAll()
    }

    // MARK: - Setup

    /// ステータスアイテム（メニューバーアイコン）をセットアップ
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem?.button else { return }

        updateStatusItemIcon(for: currentPostureLevel)

        button.action = #selector(togglePopover)
        button.target = self
    }

    /// ポップオーバーをセットアップ
    private func setupPopover() {
        let popover = NSPopover()
        popover.contentSize = NSSize(
            width: Constants.UserInterface.Popover.width,
            height: Constants.UserInterface.Popover.height
        )
        popover.behavior = .transient
        popover.animates = true

        // PopoverView を SwiftUI でホスト
        let popoverView = PopoverView(
            postureLevel: currentPostureLevel,
            onSettingsPressed: { [weak self] in
                self?.openSettings()
            },
            onStretchPressed: { [weak self] in
                self?.startStretch()
            }
        )
        popover.contentViewController = NSHostingController(rootView: popoverView)

        self.popover = popover
    }

    // MARK: - Status Item Icon

    /// 姿勢レベルに応じてステータスアイテムのアイコンを更新
    /// - Parameter level: 姿勢レベル
    public func updateStatusItemIcon(for level: PostureLevel) {
        guard let button = statusItem?.button else { return }

        let symbolConfig = NSImage.SymbolConfiguration(
            pointSize: Constants.UserInterface.statusBarIconSize,
            weight: .medium
        )

        let nsColor: NSColor
        switch level {
        case .good:
            nsColor = NSColor(Color("PostureGoodColor"))
        case .warning:
            nsColor = NSColor(Color("PostureWarningColor"))
        case .bad:
            nsColor = NSColor(Color("PostureBadColor"))
        case .unknown:
            nsColor = NSColor(Color("PostureUnknownColor"))
        }

        let paletteConfig = NSImage.SymbolConfiguration(paletteColors: [nsColor])
        let combinedConfig = symbolConfig.applying(paletteConfig)

        let image = NSImage(
            systemSymbolName: level.iconName,
            accessibilityDescription: "Flowease - \(level.displayName)"
        )
        button.image = image?.withSymbolConfiguration(combinedConfig)
    }

    /// 外部から姿勢レベルを更新（Phase 4 で姿勢検知サービスから呼び出し）
    /// - Parameter level: 新しい姿勢レベル
    public func updatePostureLevel(_ level: PostureLevel) {
        currentPostureLevel = level

        // ポップオーバーの内容も更新
        if let popover = popover, popover.isShown {
            updatePopoverContent()
        }
    }

    // MARK: - Popover Actions

    /// ポップオーバーの表示/非表示を切り替え
    @objc private func togglePopover() {
        guard let button = statusItem?.button else { return }

        if let popover = popover {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                // ポップオーバーを表示する前に内容を更新
                updatePopoverContent()
                NSApp.activate(ignoringOtherApps: true)
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }

    /// ポップオーバーの内容を更新
    private func updatePopoverContent() {
        let popoverView = PopoverView(
            postureLevel: currentPostureLevel,
            onSettingsPressed: { [weak self] in
                self?.openSettings()
            },
            onStretchPressed: { [weak self] in
                self?.startStretch()
            }
        )
        popover?.contentViewController = NSHostingController(rootView: popoverView)
    }

    /// ポップオーバーを閉じる
    public func closePopover() {
        popover?.performClose(nil)
    }

    // MARK: - Navigation

    /// 設定画面を開く
    private func openSettings() {
        closePopover()
        // Settings Scene を表示
        if #available(macOS 14.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }

    /// ストレッチを開始（Phase 6 で実装）
    private func startStretch() {
        closePopover()
        // Phase 6: ストレッチガイド画面を表示
        // TODO: StretchGuideWindow を表示
    }
}
