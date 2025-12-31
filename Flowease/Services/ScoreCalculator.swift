// ScoreCalculator.swift
// Flowease
//
// 姿勢データからスコアを算出するロジック

import Foundation
import OSLog

// MARK: - ScoreCalculator

/// 姿勢データ (BodyPose) から姿勢スコア (PostureScore) を算出する
///
/// スコア構成要素（research.md に基づく）:
/// - 頭部傾斜 (30%): 首-鼻の垂直からの角度偏差
/// - 肩の水平バランス (25%): 左右肩のY座標差
/// - 前傾姿勢 (30%): 鼻のX座標と首の前後関係
/// - 左右対称性 (15%): 左右耳・肩の対称性
@MainActor
final class ScoreCalculator {
    // MARK: - Properties

    private let logger = Logger(subsystem: "cc.focuswave.Flowease", category: "ScoreCalculator")

    // MARK: - Score Weights

    /// 頭部傾斜の重み (30%)
    private let headTiltWeight: Double = 0.30

    /// 肩バランスの重み (25%)
    private let shoulderBalanceWeight: Double = 0.25

    /// 前傾姿勢の重み (30%)
    private let forwardLeanWeight: Double = 0.30

    /// 対称性の重み (15%)
    private let symmetryWeight: Double = 0.15

    // MARK: - Thresholds

    /// 頭部傾斜の許容偏差（正規化座標での水平方向のずれ）
    /// この値を超えるとスコアが減少し始める
    private let headTiltThreshold: Double = 0.02

    /// 頭部傾斜の最大偏差（これ以上でスコア0）
    private let headTiltMaxDeviation: Double = 0.15

    /// 肩バランスの許容偏差（Y座標の差）
    private let shoulderBalanceThreshold: Double = 0.02

    /// 肩バランスの最大偏差
    private let shoulderBalanceMaxDeviation: Double = 0.15

    /// 前傾姿勢の許容偏差（X座標のずれ）
    private let forwardLeanThreshold: Double = 0.03

    /// 前傾姿勢の最大偏差
    private let forwardLeanMaxDeviation: Double = 0.15

    /// 対称性の許容偏差
    private let symmetryThreshold: Double = 0.02

    /// 対称性の最大偏差
    private let symmetryMaxDeviation: Double = 0.15

    // MARK: - Initialization

    init() {
        logger.debug("ScoreCalculator 初期化完了")
    }

    // MARK: - Public Methods

    /// 姿勢データからスコアを計算
    /// - Parameter pose: 検出された姿勢データ
    /// - Returns: 姿勢スコア、または姿勢が無効な場合は nil
    func calculate(from pose: BodyPose) -> PostureScore? {
        // 姿勢の有効性をチェック（必須関節が検出されているか）
        guard pose.isValid else {
            logger.debug("無効な姿勢のためスコア計算をスキップ")
            return nil
        }

        // 必須関節を取得（isValid = true なら存在が保証される）
        guard let neck = pose.neck,
              let leftShoulder = pose.leftShoulder,
              let rightShoulder = pose.rightShoulder
        else {
            return nil
        }

        // 各構成要素のスコアを計算
        let headTiltScore = calculateHeadTiltScore(nose: pose.nose, neck: neck)
        let shoulderBalanceScore = calculateShoulderBalanceScore(
            leftShoulder: leftShoulder,
            rightShoulder: rightShoulder
        )
        let forwardLeanScore = calculateForwardLeanScore(nose: pose.nose, neck: neck)
        let symmetryScore = calculateSymmetryScore(
            leftShoulder: leftShoulder,
            rightShoulder: rightShoulder,
            leftEar: pose.leftEar,
            rightEar: pose.rightEar,
            neck: neck
        )

        // 加重平均で総合スコアを算出
        let weightedScore = Double(headTiltScore) * headTiltWeight
            + Double(shoulderBalanceScore) * shoulderBalanceWeight
            + Double(forwardLeanScore) * forwardLeanWeight
            + Double(symmetryScore) * symmetryWeight

        let totalScore = Int(weightedScore.rounded())

        // 信頼度は必須関節の平均信頼度
        let confidence = calculateConfidence(neck: neck, leftShoulder: leftShoulder, rightShoulder: rightShoulder)

        let breakdown = ScoreBreakdown(
            headTilt: headTiltScore,
            shoulderBalance: shoulderBalanceScore,
            forwardLean: forwardLeanScore,
            symmetry: symmetryScore
        )

        logger.debug(
            """
            スコア計算完了: total=\(totalScore), headTilt=\(headTiltScore), \
            shoulder=\(shoulderBalanceScore), lean=\(forwardLeanScore), symmetry=\(symmetryScore)
            """
        )

        return PostureScore(
            value: totalScore,
            timestamp: pose.timestamp,
            breakdown: breakdown,
            confidence: confidence
        )
    }

    // MARK: - Private Score Calculation Methods

    /// 頭部傾斜スコアを計算
    /// - Parameters:
    ///   - nose: 鼻の位置（オプショナル）
    ///   - neck: 首の位置
    /// - Returns: 頭部傾斜スコア (0-100)
    private func calculateHeadTiltScore(nose: JointPosition?, neck: JointPosition) -> Int {
        // 鼻が検出されていない場合はデフォルト値
        guard let nose else {
            return 70 // 中程度のスコア
        }

        // 首と鼻のX座標の差（水平方向のずれ）
        let horizontalDeviation = abs(nose.x - neck.x)

        return calculateScoreFromDeviation(
            deviation: horizontalDeviation,
            threshold: headTiltThreshold,
            maxDeviation: headTiltMaxDeviation
        )
    }

    /// 肩バランススコアを計算
    /// - Parameters:
    ///   - leftShoulder: 左肩の位置
    ///   - rightShoulder: 右肩の位置
    /// - Returns: 肩バランススコア (0-100)
    private func calculateShoulderBalanceScore(
        leftShoulder: JointPosition,
        rightShoulder: JointPosition
    ) -> Int {
        // 左右肩のY座標の差
        let verticalDeviation = abs(leftShoulder.y - rightShoulder.y)

        return calculateScoreFromDeviation(
            deviation: verticalDeviation,
            threshold: shoulderBalanceThreshold,
            maxDeviation: shoulderBalanceMaxDeviation
        )
    }

    /// 前傾姿勢スコアを計算
    /// - Parameters:
    ///   - nose: 鼻の位置（オプショナル）
    ///   - neck: 首の位置
    /// - Returns: 前傾姿勢スコア (0-100)
    private func calculateForwardLeanScore(nose: JointPosition?, neck: JointPosition) -> Int {
        // 鼻が検出されていない場合はデフォルト値
        guard let nose else {
            return 70
        }

        // 鼻と首のX座標の差（前傾はX座標が首より小さくなる方向と仮定）
        // Note: カメラ座標系では前傾すると鼻が首より手前に来る
        let forwardDeviation = max(0, neck.x - nose.x)

        return calculateScoreFromDeviation(
            deviation: forwardDeviation,
            threshold: forwardLeanThreshold,
            maxDeviation: forwardLeanMaxDeviation
        )
    }

    /// 対称性スコアを計算
    /// - Parameters:
    ///   - leftShoulder: 左肩の位置
    ///   - rightShoulder: 右肩の位置
    ///   - leftEar: 左耳の位置（オプショナル）
    ///   - rightEar: 右耳の位置（オプショナル）
    ///   - neck: 首の位置
    /// - Returns: 対称性スコア (0-100)
    private func calculateSymmetryScore(
        leftShoulder: JointPosition,
        rightShoulder: JointPosition,
        leftEar: JointPosition?,
        rightEar: JointPosition?,
        neck: JointPosition
    ) -> Int {
        var deviations: [Double] = []

        // 肩の中心からのずれ
        let shoulderCenterX = (leftShoulder.x + rightShoulder.x) / 2
        let shoulderDeviation = abs(shoulderCenterX - neck.x)
        deviations.append(shoulderDeviation)

        // 左右肩の首からの距離の差
        let leftShoulderDistance = abs(leftShoulder.x - neck.x)
        let rightShoulderDistance = abs(rightShoulder.x - neck.x)
        let shoulderDistanceDeviation = abs(leftShoulderDistance - rightShoulderDistance)
        deviations.append(shoulderDistanceDeviation)

        // 耳の対称性（両方検出されている場合のみ）
        if let leftEar, let rightEar {
            let leftEarDistance = abs(leftEar.x - neck.x)
            let rightEarDistance = abs(rightEar.x - neck.x)
            let earDeviation = abs(leftEarDistance - rightEarDistance)
            deviations.append(earDeviation)
        }

        // 平均偏差からスコアを算出
        let averageDeviation = deviations.reduce(0, +) / Double(deviations.count)

        return calculateScoreFromDeviation(
            deviation: averageDeviation,
            threshold: symmetryThreshold,
            maxDeviation: symmetryMaxDeviation
        )
    }

    /// 偏差からスコアを計算（線形減衰）
    /// - Parameters:
    ///   - deviation: 実際の偏差
    ///   - threshold: 許容偏差（これ以下は100点）
    ///   - maxDeviation: 最大偏差（これ以上は0点）
    /// - Returns: スコア (0-100)
    private func calculateScoreFromDeviation(
        deviation: Double,
        threshold: Double,
        maxDeviation: Double
    ) -> Int {
        if deviation <= threshold {
            return 100
        }

        if deviation >= maxDeviation {
            return 0
        }

        // 線形補間
        let range = maxDeviation - threshold
        let excess = deviation - threshold
        let ratio = excess / range
        let score = 100.0 * (1.0 - ratio)

        return Int(score.rounded())
    }

    /// 信頼度を計算（必須関節の平均信頼度）
    /// - Parameters:
    ///   - neck: 首の位置
    ///   - leftShoulder: 左肩の位置
    ///   - rightShoulder: 右肩の位置
    /// - Returns: 信頼度 (0.0-1.0)
    private func calculateConfidence(
        neck: JointPosition,
        leftShoulder: JointPosition,
        rightShoulder: JointPosition
    ) -> Double {
        let avgConfidence = (neck.confidence + leftShoulder.confidence + rightShoulder.confidence) / 3.0
        return min(max(avgConfidence, 0.0), 1.0)
    }
}
