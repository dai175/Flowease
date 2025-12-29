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

    /// 姿勢検知サービス
    private var postureDetectionService: PostureDetectionServiceProtocol? {
        ServiceContainer.shared.isPostureDetectionServiceAvailable
            ? ServiceContainer.shared.postureDetectionService
            : nil
    }

    /// 通知サービス
    private var notificationService: NotificationServiceProtocol? {
        ServiceContainer.shared.isNotificationServiceAvailable
            ? ServiceContainer.shared.notificationService
            : nil
    }

    /// キャンセラブルの保持用
    private var cancellables = Set<AnyCancellable>()

    /// 姿勢監視の購読（重複防止用）
    private var postureMonitoringCancellable: AnyCancellable?

    /// 現在の姿勢状態
    @Published private var currentPostureLevel: PostureLevel = .unknown

    /// 現在の姿勢スコア
    @Published private var currentPostureScore = 0.0

    // MARK: - NSApplicationDelegate

    public func applicationDidFinishLaunching(_: Notification) {
        // サービスを登録
        registerServices()

        // UIをセットアップ
        setupStatusItem()
        setupPopover()

        // 姿勢レベルの変更を監視してアイコンを更新
        $currentPostureLevel
            .receive(on: RunLoop.main)
            .sink { [weak self] level in
                self?.updateStatusItemIcon(for: level)
            }
            .store(in: &cancellables)

        // 姿勢検知を開始
        Task {
            await startPostureMonitoring()
        }

        // 通知からストレッチ開始の通知を購読
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleStartStretchNotification),
            name: .startStretchFromNotification,
            object: nil
        )
    }

    public func applicationWillTerminate(_: Notification) {
        // 姿勢検知を停止
        postureDetectionService?.stopDetection()

        // クリーンアップ処理
        cancellables.removeAll()
        // Note: removeObserver は不要（アプリ終了時にプロセスごと解放される）
    }

    // MARK: - Service Registration

    /// サービスを登録
    private func registerServices() {
        // カメラサービスを登録
        let cameraService = CameraService()
        ServiceContainer.shared.registerCameraService(cameraService)

        // 通知サービスを登録
        let notificationService = NotificationService()
        ServiceContainer.shared.registerNotificationService(notificationService)

        // 姿勢検知サービスを登録
        let postureDetectionService = PostureDetectionService(cameraService: cameraService)
        ServiceContainer.shared.registerPostureDetectionService(postureDetectionService)
    }

    // MARK: - Posture Monitoring

    /// 姿勢監視を開始
    private func startPostureMonitoring() async {
        guard let postureService = postureDetectionService else { return }

        // 設定が有効な場合のみ開始
        let settings = settingsService.settings.value
        guard settings.postureMonitoringEnabled else { return }

        // 既存の購読をキャンセル（重複防止）
        postureMonitoringCancellable?.cancel()

        // 通知権限をリクエスト
        if let notifService = notificationService {
            _ = try? await notifService.requestAuthorization()
        }

        // 姿勢の変更を購読
        postureMonitoringCancellable = postureService.posturePublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] postureState in
                self?.handlePostureUpdate(postureState)
            }

        // 姿勢検知を開始
        do {
            try await postureService.startDetection(cameraDeviceID: settings.selectedCameraID)
        } catch {
            print("Failed to start posture detection: \(error.localizedDescription)")
            currentPostureLevel = .unknown
        }
    }

    /// 姿勢更新を処理
    private func handlePostureUpdate(_ postureState: PostureState?) {
        guard let state = postureState else {
            currentPostureLevel = .unknown
            currentPostureScore = 0.0
            return
        }

        currentPostureLevel = state.level
        currentPostureScore = state.score

        // ポップオーバーの内容も更新
        if let popover = popover, popover.isShown {
            updatePopoverContent()
        }

        // 悪い姿勢が続いている場合は通知を送信
        Task {
            await checkAndSendPostureAlert(state)
        }
    }

    /// 姿勢警告が必要かチェックして送信
    private func checkAndSendPostureAlert(_ state: PostureState) async {
        let settings = settingsService.settings.value

        // 通知が無効の場合はスキップ
        guard settings.notificationsEnabled else { return }

        // 悪い姿勢が設定時間以上続いている場合
        if state.level == .bad,
           state.badPostureDuration >= settings.badPostureAlertDelay
        {
            try? await notificationService?.sendPostureAlert(postureState: state)
        }
    }

    /// 通知からストレッチ開始
    @objc private func handleStartStretchNotification() {
        DispatchQueue.main.async { [weak self] in
            self?.startStretch()
        }
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
            postureScore: currentPostureScore,
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
            postureScore: currentPostureScore,
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
