//
//  StatusBarView.swift
//  Flowease
//
//  Created by Daisuke Ooba on 2025/12/28.
//

import Combine
import SwiftUI

/// ステータスバーアイコンの状態を管理するビューモデル
/// メニューバーアイコンの色と表示を制御
@MainActor
public final class StatusBarViewModel: ObservableObject {
    // MARK: - Published Properties

    /// 現在の姿勢レベル
    @Published public var postureLevel: PostureLevel = .unknown

    /// 顔が検出されているか
    @Published public var isFaceDetected = false

    // MARK: - Computed Properties

    /// アイコンの色（NSColor）
    public var iconColor: NSColor {
        switch postureLevel {
        case .good:
            return NSColor(Color("PostureGoodColor"))
        case .warning:
            return NSColor(Color("PostureWarningColor"))
        case .bad:
            return NSColor(Color("PostureBadColor"))
        case .unknown:
            return NSColor(Color("PostureUnknownColor"))
        }
    }

    /// アイコンのシンボル名
    public var iconSymbolName: String {
        postureLevel.iconName
    }

    /// アクセシビリティの説明
    public var accessibilityDescription: String {
        "Flowease - \(postureLevel.displayName)"
    }

    // MARK: - Initialization

    public init(postureLevel: PostureLevel = .unknown, isFaceDetected: Bool = false) {
        self.postureLevel = postureLevel
        self.isFaceDetected = isFaceDetected
    }

    // MARK: - Methods

    /// 姿勢状態を更新
    /// - Parameter state: 新しい姿勢状態
    public func update(with state: PostureState) {
        postureLevel = state.level
        isFaceDetected = state.isFaceDetected
    }

    /// 姿勢レベルを直接更新
    /// - Parameter level: 新しい姿勢レベル
    public func update(level: PostureLevel) {
        postureLevel = level
    }
}

/// ステータスバーアイコンのプレビュー用ビュー
/// 実際のメニューバーアイコンは AppDelegate で NSStatusItem として管理
struct StatusBarIconPreview: View {
    let postureLevel: PostureLevel

    var body: some View {
        Image(systemName: postureLevel.iconName)
            .font(.system(size: Constants.UserInterface.statusBarIconSize))
            .foregroundColor(postureLevel.color)
            .accessibilityLabel("Flowease - \(postureLevel.displayName)")
    }
}

// MARK: - Previews

#Preview("Good Posture") {
    HStack(spacing: 20) {
        StatusBarIconPreview(postureLevel: .good)
        StatusBarIconPreview(postureLevel: .warning)
        StatusBarIconPreview(postureLevel: .bad)
        StatusBarIconPreview(postureLevel: .unknown)
    }
    .padding()
    .background(Color.black.opacity(0.8))
}
