// FaceScoreCalculator.swift
// Flowease
//
// 顔検出ベースのスコア計算サービス

import Foundation
import OSLog

// MARK: - FaceScoreCalculatorProtocol

/// 顔ベーススコア計算プロトコル
///
/// テスト可能性のために FaceScoreCalculator の抽象化を提供する。
@MainActor
protocol FaceScoreCalculatorProtocol: AnyObject {
    /// 基準姿勢（キャリブレーション済みの場合に設定）
    var referencePosture: FaceReferencePosture? { get }

    /// キャリブレーション済みかどうか
    var isCalibrated: Bool { get }

    /// 基準姿勢を設定（nilでクリア）
    func setReferencePosture(_ posture: FaceReferencePosture?)

    /// 顔位置データからスコアを計算
    /// - Parameter face: 検出された顔位置データ
    /// - Returns: 姿勢スコア、または顔データが無効な場合は nil
    func calculate(from face: FacePosition) -> PostureScore?
}

// MARK: - FaceScoreCalculator

/// 顔検出ベースのスコア計算の実装
///
/// 顔の位置・サイズ・傾きから姿勢スコアを算出する。
/// スコア構成要素（spec.mdに基づく）:
/// - 垂直位置変化 (40%): 顔のY座標の下方変化（うつむき検出）
/// - サイズ変化 (40%): 顔面積の増加（前傾検出）
/// - 傾き (20%): roll角の変化（首の傾き検出）
@MainActor
final class FaceScoreCalculator: FaceScoreCalculatorProtocol {
    // MARK: - Properties

    private let logger = Logger(subsystem: "cc.focuswave.Flowease", category: "FaceScoreCalculator")

    /// 基準姿勢（キャリブレーション済みの場合に設定）
    private(set) var referencePosture: FaceReferencePosture?

    /// キャリブレーション済みかどうか
    var isCalibrated: Bool {
        referencePosture != nil
    }

    // MARK: - Score Weights

    private let verticalPositionWeight: Double = 0.40
    private let sizeChangeWeight: Double = 0.40
    private let tiltWeight: Double = 0.20

    // MARK: - Thresholds (threshold: 減少開始, maxDeviation: スコア0)

    private let verticalThreshold: Double = 0.02
    private let verticalMaxDeviation: Double = 0.15
    private let sizeThreshold: Double = 0.05
    private let sizeMaxDeviation: Double = 0.30
    private let tiltThreshold: Double = 0.05 // ~3°
    private let tiltMaxDeviation: Double = 0.35 // ~20°

    // MARK: - Initialization

    init() {
        logger.debug("FaceScoreCalculator 初期化完了")
    }

    // MARK: - Reference Posture

    /// 基準姿勢を設定（nilでクリア）
    func setReferencePosture(_ posture: FaceReferencePosture?) {
        referencePosture = posture
        if let posture {
            logger.debug("基準姿勢を設定: frameCount=\(posture.frameCount)")
        }
    }

    // MARK: - Public Methods

    /// 顔位置データからスコアを計算
    /// - Parameter face: 検出された顔位置データ
    /// - Returns: 姿勢スコア、または基準姿勢が未設定の場合は nil
    func calculate(from face: FacePosition) -> PostureScore? {
        // 基準姿勢が未設定の場合はスコア計算不可
        guard let reference = referencePosture else {
            logger.debug("基準姿勢未設定のためスコア計算をスキップ")
            return nil
        }

        let baseline = reference.baselineMetrics

        // 各構成要素のスコアを計算
        let verticalScore = calculateVerticalPositionScore(face: face, baseline: baseline)
        let sizeScore = calculateSizeChangeScore(face: face, baseline: baseline)
        let tiltScore = calculateTiltScore(face: face, baseline: baseline)

        // 加重平均で総合スコアを算出
        let weightedScore = Double(verticalScore) * verticalPositionWeight
            + Double(sizeScore) * sizeChangeWeight
            + Double(tiltScore) * tiltWeight

        let totalScore = Int(weightedScore.rounded())

        logger.debug(
            """
            スコア計算完了: total=\(totalScore), vertical=\(verticalScore), \
            size=\(sizeScore), tilt=\(tiltScore)
            """
        )

        return PostureScore(
            value: totalScore,
            timestamp: face.timestamp,
            breakdown: ScoreBreakdown(
                verticalPosition: verticalScore,
                sizeChange: sizeScore,
                tilt: tiltScore
            ),
            confidence: face.captureQuality
        )
    }

    // MARK: - Private Score Calculation Methods

    /// 垂直位置スコアを計算（片方向：Y低下のみ）
    private func calculateVerticalPositionScore(face: FacePosition, baseline: FaceBaselineMetrics) -> Int {
        let yDeviation = max(0, baseline.baselineY - face.centerY)
        return calculateScoreFromDeviation(
            deviation: yDeviation,
            threshold: verticalThreshold,
            maxDeviation: verticalMaxDeviation
        )
    }

    /// サイズ変化スコアを計算（片方向：増加のみ）
    private func calculateSizeChangeScore(face: FacePosition, baseline: FaceBaselineMetrics) -> Int {
        guard baseline.baselineArea > 0 else { return 100 }
        let sizeRatio = (face.area - baseline.baselineArea) / baseline.baselineArea
        let sizeDeviation = max(0, sizeRatio)
        return calculateScoreFromDeviation(
            deviation: sizeDeviation,
            threshold: sizeThreshold,
            maxDeviation: sizeMaxDeviation
        )
    }

    /// 傾きスコアを計算（両方向、ラップアラウンド考慮）
    private func calculateTiltScore(face: FacePosition, baseline: FaceBaselineMetrics) -> Int {
        guard let roll = face.roll else {
            return 70 // roll未取得時のデフォルト
        }

        let diff = roll - baseline.baselineRoll
        let absDiff = abs(diff)
        // ラップアラウンド考慮: 最小角度差を使用
        let tiltDeviation = min(absDiff, 2 * .pi - absDiff)

        return calculateScoreFromDeviation(
            deviation: tiltDeviation,
            threshold: tiltThreshold,
            maxDeviation: tiltMaxDeviation
        )
    }

    /// 偏差からスコアを計算（線形減衰）
    private func calculateScoreFromDeviation(
        deviation: Double,
        threshold: Double,
        maxDeviation: Double
    ) -> Int {
        if deviation <= threshold { return 100 }
        if deviation >= maxDeviation { return 0 }

        let range = maxDeviation - threshold
        let excess = deviation - threshold
        let ratio = excess / range
        return Int((100.0 * (1.0 - ratio)).rounded())
    }
}
