//
//  FloweaseApp.swift
//  Flowease
//
//  Created by Daisuke Ooba on 2025/12/30.
//

import SwiftUI

// MARK: - WindowID

/// ウィンドウ識別子の定数
enum WindowID {
    static let calibration = "calibration"
}

// MARK: - FloweaseApp

/// Flowease アプリケーションのエントリポイント
///
/// メニューバーに常駐し、姿勢をモニタリングするアプリケーション。
/// `LSUIElement=true` により Dock には表示されない。
/// MenuBarExtra を使用して SwiftUI ネイティブなメニューを表示する。
@main
struct FloweaseApp: App {
    /// アプリケーション状態を管理
    @State private var appState = AppState()

    var body: some Scene {
        // メニューバーアイテム（ウィンドウスタイルで Picker が動作）
        MenuBarExtra {
            StatusMenuView(
                viewModel: appState.postureViewModel,
                calibrationViewModel: appState.calibrationViewModel,
                appState: appState
            )
            .frame(width: 280)
        } label: {
            // 動的アイコン（スコアに応じた色）
            Image(nsImage: appState.menuBarIcon)
        }
        .menuBarExtraStyle(.window)

        // キャリブレーションウィンドウ
        Window("Posture Calibration", id: WindowID.calibration) {
            CalibrationWindowView(viewModel: appState.calibrationViewModel)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}
