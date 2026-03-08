//
//  FaceTrackingOverlayView.swift
//  Flowease
//
//  キャリブレーション画面用の顔トラッキングオーバーレイ
//

import SwiftUI

/// キャリブレーション時のカメラプレビュー上に表示するガイドラインオーバーレイ
///
/// 3つの要素を表示:
/// 1. 中心ターゲット（十字線）- 顔をどこに合わせるべきかのガイド
/// 2. リアルタイム顔トラッキング枠 - 検出された顔のバウンディングボックス
/// 3. 距離フィードバック - 顔の面積に基づく「近すぎ」「遠すぎ」メッセージ
struct FaceTrackingOverlayView: View {
    /// 現在検出中の顔位置（nil = 顔未検出）
    let facePosition: FacePosition?
    /// ガイドを表示するかどうか（notCalibrated or inProgress のとき true）
    let showGuide: Bool

    // MARK: - Constants

    /// 顔が近すぎると判定する面積しきい値
    private static let tooCloseAreaThreshold: Double = 0.25
    /// 顔が遠すぎると判定する面積しきい値
    private static let tooFarAreaThreshold: Double = 0.02
    /// 距離フィードバックメッセージ（ローカライズ検索を毎フレーム回避するためキャッシュ）
    private static let tooFarMessage = String(localized: "Move closer to the camera")
    private static let tooCloseMessage = String(localized: "Move further from the camera")

    var body: some View {
        GeometryReader { geometry in
            if showGuide {
                ZStack {
                    centerCrosshair(in: geometry.size)

                    if let face = facePosition {
                        faceTrackingRect(face: face, in: geometry.size)
                    }

                    if let message = distanceMessage {
                        distanceLabel(message, in: geometry.size)
                    }
                }
            }
        }
        .animation(.spring(response: 0.15), value: facePosition)
    }

    // MARK: - Center Crosshair

    /// プレビュー中央の十字線ガイド
    @ViewBuilder
    private func centerCrosshair(in size: CGSize) -> some View {
        let centerX = size.width / 2
        let centerY = size.height / 2
        let armLength: CGFloat = 12

        // 水平線
        Path { path in
            path.move(to: CGPoint(x: centerX - armLength, y: centerY))
            path.addLine(to: CGPoint(x: centerX + armLength, y: centerY))
        }
        .stroke(.white.opacity(0.4), lineWidth: 1)

        // 垂直線
        Path { path in
            path.move(to: CGPoint(x: centerX, y: centerY - armLength))
            path.addLine(to: CGPoint(x: centerX, y: centerY + armLength))
        }
        .stroke(.white.opacity(0.4), lineWidth: 1)
    }

    // MARK: - Face Tracking Rectangle

    /// 検出された顔のバウンディングボックスを表示
    ///
    /// Vision座標（Y=0が下端）→ SwiftUI座標（Y=0が上端）への変換を行う。
    /// カメラプレビューはミラーリング有効のため、X座標も反転する。
    private func faceTrackingRect(face: FacePosition, in size: CGSize) -> some View {
        // Vision座標 → SwiftUI座標変換（ミラーリング + Y反転）
        let rectWidth = face.width * size.width
        let rectHeight = face.height * size.height
        let swiftUIX = (1 - face.centerX) * size.width - rectWidth / 2
        let swiftUIY = (1 - face.centerY) * size.height - rectHeight / 2

        return RoundedRectangle(cornerRadius: 6)
            .stroke(.white.opacity(0.6), lineWidth: 1.5)
            .frame(width: rectWidth, height: rectHeight)
            .position(
                x: swiftUIX + rectWidth / 2,
                y: swiftUIY + rectHeight / 2
            )
    }

    // MARK: - Distance Feedback

    /// 顔の面積に基づく距離フィードバックメッセージ
    private var distanceMessage: String? {
        guard let face = facePosition else { return nil }

        if face.area > Self.tooCloseAreaThreshold {
            return Self.tooCloseMessage
        } else if face.area < Self.tooFarAreaThreshold {
            return Self.tooFarMessage
        }
        return nil
    }

    /// 距離フィードバックラベル
    private func distanceLabel(_ message: String, in size: CGSize) -> some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.black.opacity(0.6))
            .clipShape(Capsule())
            .position(x: size.width / 2, y: size.height - 20)
            .accessibilityLabel(message)
            .accessibilityAddTraits(.isStaticText)
    }
}
