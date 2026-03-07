import Testing
import Foundation
@testable import Flowease

/// FaceScoreCalculatorサービスのテスト
///
/// TDD: T010 - スコア計算ロジックを検証
///
/// 仕様（spec.md「スコア算出仕様」参照）:
/// - 垂直位置変化（40%）: Y座標低下のみ減点（片方向）
/// - サイズ変化（40%）: 面積増加のみ減点（片方向）
/// - 傾き（20%）: roll角変化で減点（両方向、ラップアラウンド考慮）
@MainActor
struct FaceScoreCalculatorTests {
    // MARK: - Test Fixtures

    /// テスト用の基準姿勢を生成
    private func makeReferencePosture(
        baselineY: Double = 0.5,
        baselineArea: Double = 0.04,
        baselineRoll: Double = 0.0
    ) -> FaceReferencePosture {
        FaceReferencePosture(
            calibratedAt: Date(),
            frameCount: 30,
            averageQuality: 0.8,
            baselineMetrics: FaceBaselineMetrics(
                baselineY: baselineY,
                baselineArea: baselineArea,
                baselineRoll: baselineRoll
            )
        )
    }

    /// テスト用の顔位置を生成
    private func makeFacePosition(
        centerX: Double = 0.5,
        centerY: Double = 0.5,
        area: Double = 0.04,
        roll: Double? = 0.0,
        captureQuality: Double = 0.8
    ) -> FacePosition {
        FacePosition(
            centerX: centerX,
            centerY: centerY,
            area: area,
            width: sqrt(area),
            height: sqrt(area),
            roll: roll,
            captureQuality: captureQuality,
            timestamp: Date()
        )
    }

    // MARK: - Initialization Tests

    /// FaceScoreCalculatorがプロトコルに準拠していることを確認
    @Test func conformsToProtocol() {
        let calculator = FaceScoreCalculator()
        #expect(calculator is FaceScoreCalculatorProtocol)
    }

    /// 初期状態ではキャリブレーションされていない
    @Test func initialStateNotCalibrated() {
        let calculator = FaceScoreCalculator()
        #expect(!calculator.isCalibrated)
        #expect(calculator.referencePosture == nil)
    }

    // MARK: - Reference Posture Tests

    /// 基準姿勢を設定できる
    @Test func setReferencePosture() {
        let calculator = FaceScoreCalculator()
        let reference = makeReferencePosture()

        calculator.setReferencePosture(reference)

        #expect(calculator.isCalibrated)
        #expect(calculator.referencePosture != nil)
    }

    /// 基準姿勢をnilでクリアできる
    @Test func clearReferencePosture() {
        let calculator = FaceScoreCalculator()
        let reference = makeReferencePosture()

        calculator.setReferencePosture(reference)
        calculator.setReferencePosture(nil)

        #expect(!calculator.isCalibrated)
        #expect(calculator.referencePosture == nil)
    }

    /// 基準姿勢が未設定の場合はnilを返す
    @Test func calculateReturnsNilWithoutReference() {
        let calculator = FaceScoreCalculator()
        let face = makeFacePosition()

        let score = calculator.calculate(from: face)

        #expect(score == nil)
    }

    // MARK: - Perfect Score Tests (100点)

    /// 基準姿勢と同じ位置では100点
    @Test func perfectScoreAtBaseline() {
        let calculator = FaceScoreCalculator()
        let reference = makeReferencePosture(
            baselineY: 0.5,
            baselineArea: 0.04,
            baselineRoll: 0.0
        )
        calculator.setReferencePosture(reference)

        let face = makeFacePosition(
            centerY: 0.5,
            area: 0.04,
            roll: 0.0
        )

        let score = calculator.calculate(from: face)

        #expect(score != nil)
        #expect(score?.value == 100)
        #expect(score?.breakdown.verticalPosition == 100)
        #expect(score?.breakdown.sizeChange == 100)
        #expect(score?.breakdown.tilt == 100)
    }

    // MARK: - Vertical Position Score Tests (T015)

    /// Y座標がしきい値以下の場合は100点
    @Test func verticalPositionScoreWithinThreshold() {
        let calculator = FaceScoreCalculator()
        let reference = makeReferencePosture(baselineY: 0.5)
        calculator.setReferencePosture(reference)

        // しきい値0.02以下の低下
        let face = makeFacePosition(centerY: 0.49)

        let score = calculator.calculate(from: face)

        #expect(score?.breakdown.verticalPosition == 100)
    }

    /// Y座標が低下すると減点（うつむき検出）
    @Test func verticalPositionScoreDecreasesWithYDrop() {
        let calculator = FaceScoreCalculator()
        let reference = makeReferencePosture(baselineY: 0.5)
        calculator.setReferencePosture(reference)

        // しきい値0.02を超える低下（0.08低下 = 中程度の逸脱）
        let face = makeFacePosition(centerY: 0.42)

        let score = calculator.calculate(from: face)

        // 線形補間: (0.08 - 0.02) / (0.15 - 0.02) = 0.46 → 100 * (1 - 0.46) ≈ 54
        #expect(score?.breakdown.verticalPosition ?? 0 < 100)
        #expect(score?.breakdown.verticalPosition ?? 0 > 0)
    }

    /// Y座標が最大逸脱以上の場合は0点
    @Test func verticalPositionScoreZeroAtMaxDeviation() {
        let calculator = FaceScoreCalculator()
        let reference = makeReferencePosture(baselineY: 0.5)
        calculator.setReferencePosture(reference)

        // 最大逸脱0.15以上の低下
        let face = makeFacePosition(centerY: 0.35)

        let score = calculator.calculate(from: face)

        #expect(score?.breakdown.verticalPosition == 0)
    }

    /// Y座標が上がっても減点なし（片方向評価）
    @Test func verticalPositionScoreNoDeductionWhenYIncreases() {
        let calculator = FaceScoreCalculator()
        let reference = makeReferencePosture(baselineY: 0.5)
        calculator.setReferencePosture(reference)

        // Y座標が上がる（顔が上を向く）
        let face = makeFacePosition(centerY: 0.7)

        let score = calculator.calculate(from: face)

        #expect(score?.breakdown.verticalPosition == 100)
    }

    // MARK: - Size Change Score Tests (T016)

    /// 面積がしきい値以下の場合は100点
    @Test func sizeChangeScoreWithinThreshold() {
        let calculator = FaceScoreCalculator()
        let reference = makeReferencePosture(baselineArea: 0.04)
        calculator.setReferencePosture(reference)

        // しきい値5%以下の増加
        let face = makeFacePosition(area: 0.042)

        let score = calculator.calculate(from: face)

        #expect(score?.breakdown.sizeChange == 100)
    }

    /// 面積が増加すると減点（前傾検出）
    @Test func sizeChangeScoreDecreasesWithAreaIncrease() {
        let calculator = FaceScoreCalculator()
        let reference = makeReferencePosture(baselineArea: 0.04)
        calculator.setReferencePosture(reference)

        // 15%増加 = 中程度の逸脱
        let face = makeFacePosition(area: 0.046)

        let score = calculator.calculate(from: face)

        // 線形補間: (0.15 - 0.05) / (0.30 - 0.05) = 0.4 → 100 * (1 - 0.4) = 60
        #expect(score?.breakdown.sizeChange ?? 0 < 100)
        #expect(score?.breakdown.sizeChange ?? 0 > 0)
    }

    /// 面積が最大逸脱（30%増加）以上の場合は0点
    @Test func sizeChangeScoreZeroAtMaxDeviation() {
        let calculator = FaceScoreCalculator()
        let reference = makeReferencePosture(baselineArea: 0.04)
        calculator.setReferencePosture(reference)

        // 30%以上増加
        let face = makeFacePosition(area: 0.052)

        let score = calculator.calculate(from: face)

        #expect(score?.breakdown.sizeChange == 0)
    }

    /// 面積が減少しても減点なし（片方向評価）
    @Test func sizeChangeScoreNoDeductionWhenAreaDecreases() {
        let calculator = FaceScoreCalculator()
        let reference = makeReferencePosture(baselineArea: 0.04)
        calculator.setReferencePosture(reference)

        // 面積が減少（後ろに下がる）
        let face = makeFacePosition(area: 0.02)

        let score = calculator.calculate(from: face)

        #expect(score?.breakdown.sizeChange == 100)
    }

    // MARK: - Tilt Score Tests (T017)

    /// 傾きがしきい値以下の場合は100点
    @Test func tiltScoreWithinThreshold() {
        let calculator = FaceScoreCalculator()
        let reference = makeReferencePosture(baselineRoll: 0.0)
        calculator.setReferencePosture(reference)

        // しきい値0.05ラジアン以下の傾き
        let face = makeFacePosition(roll: 0.04)

        let score = calculator.calculate(from: face)

        #expect(score?.breakdown.tilt == 100)
    }

    /// 傾きが増加すると減点（首の傾き検出）
    @Test func tiltScoreDecreasesWithRollChange() {
        let calculator = FaceScoreCalculator()
        let reference = makeReferencePosture(baselineRoll: 0.0)
        calculator.setReferencePosture(reference)

        // 0.2ラジアンの傾き（約11度）
        let face = makeFacePosition(roll: 0.2)

        let score = calculator.calculate(from: face)

        // 線形補間: (0.2 - 0.05) / (0.35 - 0.05) = 0.5 → 100 * (1 - 0.5) = 50
        #expect(score?.breakdown.tilt ?? 0 < 100)
        #expect(score?.breakdown.tilt ?? 0 > 0)
    }

    /// 傾きが最大逸脱以上の場合は0点
    @Test func tiltScoreZeroAtMaxDeviation() {
        let calculator = FaceScoreCalculator()
        let reference = makeReferencePosture(baselineRoll: 0.0)
        calculator.setReferencePosture(reference)

        // 最大逸脱0.35ラジアン以上の傾き
        let face = makeFacePosition(roll: 0.4)

        let score = calculator.calculate(from: face)

        #expect(score?.breakdown.tilt == 0)
    }

    /// 負の方向への傾きも減点（両方向評価）
    @Test func tiltScoreDeductionForNegativeRoll() throws {
        let calculator = FaceScoreCalculator()
        let reference = makeReferencePosture(baselineRoll: 0.0)
        calculator.setReferencePosture(reference)

        // 負方向に0.2ラジアンの傾き
        let face = makeFacePosition(roll: -0.2)

        let score = calculator.calculate(from: face)

        // 正方向と同じスコア
        let tiltScore = try #require(score?.breakdown.tilt)
        #expect(tiltScore < 100)
        #expect(tiltScore > 0)
    }

    /// ラップアラウンド: π付近からの変化（反時計回り）
    @Test func tiltScoreWraparoundFromPositivePi() throws {
        let calculator = FaceScoreCalculator()
        // 基準がπに近い位置
        let reference = makeReferencePosture(baselineRoll: 3.0)
        calculator.setReferencePosture(reference)

        // -πに近い位置（実際は短い距離）
        // 差分 = -3.0 - 3.0 = -6.0、ラップアラウンドで最小距離 = 2π - 6.0 ≈ 0.28
        let face = makeFacePosition(roll: -3.0)

        let score = calculator.calculate(from: face)

        // 0.28はしきい値(0.05)を超えるが最大逸脱(0.35)未満
        let tiltScore = try #require(score?.breakdown.tilt)
        #expect(tiltScore < 100)
        #expect(tiltScore > 0)
    }

    /// ラップアラウンド: -π付近から+π付近への変化
    @Test func tiltScoreWraparoundAcrossPi() throws {
        let calculator = FaceScoreCalculator()
        // 基準が-πに近い位置
        let reference = makeReferencePosture(baselineRoll: -.pi + 0.1)
        calculator.setReferencePosture(reference)

        // +πに近い位置（実際は短い距離 ≈ 0.2）
        let face = makeFacePosition(roll: .pi - 0.1)

        let score = calculator.calculate(from: face)

        // 最小距離は約0.2（しきい値を超えるが最大逸脱未満）
        let tiltScore = try #require(score?.breakdown.tilt)
        #expect(tiltScore < 100)
        #expect(tiltScore > 0)
    }

    /// rollがnilの場合は70点（デフォルト）
    @Test func tiltScoreDefaultWhenRollIsNil() {
        let calculator = FaceScoreCalculator()
        let reference = makeReferencePosture()
        calculator.setReferencePosture(reference)

        let face = makeFacePosition(roll: nil)

        let score = calculator.calculate(from: face)

        #expect(score?.breakdown.tilt == 70)
    }

    // MARK: - Weighted Total Score Tests

    /// 総合スコアは各項目の加重平均
    @Test func totalScoreIsWeightedAverage() {
        let calculator = FaceScoreCalculator()
        let reference = makeReferencePosture(
            baselineY: 0.5,
            baselineArea: 0.04,
            baselineRoll: 0.0
        )
        calculator.setReferencePosture(reference)

        // すべて100点の場合
        let face = makeFacePosition(
            centerY: 0.5,
            area: 0.04,
            roll: 0.0
        )

        let score = calculator.calculate(from: face)

        // 100 * 0.4 + 100 * 0.4 + 100 * 0.2 = 100
        #expect(score?.value == 100)
    }

    /// 各項目のスコアが異なる場合の加重平均
    @Test func totalScoreWithMixedBreakdown() {
        let calculator = FaceScoreCalculator()
        let reference = makeReferencePosture(
            baselineY: 0.5,
            baselineArea: 0.04,
            baselineRoll: 0.0
        )
        calculator.setReferencePosture(reference)

        // Y座標低下: 0.15逸脱 → 0点
        // 面積: 変化なし → 100点
        // 傾き: 変化なし → 100点
        let face = makeFacePosition(
            centerY: 0.35,
            area: 0.04,
            roll: 0.0
        )

        let score = calculator.calculate(from: face)

        // 0 * 0.4 + 100 * 0.4 + 100 * 0.2 = 60
        #expect(score?.value == 60)
    }

    /// SC-003: 良い姿勢は90点以上
    @Test func goodPostureScoreAbove90() throws {
        let calculator = FaceScoreCalculator()
        let reference = makeReferencePosture(
            baselineY: 0.5,
            baselineArea: 0.04,
            baselineRoll: 0.0
        )
        calculator.setReferencePosture(reference)

        // 基準姿勢を維持
        let face = makeFacePosition(
            centerY: 0.5,
            area: 0.04,
            roll: 0.0
        )

        let score = try #require(calculator.calculate(from: face))

        #expect(score.value >= 90)
    }

    /// SC-003: 30%以上の前傾は60点以下
    @Test func forwardLeanScoreBelow60() throws {
        let calculator = FaceScoreCalculator()
        let reference = makeReferencePosture(
            baselineY: 0.5,
            baselineArea: 0.04,
            baselineRoll: 0.0
        )
        calculator.setReferencePosture(reference)

        // 30%以上の面積増加（前傾）
        let face = makeFacePosition(
            centerY: 0.5,
            area: 0.052, // 0.04 * 1.3 = 0.052
            roll: 0.0
        )

        let score = try #require(calculator.calculate(from: face))

        // サイズ0点 + 他100点 = 0*0.4 + 100*0.4 + 100*0.2 = 60
        #expect(score.value <= 60)
    }

    // MARK: - PostureScore Properties Tests

    /// スコアにはconfidenceが含まれる
    @Test func scoreContainsConfidence() {
        let calculator = FaceScoreCalculator()
        let reference = makeReferencePosture()
        calculator.setReferencePosture(reference)

        let face = makeFacePosition(captureQuality: 0.85)

        let score = calculator.calculate(from: face)

        #expect(score?.confidence == 0.85)
    }

    /// スコアにはtimestampが含まれる
    @Test func scoreContainsTimestamp() {
        let calculator = FaceScoreCalculator()
        let reference = makeReferencePosture()
        calculator.setReferencePosture(reference)

        let now = Date()
        let face = FacePosition(
            centerX: 0.5,
            centerY: 0.5,
            area: 0.04,
            width: 0.2,
            height: 0.2,
            roll: 0.0,
            captureQuality: 0.8,
            timestamp: now
        )

        let score = calculator.calculate(from: face)

        #expect(score?.timestamp == now)
    }

    // MARK: - Edge Cases

    /// baselineAreaが0の場合でもクラッシュしない
    @Test func handleZeroBaselineArea() {
        let calculator = FaceScoreCalculator()
        let reference = FaceReferencePosture(
            calibratedAt: Date(),
            frameCount: 30,
            averageQuality: 0.8,
            baselineMetrics: FaceBaselineMetrics(
                baselineY: 0.5,
                baselineArea: 0.0, // 無効だがクラッシュしないことを確認
                baselineRoll: 0.0
            )
        )
        calculator.setReferencePosture(reference)

        let face = makeFacePosition()

        // クラッシュしないことを確認
        let score = calculator.calculate(from: face)
        #expect(score != nil)
    }
}
