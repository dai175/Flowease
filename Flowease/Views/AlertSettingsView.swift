//
//  AlertSettingsView.swift
//  Flowease
//
//  通知設定画面
//

import SwiftUI

// MARK: - AlertSettings + Picker Options

extension AlertSettings {
    /// 評価期間の選択肢（ラベル, 秒数）
    static let evaluationPeriodOptions: [(label: LocalizedStringKey, value: Int)] = [
        ("1 min", 60),
        ("3 min", 180),
        ("5 min", 300),
        ("10 min", 600)
    ]

    /// 最短通知間隔の選択肢（ラベル, 秒数）
    static let minimumIntervalOptions: [(label: LocalizedStringKey, value: Int)] = [
        ("5 min", 300),
        ("15 min", 900),
        ("30 min", 1800),
        ("60 min", 3600)
    ]
}

// MARK: - AlertSettingsCard

/// 通知設定カード
///
/// StatusMenuView内に表示される通知設定のカードビュー。
/// ユーザーが閾値、評価期間、通知間隔を設定できる。
struct AlertSettingsCard: View {
    /// 現在の設定
    @Binding var settings: AlertSettings

    /// 設定変更時のコールバック
    let onSettingsChanged: (AlertSettings) -> Void

    /// 展開/折りたたみ状態
    @State private var isExpanded: Bool

    /// カラースキーム（スライダー・数値のカラー化に使用）
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Dynamic Type Support

    /// 展開ボタンのアイコンサイズ（Dynamic Type対応）
    @ScaledMetric(relativeTo: .caption) private var chevronSize: CGFloat = 12

    // MARK: - Initialization

    init(
        settings: Binding<AlertSettings>,
        onSettingsChanged: @escaping (AlertSettings) -> Void,
        initiallyExpanded: Bool = false
    ) {
        _settings = settings
        self.onSettingsChanged = onSettingsChanged
        _isExpanded = State(initialValue: initiallyExpanded)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // ヘッダー行
            headerRow

            // 展開時の設定項目
            if isExpanded {
                settingsContent
            }
        }
        .padding(12)
    }

    // MARK: - Header Row

    private var headerRow: some View {
        HStack(spacing: 8) {
            StatusBadge(
                systemName: settings.isEnabled ? "bell.fill" : "bell.slash",
                color: statusColor
            )

            VStack(alignment: .leading, spacing: 2) {
                Text("Alert Settings")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(statusSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            // 展開/折りたたみアイコン
            Image(systemName: "chevron.right")
                .font(.system(size: chevronSize, weight: .semibold))
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .hoverableRow(
            accessibilityLabel: Text(String(
                localized: "Alert Settings",
                comment: "Accessibility label for alert settings card"
            )),
            accessibilityValue: statusSummary,
            accessibilityHint: isExpanded
                ? String(localized: "Collapse settings", comment: "Accessibility label when settings expanded")
                : String(localized: "Expand settings", comment: "Accessibility label when settings collapsed")
        ) {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        }
    }

    // MARK: - Settings Content

    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
                .padding(.vertical, 4)

            // 通知有効/無効トグル
            enableToggle

            if settings.isEnabled {
                // 閾値スライダー
                thresholdSlider

                // 評価期間ピッカー
                evaluationPeriodPicker

                // 最短通知間隔ピッカー
                minimumIntervalPicker
            }
        }
    }

    // MARK: - Enable Toggle

    private var enableToggle: some View {
        Toggle(isOn: Binding(
            get: { settings.isEnabled },
            set: { newValue in
                settings.isEnabled = newValue
                onSettingsChanged(settings)
            }
        )) {
            Text("Enable Alerts")
                .font(.subheadline)
        }
        .toggleStyle(.switch)
        .controlSize(.small)
        .accessibilityLabel(
            String(localized: "Enable Alerts", comment: "Accessibility label for alert toggle")
        )
        .accessibilityHint(
            String(
                localized: "Double-tap to toggle posture alert notifications",
                comment: "Accessibility hint for alert toggle"
            )
        )
    }

    // MARK: - Threshold Slider

    private var thresholdColor: Color {
        ColorGradient.color(fromScore: settings.threshold, colorScheme: colorScheme)
    }

    private var thresholdSlider: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Score Threshold")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(settings.threshold)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(thresholdColor)
            }

            Slider(
                value: Binding(
                    get: { Double(settings.threshold) },
                    set: { newValue in
                        settings.threshold = Int(newValue)
                        onSettingsChanged(settings)
                    }
                ),
                in: Double(AlertSettings.thresholdRange.lowerBound) ...
                    Double(AlertSettings.thresholdRange.upperBound),
                step: 1
            )
            .tint(thresholdColor)
            .controlSize(.small)
            .accessibilityLabel(
                String(localized: "Score Threshold", comment: "Accessibility label for threshold slider")
            )
            .accessibilityValue("\(settings.threshold)")
            .accessibilityHint(
                String(
                    localized: "Adjust to set the minimum score that triggers an alert",
                    comment: "Accessibility hint for threshold slider"
                )
            )
        }
    }

    // MARK: - Settings Picker Row

    /// 設定用ピッカー行を生成
    private func settingsPickerRow(
        label: LocalizedStringKey,
        selection keyPath: WritableKeyPath<AlertSettings, Int>,
        options: [(label: LocalizedStringKey, value: Int)],
        accessibilityHintText: String
    ) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Picker("", selection: bindingWithCallback(keyPath)) {
                ForEach(options, id: \.value) { option in
                    Text(option.label).tag(option.value)
                }
            }
            .pickerStyle(.menu)
            .accessibilityLabel(Text(label))
            .accessibilityHint(accessibilityHintText)
        }
    }

    private var evaluationPeriodPicker: some View {
        settingsPickerRow(
            label: "Check Duration",
            selection: \.evaluationPeriodSeconds,
            options: AlertSettings.evaluationPeriodOptions,
            accessibilityHintText: String(
                localized: "Select how long posture must be poor before alerting",
                comment: "Accessibility hint for check duration picker"
            )
        )
    }

    private var minimumIntervalPicker: some View {
        settingsPickerRow(
            label: "Notification Cooldown",
            selection: \.minimumIntervalSeconds,
            options: AlertSettings.minimumIntervalOptions,
            accessibilityHintText: String(
                localized: "Select minimum time between consecutive alerts",
                comment: "Accessibility hint for cooldown picker"
            )
        )
    }

    // MARK: - Binding Helper

    /// 設定プロパティへの Binding を作成し、変更時にコールバックを呼び出す
    private func bindingWithCallback<T>(
        _ keyPath: WritableKeyPath<AlertSettings, T>
    ) -> Binding<T> {
        Binding(
            get: { settings[keyPath: keyPath] },
            set: { newValue in
                settings[keyPath: keyPath] = newValue
                onSettingsChanged(settings)
            }
        )
    }

    // MARK: - Computed Properties

    private var statusColor: Color {
        settings.isEnabled ? .blue : .gray
    }

    private var statusSummary: String {
        guard settings.isEnabled else {
            return String(localized: "Disabled")
        }
        let minutes = settings.evaluationPeriodMinutes
        return String(
            localized: "Alert if score stays below \(settings.threshold) for \(minutes) min"
        )
    }
}

// MARK: - Preview

#Preview("通知有効（折りたたみ）") {
    AlertSettingsCard(
        settings: .constant(.default),
        onSettingsChanged: { _ in }
    )
    .frame(width: 280)
    .padding()
}

#Preview("通知有効（展開）") {
    struct ExpandedPreview: View {
        @State private var settings = AlertSettings.default

        var body: some View {
            AlertSettingsCard(
                settings: $settings,
                onSettingsChanged: { _ in },
                initiallyExpanded: true
            )
            .frame(width: 280)
            .padding()
        }
    }
    return ExpandedPreview()
}

#Preview("通知無効") {
    AlertSettingsCard(
        settings: .constant(AlertSettings(
            isEnabled: false,
            threshold: 60,
            evaluationPeriodSeconds: 300,
            minimumIntervalSeconds: 900
        )),
        onSettingsChanged: { _ in }
    )
    .frame(width: 280)
    .padding()
}

#Preview("カスタム設定") {
    AlertSettingsCard(
        settings: .constant(AlertSettings(
            isEnabled: true,
            threshold: 45,
            evaluationPeriodSeconds: 180,
            minimumIntervalSeconds: 1800
        )),
        onSettingsChanged: { _ in }
    )
    .frame(width: 280)
    .padding()
}
