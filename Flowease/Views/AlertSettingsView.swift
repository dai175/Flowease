//
//  AlertSettingsView.swift
//  Flowease
//
//  通知設定画面
//

import SwiftUI

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
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.controlBackgroundColor))
        )
    }

    // MARK: - Header Row

    private var headerRow: some View {
        HStack(spacing: 8) {
            // ステータスアイコン（円形バッジ）
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 28, height: 28)
                Image(systemName: settings.isEnabled ? "bell.fill" : "bell.slash")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(statusColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Alert Settings")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(statusSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // 展開/折りたたみボタン
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .buttonStyle(.plain)
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
    }

    // MARK: - Threshold Slider

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
                    .foregroundStyle(.primary)
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
            .controlSize(.small)

            Text("alert.threshold.description")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Evaluation Period Picker

    private var evaluationPeriodPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Evaluation Period")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("", selection: bindingWithCallback(\.evaluationPeriodSeconds)) {
                Text("1 min").tag(60)
                Text("3 min").tag(180)
                Text("5 min").tag(300)
                Text("10 min").tag(600)
            }
            .pickerStyle(.menu)
        }
    }

    // MARK: - Minimum Interval Picker

    private var minimumIntervalPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Minimum Interval")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("", selection: bindingWithCallback(\.minimumIntervalSeconds)) {
                Text("5 min").tag(300)
                Text("15 min").tag(900)
                Text("30 min").tag(1800)
                Text("60 min").tag(3600)
            }
            .pickerStyle(.menu)
        }
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
        return String(
            localized: "Threshold: \(settings.threshold), Period: \(settings.evaluationPeriodSeconds / 60) min"
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
