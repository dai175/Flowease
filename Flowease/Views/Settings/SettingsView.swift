//
//  SettingsView.swift
//  Flowease
//
//  Created by Daisuke Ooba on 2025/12/28.
//

import Combine
import SwiftUI

/// 設定画面
/// カメラ選択、休憩間隔、姿勢感度などの設定を管理
struct SettingsView: View {
    // MARK: - Properties

    /// 設定サービス
    @State private var settings: UserSettings = .default

    /// 選択されているタブ
    @State private var selectedTab: SettingsTab = .general

    /// 利用可能なカメラリスト（Phase 4 で CameraService から取得）
    @State private var availableCameras: [(id: String, name: String)] = []

    // MARK: - Body

    var body: some View {
        TabView(selection: $selectedTab) {
            generalSettingsTab
                .tabItem {
                    Label("一般", systemImage: "gear")
                }
                .tag(SettingsTab.general)

            postureSettingsTab
                .tabItem {
                    Label("姿勢検知", systemImage: "figure.stand")
                }
                .tag(SettingsTab.posture)

            breakSettingsTab
                .tabItem {
                    Label("休憩", systemImage: "clock")
                }
                .tag(SettingsTab.break)

            aboutTab
                .tabItem {
                    Label("情報", systemImage: "info.circle")
                }
                .tag(SettingsTab.about)
        }
        .frame(width: 450, height: 350)
        .onAppear {
            loadSettings()
        }
        .onChange(of: settings) { _, newValue in
            saveSettings(newValue)
        }
    }

    // MARK: - General Settings Tab

    /// 一般設定タブ
    private var generalSettingsTab: some View {
        Form {
            Section {
                Picker("カメラ", selection: $settings.selectedCameraID) {
                    Text("自動選択（デフォルトカメラ）")
                        .tag(nil as String?)

                    ForEach(availableCameras, id: \.id) { camera in
                        Text(camera.name)
                            .tag(camera.id as String?)
                    }
                }

                Toggle("通知を有効にする", isOn: $settings.notificationsEnabled)
            } header: {
                Text("基本設定")
            }

            Section {
                Toggle("姿勢モニタリングを有効にする", isOn: $settings.postureMonitoringEnabled)
                    .help("オフにすると、姿勢の検知と警告が無効になります")
            } header: {
                Text("モニタリング")
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Posture Settings Tab

    /// 姿勢検知設定タブ
    private var postureSettingsTab: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("姿勢判定の感度")
                        Spacer()
                        Text(sensitivityLabel)
                            .foregroundColor(.secondary)
                    }
                    Slider(
                        value: $settings.postureSensitivity,
                        in: 0.0 ... 1.0,
                        step: 0.1
                    )
                    Text("高いほど厳しく判定します")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("感度設定")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("前かがみ警告の閾値")
                        Spacer()
                        Text("\(Int(settings.forwardLeanThreshold))°")
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    Slider(
                        value: $settings.forwardLeanThreshold,
                        in: 5.0 ... 30.0,
                        step: 1.0
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("首傾き警告の閾値")
                        Spacer()
                        Text("\(Int(settings.neckTiltThreshold))°")
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    Slider(
                        value: $settings.neckTiltThreshold,
                        in: 10.0 ... 40.0,
                        step: 1.0
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("警告までの時間")
                        Spacer()
                        Text("\(Int(settings.badPostureAlertDelay))秒")
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    Slider(
                        value: $settings.badPostureAlertDelay,
                        in: 3.0 ... 10.0,
                        step: 1.0
                    )
                    Text("悪い姿勢がこの時間続くと通知します")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("閾値設定")
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Break Settings Tab

    /// 休憩設定タブ
    private var breakSettingsTab: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("休憩間隔")
                        Spacer()
                        Text("\(settings.breakIntervalMinutes)分")
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    Slider(
                        value: Binding(
                            get: { Double(settings.breakIntervalMinutes) },
                            set: { settings.breakIntervalMinutes = Int($0) }
                        ),
                        in: 30.0 ... 60.0,
                        step: 5.0
                    )
                    Text("この間隔で休憩を促す通知を送ります")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("休憩リマインダー")
            }

            Section {
                HStack {
                    Image(systemName: "lightbulb")
                        .foregroundColor(.yellow)
                    Text("定期的な休憩は、目の疲れや肩こりの軽減に効果的です。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("ヒント")
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - About Tab

    /// 情報タブ
    private var aboutTab: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "figure.mind.and.body")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)

            Text("Flowease")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("あなたの姿勢と健康をサポート")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("Version 1.0.0")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            VStack(spacing: 8) {
                Text("プライバシー")
                    .font(.headline)
                HStack {
                    Image(systemName: "lock.shield")
                        .foregroundColor(.green)
                    Text("カメラ映像はデバイス内でのみ処理され、\n外部に送信されることはありません。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )

            Spacer()

            Button("設定をリセット") {
                resetSettings()
            }
            .buttonStyle(.link)
            .foregroundColor(.red)
        }
        .padding()
    }

    // MARK: - Helper Properties

    /// 感度のラベル
    private var sensitivityLabel: String {
        switch settings.postureSensitivity {
        case 0.0 ..< 0.3:
            return "低い"
        case 0.3 ..< 0.7:
            return "普通"
        default:
            return "高い"
        }
    }

    // MARK: - Helper Methods

    /// 設定を読み込む
    private func loadSettings() {
        if ServiceContainer.shared.isSettingsServiceAvailable {
            settings = ServiceContainer.shared.settingsService.settings.value
        }
    }

    /// 設定を保存する
    /// - Parameter newSettings: 新しい設定
    private func saveSettings(_ newSettings: UserSettings) {
        if ServiceContainer.shared.isSettingsServiceAvailable {
            ServiceContainer.shared.settingsService.saveSettings(newSettings)
        }
    }

    /// 設定をリセットする
    private func resetSettings() {
        settings = .default
        if ServiceContainer.shared.isSettingsServiceAvailable {
            ServiceContainer.shared.settingsService.resetToDefaults()
        }
    }
}

// MARK: - Settings Tab

/// 設定画面のタブ
private enum SettingsTab: String, CaseIterable {
    case general
    case posture
    case `break`
    case about
}

// MARK: - Previews

#Preview {
    SettingsView()
}
