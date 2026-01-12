//
//  ScoreStatus.swift
//  Flowease
//
//  Created by Claude on 2025/01/12.
//

import Foundation

// MARK: - ScoreStatus

/// スコアのステータス分類（Good/Fair/Poor）
///
/// スコア値を3段階のステータスに分類する。
/// - `good`: 80以上（良好な姿勢）
/// - `fair`: 60-79（普通の姿勢）
/// - `poor`: 60未満（改善が必要な姿勢）
enum ScoreStatus: Sendable, Equatable {
    case good
    case fair
    case poor

    /// スコア値からステータスを初期化
    /// - Parameter score: 0-100のスコア値
    init(score: Int) {
        switch score {
        case 80...: self = .good
        case 60 ..< 80: self = .fair
        default: self = .poor
        }
    }

    /// 表示用のローカライズされたラベル
    var label: String {
        switch self {
        case .good: String(localized: "Good")
        case .fair: String(localized: "Fair")
        case .poor: String(localized: "Poor")
        }
    }
}
