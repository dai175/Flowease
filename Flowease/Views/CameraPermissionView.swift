//
//  CameraPermissionView.swift
//  Flowease
//
//  カメラ権限が拒否または制限されている場合に表示するビュー
//

import AppKit
import SwiftUI

/// カメラ権限エラー時のメッセージと対処法を表示するビュー
///
/// `DisableReason` に応じて適切なメッセージとアクションを提供する。
/// - `cameraPermissionDenied`: システム設定への誘導ボタンを表示
/// - `cameraPermissionRestricted`: 管理者への連絡を案内
/// - `noCameraAvailable`: 外部カメラ接続を案内
struct CameraPermissionView: View {
    /// 表示する無効化理由
    let reason: DisableReason

    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            // アイコン
            Image(systemName: iconName)
                .font(.system(size: 32))
                .foregroundStyle(.secondary)

            // タイトル（エラーの説明）
            Text(reason.description)
                .font(.headline)
                .multilineTextAlignment(.center)

            // 対処法の案内
            Text(reason.actionHint)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            // システム設定ボタン（権限拒否の場合のみ）
            if reason == .cameraPermissionDenied {
                Button("システム設定を開く") {
                    openSystemSettings()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding()
        .frame(maxWidth: 280)
    }

    // MARK: - Private

    /// 理由に応じたSFSymbolアイコン名
    private var iconName: String {
        switch reason {
        case .cameraPermissionDenied:
            "camera.fill"
        case .cameraPermissionRestricted:
            "lock.fill"
        case .noCameraAvailable:
            "video.slash.fill"
        }
    }

    /// システム設定のプライバシー > カメラを開く
    private func openSystemSettings() {
        // macOS 13+ のシステム設定URL
        if let url = URL(string: "x-apple.systemsettings:com.apple.settings.PrivacySecurity.extension?Privacy_Camera") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Previews

#Preview("権限拒否") {
    CameraPermissionView(reason: .cameraPermissionDenied)
}

#Preview("権限制限") {
    CameraPermissionView(reason: .cameraPermissionRestricted)
}

#Preview("カメラなし") {
    CameraPermissionView(reason: .noCameraAvailable)
}
