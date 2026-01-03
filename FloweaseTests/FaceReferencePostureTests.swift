import Testing
import Foundation
@testable import Flowease

/// FaceReferencePostureモデルのテスト
///
/// TDD: T023 - data-model.mdで定義されたisValid検証、Codable、Equatableを検証
@MainActor
struct FaceReferencePostureTests {
    // MARK: - Helper

    /// テスト用の有効なFaceBaselineMetricsを生成
    private func makeValidMetrics() -> FaceBaselineMetrics {
        FaceBaselineMetrics(
            baselineY: 0.5,
            baselineArea: 0.1,
            baselineRoll: 0.0
        )
    }

    // MARK: - Normal Initialization Tests

    /// 正常な値でインスタンス化できることを確認
    @Test func initializationWithValidValues() {
        let posture = FaceReferencePosture(
            calibratedAt: Date(),
            frameCount: 30,
            averageQuality: 0.8,
            baselineMetrics: makeValidMetrics()
        )

        #expect(posture.frameCount == 30)
        #expect(posture.averageQuality == 0.8)
        #expect(posture.baselineMetrics == makeValidMetrics())
    }

    /// 最低必要フレーム数の定数が仕様通りであることを確認
    @Test func minimumFrameCountConstant() {
        // data-model.md: minimumFrameCount = 15 (約1秒分、15FPS処理前提)
        #expect(FaceReferencePosture.minimumFrameCount == 15)
    }

    /// 最低必要検出品質の定数が仕様通りであることを確認
    @Test func minimumQualityConstant() {
        // data-model.md: minimumQuality = 0.3
        #expect(FaceReferencePosture.minimumQuality == 0.3)
    }

    // MARK: - isValid Tests

    /// フレーム数と品質が両方とも十分な場合、isValidはtrue
    @Test func isValidWithSufficientFrameCountAndQuality() {
        let posture = FaceReferencePosture(
            calibratedAt: Date(),
            frameCount: 15,
            averageQuality: 0.3,
            baselineMetrics: makeValidMetrics()
        )

        #expect(posture.isValid == true)
    }

    /// フレーム数が最低値を超え、品質も十分な場合、isValidはtrue
    @Test func isValidWithExcessFrameCountAndQuality() {
        let posture = FaceReferencePosture(
            calibratedAt: Date(),
            frameCount: 100,
            averageQuality: 0.9,
            baselineMetrics: makeValidMetrics()
        )

        #expect(posture.isValid == true)
    }

    /// フレーム数が不足している場合、isValidはfalse
    @Test func isInvalidWithInsufficientFrameCount() {
        let posture = FaceReferencePosture(
            calibratedAt: Date(),
            frameCount: 14, // minimumFrameCount - 1
            averageQuality: 0.8,
            baselineMetrics: makeValidMetrics()
        )

        #expect(posture.isValid == false)
    }

    /// フレーム数が0の場合、isValidはfalse
    @Test func isInvalidWithZeroFrameCount() {
        let posture = FaceReferencePosture(
            calibratedAt: Date(),
            frameCount: 0,
            averageQuality: 0.8,
            baselineMetrics: makeValidMetrics()
        )

        #expect(posture.isValid == false)
    }

    /// 品質が不足している場合、isValidはfalse
    @Test func isInvalidWithInsufficientQuality() {
        let posture = FaceReferencePosture(
            calibratedAt: Date(),
            frameCount: 30,
            averageQuality: 0.29, // minimumQuality - 0.01
            baselineMetrics: makeValidMetrics()
        )

        #expect(posture.isValid == false)
    }

    /// 品質が0の場合、isValidはfalse
    @Test func isInvalidWithZeroQuality() {
        let posture = FaceReferencePosture(
            calibratedAt: Date(),
            frameCount: 30,
            averageQuality: 0.0,
            baselineMetrics: makeValidMetrics()
        )

        #expect(posture.isValid == false)
    }

    /// フレーム数と品質の両方が不足している場合、isValidはfalse
    @Test func isInvalidWithBothInsufficientFrameCountAndQuality() {
        let posture = FaceReferencePosture(
            calibratedAt: Date(),
            frameCount: 10,
            averageQuality: 0.2,
            baselineMetrics: makeValidMetrics()
        )

        #expect(posture.isValid == false)
    }

    /// 境界値テスト: フレーム数がちょうど最低値の場合、isValidはtrue
    @Test func isValidAtExactMinimumFrameCount() {
        let posture = FaceReferencePosture(
            calibratedAt: Date(),
            frameCount: FaceReferencePosture.minimumFrameCount,
            averageQuality: 0.5,
            baselineMetrics: makeValidMetrics()
        )

        #expect(posture.isValid == true)
    }

    /// 境界値テスト: 品質がちょうど最低値の場合、isValidはtrue
    @Test func isValidAtExactMinimumQuality() {
        let posture = FaceReferencePosture(
            calibratedAt: Date(),
            frameCount: 30,
            averageQuality: FaceReferencePosture.minimumQuality,
            baselineMetrics: makeValidMetrics()
        )

        #expect(posture.isValid == true)
    }

    // MARK: - Codable Tests

    /// エンコードとデコードが正しく動作することを確認
    @Test func codableRoundTrip() throws {
        let calibrationDate = Date()
        let original = FaceReferencePosture(
            calibratedAt: calibrationDate,
            frameCount: 30,
            averageQuality: 0.85,
            baselineMetrics: FaceBaselineMetrics(
                baselineY: 0.55,
                baselineArea: 0.12,
                baselineRoll: 0.1
            )
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(FaceReferencePosture.self, from: data)

        #expect(original == decoded)
    }

    /// 最小値でのエンコード/デコードが動作することを確認
    @Test func codableWithMinimumValidValues() throws {
        let original = FaceReferencePosture(
            calibratedAt: Date(),
            frameCount: 15,
            averageQuality: 0.3,
            baselineMetrics: makeValidMetrics()
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(FaceReferencePosture.self, from: data)

        #expect(decoded.isValid == true)
        #expect(decoded.frameCount == 15)
        #expect(decoded.averageQuality == 0.3)
    }

    // MARK: - Equatable Tests

    /// 同じ値を持つインスタンスが等しい
    @Test func equalityWithSameValues() {
        let date = Date()
        let metrics = makeValidMetrics()

        let posture1 = FaceReferencePosture(
            calibratedAt: date,
            frameCount: 30,
            averageQuality: 0.8,
            baselineMetrics: metrics
        )
        let posture2 = FaceReferencePosture(
            calibratedAt: date,
            frameCount: 30,
            averageQuality: 0.8,
            baselineMetrics: metrics
        )

        #expect(posture1 == posture2)
    }

    /// フレーム数が異なる場合、等しくない
    @Test func inequalityWithDifferentFrameCount() {
        let date = Date()
        let metrics = makeValidMetrics()

        let posture1 = FaceReferencePosture(
            calibratedAt: date,
            frameCount: 30,
            averageQuality: 0.8,
            baselineMetrics: metrics
        )
        let posture2 = FaceReferencePosture(
            calibratedAt: date,
            frameCount: 31,
            averageQuality: 0.8,
            baselineMetrics: metrics
        )

        #expect(posture1 != posture2)
    }

    /// 品質が異なる場合、等しくない
    @Test func inequalityWithDifferentAverageQuality() {
        let date = Date()
        let metrics = makeValidMetrics()

        let posture1 = FaceReferencePosture(
            calibratedAt: date,
            frameCount: 30,
            averageQuality: 0.8,
            baselineMetrics: metrics
        )
        let posture2 = FaceReferencePosture(
            calibratedAt: date,
            frameCount: 30,
            averageQuality: 0.81,
            baselineMetrics: metrics
        )

        #expect(posture1 != posture2)
    }

    /// baselineMetricsが異なる場合、等しくない
    @Test func inequalityWithDifferentBaselineMetrics() {
        let date = Date()

        let posture1 = FaceReferencePosture(
            calibratedAt: date,
            frameCount: 30,
            averageQuality: 0.8,
            baselineMetrics: FaceBaselineMetrics(
                baselineY: 0.5,
                baselineArea: 0.1,
                baselineRoll: 0.0
            )
        )
        let posture2 = FaceReferencePosture(
            calibratedAt: date,
            frameCount: 30,
            averageQuality: 0.8,
            baselineMetrics: FaceBaselineMetrics(
                baselineY: 0.6,
                baselineArea: 0.1,
                baselineRoll: 0.0
            )
        )

        #expect(posture1 != posture2)
    }

    /// キャリブレーション日時が異なる場合、等しくない
    @Test func inequalityWithDifferentCalibratedAt() {
        let metrics = makeValidMetrics()

        let posture1 = FaceReferencePosture(
            calibratedAt: Date(timeIntervalSince1970: 1000),
            frameCount: 30,
            averageQuality: 0.8,
            baselineMetrics: metrics
        )
        let posture2 = FaceReferencePosture(
            calibratedAt: Date(timeIntervalSince1970: 2000),
            frameCount: 30,
            averageQuality: 0.8,
            baselineMetrics: metrics
        )

        #expect(posture1 != posture2)
    }

    // MARK: - Value Normalization Tests

    /// 負のフレーム数は0に正規化される
    @Test func negativeFrameCountNormalizedToZero() {
        let posture = FaceReferencePosture(
            calibratedAt: Date(),
            frameCount: -5,
            averageQuality: 0.8,
            baselineMetrics: makeValidMetrics()
        )

        // max(0, -5) = 0
        #expect(posture.frameCount == 0)
        // 0 < minimumFrameCount なので isValid は false
        #expect(posture.isValid == false)
    }

    /// 品質が1.0を超える値は1.0にクランプされる
    @Test func qualityAboveOneClampedToOne() {
        let posture = FaceReferencePosture(
            calibratedAt: Date(),
            frameCount: 30,
            averageQuality: 1.5,
            baselineMetrics: makeValidMetrics()
        )

        // min(max(1.5, 0.0), 1.0) = 1.0
        #expect(posture.averageQuality == 1.0)
        #expect(posture.isValid == true)
    }

    /// 負の品質値は0.0にクランプされる
    @Test func negativeQualityClampedToZero() {
        let posture = FaceReferencePosture(
            calibratedAt: Date(),
            frameCount: 30,
            averageQuality: -0.5,
            baselineMetrics: makeValidMetrics()
        )

        // min(max(-0.5, 0.0), 1.0) = 0.0
        #expect(posture.averageQuality == 0.0)
        // 0.0 < 0.3 なので isValid は false
        #expect(posture.isValid == false)
    }

    /// 品質が正確に0.0の場合
    @Test func qualityExactlyZero() {
        let posture = FaceReferencePosture(
            calibratedAt: Date(),
            frameCount: 30,
            averageQuality: 0.0,
            baselineMetrics: makeValidMetrics()
        )

        #expect(posture.averageQuality == 0.0)
        #expect(posture.isValid == false)
    }

    /// 品質が正確に1.0の場合
    @Test func qualityExactlyOne() {
        let posture = FaceReferencePosture(
            calibratedAt: Date(),
            frameCount: 30,
            averageQuality: 1.0,
            baselineMetrics: makeValidMetrics()
        )

        #expect(posture.averageQuality == 1.0)
        #expect(posture.isValid == true)
    }

    /// フレーム数が0の場合（最小の正規化結果）
    @Test func frameCountExactlyZero() {
        let posture = FaceReferencePosture(
            calibratedAt: Date(),
            frameCount: 0,
            averageQuality: 0.8,
            baselineMetrics: makeValidMetrics()
        )

        #expect(posture.frameCount == 0)
        #expect(posture.isValid == false)
    }

    /// 大きな負のフレーム数も0に正規化される
    @Test func largeNegativeFrameCountNormalizedToZero() {
        let posture = FaceReferencePosture(
            calibratedAt: Date(),
            frameCount: -1000,
            averageQuality: 0.8,
            baselineMetrics: makeValidMetrics()
        )

        #expect(posture.frameCount == 0)
    }

    /// 非常に大きな品質値も1.0にクランプされる
    @Test func veryLargeQualityClampedToOne() {
        let posture = FaceReferencePosture(
            calibratedAt: Date(),
            frameCount: 30,
            averageQuality: 100.0,
            baselineMetrics: makeValidMetrics()
        )

        #expect(posture.averageQuality == 1.0)
    }
}
