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

    /// 基準姿勢（キャリブレーション済みの場合に設定）
    /// nilの場合は固定しきい値モードで動作
    private(set) var referencePosture: ReferencePosture?

    /// キャリブレーション済みかどうか
    var isCalibrated: Bool {
        referencePosture != nil
    }

    // MARK: - Score Weights (headTilt: 30%, shoulderBalance: 25%, forwardLean: 30%, symmetry: 15%)

    private let headTiltWeight: Double = 0.30
    private let shoulderBalanceWeight: Double = 0.25
    private let forwardLeanWeight: Double = 0.30
    private let symmetryWeight: Double = 0.15

    // MARK: - Thresholds (threshold: 減少開始, maxDeviation: スコア0)

    private let headTiltThreshold: Double = 0.02
    private let headTiltMaxDeviation: Double = 0.15
    private let shoulderBalanceThreshold: Double = 0.02
    private let shoulderBalanceMaxDeviation: Double = 0.15
    private let forwardLeanThreshold: Double = 0.03
    private let forwardLeanMaxDeviation: Double = 0.15
    private let symmetryThreshold: Double = 0.02
    private let symmetryMaxDeviation: Double = 0.15

    // MARK: - Initialization

    init() {
        logger.debug("ScoreCalculator 初期化完了")
    }

    // MARK: - Reference Posture

    /// 基準姿勢を設定（nilでクリア）
    func setReferencePosture(_ posture: ReferencePosture?) {
        referencePosture = posture
        if let posture { logger.debug("基準姿勢を設定: frameCount=\(posture.frameCount)") }
    }

    // MARK: - Public Methods

    /// 姿勢データからスコアを計算
    /// - Parameter pose: 検出された姿勢データ
    /// - Returns: 姿勢スコア、または姿勢が無効な場合は nil
    ///
    /// referencePostureが設定されている場合は基準姿勢からの逸脱度でスコアを計算。
    /// 設定されていない場合は固定しきい値モードでスコアを計算。
    func calculate(from pose: BodyPose) -> PostureScore? {
        // 姿勢の有効性をチェック（必須関節が検出されているか）
        guard pose.isValid else {
            logger.debug("無効な姿勢のためスコア計算をスキップ")
            return nil
        }

        guard let neck = pose.neck,
              let leftShoulder = pose.leftShoulder,
              let rightShoulder = pose.rightShoulder
        else {
            return nil
        }

        // 各構成要素のスコアを計算（キャリブレーションモードに応じて切り替え）
        let componentScores = calculateComponentScores(
            pose: pose,
            neck: neck,
            leftShoulder: leftShoulder,
            rightShoulder: rightShoulder
        )

        // 加重平均で総合スコアを算出
        let weightedScore = Double(componentScores.headTilt) * headTiltWeight
            + Double(componentScores.shoulderBalance) * shoulderBalanceWeight
            + Double(componentScores.forwardLean) * forwardLeanWeight
            + Double(componentScores.symmetry) * symmetryWeight

        let totalScore = Int(weightedScore.rounded())

        // 信頼度は必須関節の平均信頼度
        let confidence = calculateConfidence(neck: neck, leftShoulder: leftShoulder, rightShoulder: rightShoulder)

        logger.debug(
            """
            スコア計算完了: total=\(totalScore), headTilt=\(componentScores.headTilt), \
            shoulder=\(componentScores.shoulderBalance), lean=\(componentScores.forwardLean), \
            symmetry=\(componentScores.symmetry), calibrated=\(self.isCalibrated)
            """
        )

        return PostureScore(
            value: totalScore,
            timestamp: pose.timestamp,
            breakdown: componentScores,
            confidence: confidence
        )
    }

    // MARK: - Private Score Calculation Methods

    /// 各構成要素のスコアを計算
    private func calculateComponentScores(
        pose: BodyPose,
        neck: JointPosition,
        leftShoulder: JointPosition,
        rightShoulder: JointPosition
    ) -> ScoreBreakdown {
        if let reference = referencePosture {
            return calculateCalibratedScores(
                pose: pose,
                neck: neck,
                leftShoulder: leftShoulder,
                rightShoulder: rightShoulder,
                baseline: reference.baselineMetrics
            )
        } else {
            return calculateFixedThresholdScores(
                pose: pose,
                neck: neck,
                leftShoulder: leftShoulder,
                rightShoulder: rightShoulder
            )
        }
    }

    /// 固定しきい値モードでのスコア計算
    private func calculateFixedThresholdScores(
        pose: BodyPose,
        neck: JointPosition,
        leftShoulder: JointPosition,
        rightShoulder: JointPosition
    ) -> ScoreBreakdown {
        ScoreBreakdown(
            headTilt: calculateHeadTiltScore(nose: pose.nose, neck: neck),
            shoulderBalance: calculateShoulderBalanceScore(
                leftShoulder: leftShoulder,
                rightShoulder: rightShoulder
            ),
            forwardLean: calculateForwardLeanScore(nose: pose.nose, neck: neck),
            symmetry: calculateSymmetryScore(
                leftShoulder: leftShoulder,
                rightShoulder: rightShoulder,
                leftEar: pose.leftEar,
                rightEar: pose.rightEar,
                neck: neck
            )
        )
    }

    /// キャリブレーションモードでのスコア計算
    private func calculateCalibratedScores(
        pose: BodyPose,
        neck: JointPosition,
        leftShoulder: JointPosition,
        rightShoulder: JointPosition,
        baseline: BaselineMetrics
    ) -> ScoreBreakdown {
        ScoreBreakdown(
            headTilt: calculateCalibratedHeadTiltScore(
                nose: pose.nose,
                neck: neck,
                baseline: baseline
            ),
            shoulderBalance: calculateCalibratedShoulderBalanceScore(
                leftShoulder: leftShoulder,
                rightShoulder: rightShoulder,
                baseline: baseline
            ),
            forwardLean: calculateCalibratedForwardLeanScore(
                nose: pose.nose,
                neck: neck,
                baseline: baseline
            ),
            symmetry: calculateCalibratedSymmetryScore(
                pose: pose,
                neck: neck,
                baseline: baseline
            )
        )
    }

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

        // 鼻と首のY座標の差（前傾時は鼻が下がる = nose.yが小さくなる）
        // Vision座標系: Y=0が下端、Y=1が上端
        // 良い姿勢: nose.y > neck.y（鼻が首より上）
        // 前傾姿勢: nose.y が neck.y に近づく、または下回る
        let forwardDeviation = max(0, neck.y - nose.y)

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

    // MARK: - Calibrated Score Calculation Methods

    /// キャリブレーションモードでの頭部傾斜スコアを計算
    /// 基準姿勢からの逸脱度でスコアを計算
    private func calculateCalibratedHeadTiltScore(
        nose: JointPosition?,
        neck: JointPosition,
        baseline: BaselineMetrics
    ) -> Int {
        guard let nose else {
            return 70
        }

        // 現在の頭傾き（鼻と首のX座標差）
        let currentDeviation = nose.x - neck.x

        // 基準値からの逸脱
        let deviationFromBaseline = abs(currentDeviation - baseline.headTiltDeviation)

        return calculateScoreFromDeviation(
            deviation: deviationFromBaseline,
            threshold: headTiltThreshold,
            maxDeviation: headTiltMaxDeviation
        )
    }

    /// キャリブレーションモードでの肩バランススコアを計算
    private func calculateCalibratedShoulderBalanceScore(
        leftShoulder: JointPosition,
        rightShoulder: JointPosition,
        baseline: BaselineMetrics
    ) -> Int {
        // 現在の肩バランス（左右肩のY座標差）
        let currentBalance = leftShoulder.y - rightShoulder.y

        // 基準値からの逸脱
        let deviationFromBaseline = abs(currentBalance - baseline.shoulderBalance)

        return calculateScoreFromDeviation(
            deviation: deviationFromBaseline,
            threshold: shoulderBalanceThreshold,
            maxDeviation: shoulderBalanceMaxDeviation
        )
    }

    /// キャリブレーションモードでの前傾姿勢スコアを計算
    private func calculateCalibratedForwardLeanScore(
        nose: JointPosition?,
        neck: JointPosition,
        baseline: BaselineMetrics
    ) -> Int {
        guard let nose else {
            return 70
        }

        // 現在の前傾度（首と鼻のY座標差）
        // Vision座標系: Y=0が下端、Y=1が上端
        // 良い姿勢: nose.y > neck.y（鼻が首より上）
        // 前傾姿勢: nose.y が neck.y に近づく、または下回る
        let currentLean = max(0, neck.y - nose.y)

        // 基準値からの逸脱
        let deviationFromBaseline = abs(currentLean - baseline.forwardLean)

        return calculateScoreFromDeviation(
            deviation: deviationFromBaseline,
            threshold: forwardLeanThreshold,
            maxDeviation: forwardLeanMaxDeviation
        )
    }

    /// キャリブレーションモードでの対称性スコアを計算
    private func calculateCalibratedSymmetryScore(
        pose: BodyPose,
        neck: JointPosition,
        baseline: BaselineMetrics
    ) -> Int {
        guard let leftShoulder = pose.leftShoulder,
              let rightShoulder = pose.rightShoulder
        else {
            return 70
        }

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

        // 耳の対称性
        if let leftEar = pose.leftEar, let rightEar = pose.rightEar {
            let leftEarDistance = abs(leftEar.x - neck.x)
            let rightEarDistance = abs(rightEar.x - neck.x)
            let earDeviation = abs(leftEarDistance - rightEarDistance)
            deviations.append(earDeviation)
        }

        // 現在の対称性
        let currentSymmetry = deviations.isEmpty ? 0 : deviations.reduce(0, +) / Double(deviations.count)

        // 基準値からの逸脱
        let deviationFromBaseline = abs(currentSymmetry - baseline.symmetry)

        return calculateScoreFromDeviation(
            deviation: deviationFromBaseline,
            threshold: symmetryThreshold,
            maxDeviation: symmetryMaxDeviation
        )
    }
}
