//
//  PopoverView.swift
//  Flowease
//
//  Created by Daisuke Ooba on 2025/12/28.
//

import SwiftUI

/// メニューバーアイコンをクリックした際に表示されるポップオーバービュー
/// 姿勢スコア、次の休憩時間、ストレッチボタン、設定ボタンを表示
struct PopoverView: View {
    // MARK: - Properties

    /// 現在の姿勢レベル
    let postureLevel: PostureLevel

    /// 次の休憩までの残り時間（秒）（Phase 5 で実装）
    var timeUntilNextBreak: TimeInterval?

    /// 設定ボタンが押されたときのコールバック
    var onSettingsPressed: (() -> Void)?

    /// ストレッチボタンが押されたときのコールバック
    var onStretchPressed: (() -> Void)?

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // ヘッダー
            headerSection

            Divider()

            // メインコンテンツ
            VStack(spacing: 16) {
                postureStatusSection
                breakReminderSection
                actionButtonsSection
            }
            .padding()

            Divider()

            // フッター
            footerSection
        }
        .frame(width: Constants.UserInterface.Popover.width)
    }

    // MARK: - Sections

    /// ヘッダーセクション
    private var headerSection: some View {
        HStack {
            Image(systemName: "figure.mind.and.body")
                .font(.title2)
                .foregroundColor(.accentColor)

            Text("Flowease")
                .font(.headline)

            Spacer()
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
    }

    /// 姿勢状態セクション
    private var postureStatusSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("姿勢の状態")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
            }

            HStack(spacing: 12) {
                // 姿勢アイコン
                Image(systemName: postureLevel.iconName)
                    .font(.system(size: 40))
                    .foregroundColor(postureLevel.color)

                VStack(alignment: .leading, spacing: 4) {
                    Text(postureLevel.displayName)
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(postureStatusDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
        }
    }

    /// 姿勢状態の説明文
    private var postureStatusDescription: String {
        switch postureLevel {
        case .good:
            return "良い姿勢を維持しています"
        case .warning:
            return "姿勢が少し崩れています"
        case .bad:
            return "姿勢を正してください"
        case .unknown:
            return "カメラで姿勢を確認中..."
        }
    }

    /// 休憩リマインダーセクション（Phase 5 で詳細実装）
    private var breakReminderSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("次の休憩まで")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
            }

            HStack {
                Image(systemName: "clock")
                    .font(.title3)
                    .foregroundColor(.orange)

                if let remaining = timeUntilNextBreak {
                    Text(formatTimeInterval(remaining))
                        .font(.title3)
                        .fontWeight(.medium)
                        .monospacedDigit()
                } else {
                    Text("--:--")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
        }
    }

    /// アクションボタンセクション
    private var actionButtonsSection: some View {
        Button {
            onStretchPressed?()
        } label: {
            HStack {
                Image(systemName: "figure.flexibility")
                    .font(.title3)
                Text("今すぐストレッチ")
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .tint(.green)
    }

    /// フッターセクション
    private var footerSection: some View {
        HStack {
            Button {
                onSettingsPressed?()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "gear")
                    Text("設定")
                }
                .font(.footnote)
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)

            Spacer()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "power")
                    Text("終了")
                }
                .font(.footnote)
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
        }
        .padding()
    }

    // MARK: - Helper Methods

    /// 時間間隔をフォーマット
    /// - Parameter interval: 時間間隔（秒）
    /// - Returns: フォーマットされた文字列 (例: "25:30")
    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(interval)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Previews

#Preview("Good Posture") {
    PopoverView(
        postureLevel: .good,
        timeUntilNextBreak: 1530
    )
}

#Preview("Warning Posture") {
    PopoverView(
        postureLevel: .warning,
        timeUntilNextBreak: 900
    )
}

#Preview("Bad Posture") {
    PopoverView(
        postureLevel: .bad,
        timeUntilNextBreak: 300
    )
}

#Preview("Unknown - No Camera") {
    PopoverView(
        postureLevel: .unknown,
        timeUntilNextBreak: nil
    )
}
