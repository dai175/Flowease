// AppDelegate.swift
// Flowease
//
// アプリケーションのライフサイクル管理と NSStatusItem の設定

import AppKit
import Combine
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

    /// キャリブレーション ViewModel
    private var calibrationViewModel: CalibrationViewModel?

    /// ステータスアイテム管理
    private var statusItemManager: StatusItemManager?

    /// キャリブレーションウィンドウ
    private var calibrationWindow: NSWindow?

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_: Notification) {
        logger.info("アプリケーション起動")
        setupStatusItem()
        setupNotificationObservers()
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
        // サービスを作成
        let storage = CalibrationStorage()
        let calibrationService = CalibrationService(storage: storage)

        // ViewModel を作成
        let viewModel = PostureViewModel(
            cameraService: CameraService(),
            postureAnalyzer: PostureAnalyzer(),
            faceScoreCalculator: FaceScoreCalculator(),
            calibrationService: calibrationService
        )
        self.viewModel = viewModel

        // CalibrationViewModel を作成
        let calibrationViewModel = CalibrationViewModel(calibrationService: calibrationService)
        self.calibrationViewModel = calibrationViewModel

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
        statusItem.menu = createMenu(viewModel: viewModel, calibrationViewModel: calibrationViewModel)

        logger.debug("NSStatusItem をセットアップしました")

        // ViewModel の初期化を開始
        Task {
            await viewModel.initialize()
        }
    }

    private func createMenu(viewModel: PostureViewModel, calibrationViewModel: CalibrationViewModel) -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self

        // SwiftUI ビューを NSMenuItem に埋め込む
        let hostingView = NSHostingView(
            rootView: StatusMenuView(viewModel: viewModel, calibrationViewModel: calibrationViewModel)
        )
        hostingView.frame.size = hostingView.fittingSize

        let menuItem = NSMenuItem()
        menuItem.view = hostingView
        menu.addItem(menuItem)

        // 区切り線
        menu.addItem(NSMenuItem.separator())

        // 終了ボタン
        let quitItem = NSMenuItem(
            title: String(localized: "Quit"),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)

        return menu
    }

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleShowCalibrationWindow),
            name: .showCalibrationWindow,
            object: nil
        )
    }

    @objc private func handleShowCalibrationWindow() {
        showCalibrationWindow()
    }

    private func showCalibrationWindow() {
        // 既存のウィンドウがあれば前面に
        if let window = calibrationWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        guard let calibrationViewModel else {
            logger.error("CalibrationViewModel が未初期化です")
            return
        }

        // ウィンドウを作成
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 280),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = String(localized: "Posture Calibration")
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self

        // SwiftUI ビューを設定
        let hostingView = NSHostingView(rootView: CalibrationWindowView(viewModel: calibrationViewModel))
        window.contentView = hostingView

        // ウィンドウを表示
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        calibrationWindow = window
        logger.debug("キャリブレーションウィンドウを表示")
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

// MARK: NSWindowDelegate

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window === calibrationWindow {
            calibrationWindow = nil
            logger.debug("キャリブレーションウィンドウを閉じました")
        }
    }
}

// MARK: - CalibrationWindowView

/// キャリブレーションウィンドウ用のビュー
///
/// CalibrationViewをラップし、ウィンドウを閉じる機能を提供する。
private struct CalibrationWindowView: View {
    @Bindable var viewModel: CalibrationViewModel

    /// タイマーで進捗を更新（0.1秒ごと）
    @State private var timerTick = 0

    /// 進捗更新用タイマー
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 16) {
            // 状態に応じたコンテンツ
            contentView

            Divider()

            // アクションボタン
            actionButtons
        }
        .padding()
        .frame(width: 280, height: 240)
        .onReceive(timer) { _ in
            // タイマーでビューを再描画（進捗更新用）
            if viewModel.isInProgress {
                timerTick += 1
            }
        }
    }

    // MARK: - Content View

    @ViewBuilder
    private var contentView: some View {
        switch viewModel.state {
        case .notCalibrated:
            notCalibratedView

        case .inProgress:
            inProgressView

        case .completed:
            completedView

        case let .failed(failure):
            failedView(failure: failure)
        }
    }

    // MARK: - Not Calibrated View

    private var notCalibratedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("Please assume good posture")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text("Face the camera and maintain a relaxed, good posture for 3 seconds.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 8)
    }

    // MARK: - In Progress View

    private var inProgressView: some View {
        VStack(spacing: 16) {
            // timerTickを使って再描画をトリガー（見えない形で）
            CalibrationProgressView(
                progress: viewModel.progress,
                remainingSeconds: viewModel.remainingSeconds
            )
            .id(timerTick)

            Text("Maintain your posture...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Completed View

    private var completedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.green)

            Text("Calibration Complete")
                .font(.subheadline)
                .foregroundStyle(.primary)

            Text("Your good posture has been recorded as the baseline.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Failed View

    private func failedView(failure: CalibrationFailure) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.orange)

            Text("Calibration Failed")
                .font(.subheadline)
                .foregroundStyle(.primary)

            if !failure.userMessage.isEmpty {
                Text(failure.userMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
        switch viewModel.state {
        case .notCalibrated, .failed:
            HStack(spacing: 12) {
                Button("Cancel") {
                    closeWindow()
                }
                .buttonStyle(.bordered)

                Button("Start") {
                    Task {
                        await viewModel.startCalibration()
                    }
                }
                .buttonStyle(.borderedProminent)
            }

        case .inProgress:
            Button("Cancel") {
                viewModel.cancelCalibration()
            }
            .buttonStyle(.bordered)

        case .completed:
            Button("Close") {
                closeWindow()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func closeWindow() {
        NSApp.keyWindow?.close()
    }
}
