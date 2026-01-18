//
//  HoverableRow.swift
//  Flowease
//
//  行全体がクリック可能でホバー効果を持つ共通 ViewModifier
//

import SwiftUI

// MARK: - HoverableRowModifier

/// 行全体をクリック可能にし、ホバー時に背景色を変更する ViewModifier
///
/// メニュー内の各行に統一されたインタラクションを提供する。
/// - 行全体がクリック可能（contentShape による拡張）
/// - ホバー時に薄い背景色でフィードバック
/// - アクセシビリティ対応（ボタンとして認識）
private struct HoverableRowModifier: ViewModifier {
    /// タップ時のアクション
    let action: () -> Void

    /// アクセシビリティラベル
    let accessibilityLabelText: Text?

    /// アクセシビリティ値
    let accessibilityValueText: String?

    /// アクセシビリティヒント
    let accessibilityHintText: String?

    /// 背景の角丸半径
    let cornerRadius: CGFloat

    /// ホバー状態
    @State private var isHovered: Bool = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(isHovered ? Color.primary.opacity(0.05) : Color.clear)
            )
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
            .onHover { hovering in
                isHovered = hovering
            }
            .accessibilityElement(children: .combine)
            .modifier(AccessibilityModifier(
                label: accessibilityLabelText,
                value: accessibilityValueText,
                hint: accessibilityHintText
            ))
            .accessibilityAddTraits(.isButton)
    }
}

// MARK: - AccessibilityModifier

/// 条件付きでアクセシビリティ属性を追加する ViewModifier
private struct AccessibilityModifier: ViewModifier {
    let label: Text?
    let value: String?
    let hint: String?

    func body(content: Content) -> some View {
        content
            .modifier(OptionalAccessibilityLabel(label: label))
            .modifier(OptionalAccessibilityValue(value: value))
            .modifier(OptionalAccessibilityHint(hint: hint))
    }
}

// MARK: - OptionalAccessibilityLabel

private struct OptionalAccessibilityLabel: ViewModifier {
    let label: Text?

    func body(content: Content) -> some View {
        if let label {
            content.accessibilityLabel(label)
        } else {
            content
        }
    }
}

// MARK: - OptionalAccessibilityValue

private struct OptionalAccessibilityValue: ViewModifier {
    let value: String?

    func body(content: Content) -> some View {
        if let value {
            content.accessibilityValue(value)
        } else {
            content
        }
    }
}

// MARK: - OptionalAccessibilityHint

private struct OptionalAccessibilityHint: ViewModifier {
    let hint: String?

    func body(content: Content) -> some View {
        if let hint {
            content.accessibilityHint(hint)
        } else {
            content
        }
    }
}

// MARK: - View Extension

extension View {
    /// 行全体をクリック可能にし、ホバー時に背景色を変更する
    ///
    /// - Parameters:
    ///   - cornerRadius: 背景の角丸半径（デフォルト: 6）
    ///   - accessibilityLabel: アクセシビリティラベル
    ///   - accessibilityValue: アクセシビリティ値
    ///   - accessibilityHint: アクセシビリティヒント
    ///   - action: タップ時のアクション
    /// - Returns: ホバー効果が適用された View
    func hoverableRow(
        cornerRadius: CGFloat = 6,
        accessibilityLabel: Text? = nil,
        accessibilityValue: String? = nil,
        accessibilityHint: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        modifier(HoverableRowModifier(
            action: action,
            accessibilityLabelText: accessibilityLabel,
            accessibilityValueText: accessibilityValue,
            accessibilityHintText: accessibilityHint,
            cornerRadius: cornerRadius
        ))
    }
}
