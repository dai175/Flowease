import Foundation
import SwiftUI

/// 姿勢の判定レベル
public enum PostureLevel: String, Codable, CaseIterable, Sendable {
    case good // 良い姿勢
    case warning // 注意
    case bad // 悪い姿勢
    case unknown // 顔未検出・判定不能

    /// メニューバーアイコンの色
    public var color: Color {
        switch self {
        case .good: return Color("PostureGoodColor")
        case .warning: return Color("PostureWarningColor")
        case .bad: return Color("PostureBadColor")
        case .unknown: return Color("PostureUnknownColor")
        }
    }

    /// SF Symbolsアイコン名
    public var iconName: String {
        switch self {
        case .good: return "figure.stand"
        case .warning: return "exclamationmark.triangle.fill"
        case .bad: return "xmark.circle.fill"
        case .unknown: return "questionmark.circle"
        }
    }

    /// ローカライズされた表示名
    public var displayName: String {
        switch self {
        case .good: return "良好"
        case .warning: return "注意"
        case .bad: return "要改善"
        case .unknown: return "未検出"
        }
    }
}

/// 姿勢状態モデル
public struct PostureState: Sendable {
    /// 現在の姿勢レベル
    public var level: PostureLevel

    /// 姿勢スコア（0.0〜1.0、1.0が最良）
    public var score: Double

    /// 前かがみ角度（度）
    public var forwardLeanAngle: Double

    /// 首の傾き角度（度）
    public var neckTiltAngle: Double

    /// 最終更新時刻
    public var lastUpdated: Date

    /// 悪い姿勢が続いている時間（秒）
    public var badPostureDuration: TimeInterval

    /// 顔が検出されているか
    public var isFaceDetected: Bool

    public init(
        level: PostureLevel,
        score: Double,
        forwardLeanAngle: Double,
        neckTiltAngle: Double,
        lastUpdated: Date = Date(),
        badPostureDuration: TimeInterval = 0,
        isFaceDetected: Bool = true
    ) {
        self.level = level
        self.score = max(0.0, min(1.0, score))
        self.forwardLeanAngle = max(0.0, min(90.0, forwardLeanAngle))
        self.neckTiltAngle = max(0.0, min(90.0, neckTiltAngle))
        self.lastUpdated = lastUpdated
        self.badPostureDuration = max(0.0, badPostureDuration)
        self.isFaceDetected = isFaceDetected
    }

    /// スコアに基づいて姿勢レベルを自動計算する初期化
    public init(
        score: Double,
        forwardLeanAngle: Double,
        neckTiltAngle: Double,
        badPostureDuration: TimeInterval = 0,
        isFaceDetected: Bool = true
    ) {
        let clampedScore = max(0.0, min(1.0, score))
        let level: PostureLevel
        if clampedScore >= Constants.PostureDetection.ScoreThreshold.good {
            level = .good
        } else if clampedScore >= Constants.PostureDetection.ScoreThreshold.warning {
            level = .warning
        } else {
            level = .bad
        }

        self.init(
            level: level,
            score: clampedScore,
            forwardLeanAngle: forwardLeanAngle,
            neckTiltAngle: neckTiltAngle,
            badPostureDuration: badPostureDuration,
            isFaceDetected: isFaceDetected
        )
    }
}

// MARK: - Default Values

public extension PostureState {
    /// 検出なし状態（顔が検出されていない）
    static let notDetected = PostureState(
        level: .unknown,
        score: 0.0,
        forwardLeanAngle: 0.0,
        neckTiltAngle: 0.0,
        isFaceDetected: false
    )
}
