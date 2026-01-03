import Testing
import Foundation
@testable import Flowease

/// FaceBaselineMetricsモデルのテスト
///
/// TDD: T022 - data-model.mdで定義されたNaN/Infiniteサニタイズを検証
@MainActor
struct FaceBaselineMetricsTests {
    // MARK: - Normal Initialization Tests

    /// 正常な値でインスタンス化できることを確認
    @Test func initializationWithValidValues() {
        let metrics = FaceBaselineMetrics(
            baselineY: 0.5,
            baselineArea: 0.1,
            baselineRoll: 0.0
        )

        #expect(metrics.baselineY == 0.5)
        #expect(metrics.baselineArea == 0.1)
        #expect(metrics.baselineRoll == 0.0)
    }

    /// 境界値（0.0, 1.0）でのインスタンス化
    @Test func initializationWithBoundaryValues() {
        let metrics = FaceBaselineMetrics(
            baselineY: 0.0,
            baselineArea: 1.0,
            baselineRoll: -.pi
        )

        #expect(metrics.baselineY == 0.0)
        #expect(metrics.baselineArea == 1.0)
        #expect(metrics.baselineRoll == -.pi)
    }

    // MARK: - NaN Sanitization Tests

    /// baselineYがNaNの場合、0.5にサニタイズされる
    @Test func sanitizesNaNBaselineY() {
        let metrics = FaceBaselineMetrics(
            baselineY: Double.nan,
            baselineArea: 0.1,
            baselineRoll: 0.0
        )

        #expect(metrics.baselineY == 0.5)
    }

    /// baselineAreaがNaNの場合、0.01にサニタイズされる
    @Test func sanitizesNaNBaselineArea() {
        let metrics = FaceBaselineMetrics(
            baselineY: 0.5,
            baselineArea: Double.nan,
            baselineRoll: 0.0
        )

        #expect(metrics.baselineArea == 0.01)
    }

    /// baselineRollがNaNの場合、0.0にサニタイズされる
    @Test func sanitizesNaNBaselineRoll() {
        let metrics = FaceBaselineMetrics(
            baselineY: 0.5,
            baselineArea: 0.1,
            baselineRoll: Double.nan
        )

        #expect(metrics.baselineRoll == 0.0)
    }

    /// すべての値がNaNの場合、すべてデフォルト値にサニタイズされる
    @Test func sanitizesAllNaNValues() {
        let metrics = FaceBaselineMetrics(
            baselineY: Double.nan,
            baselineArea: Double.nan,
            baselineRoll: Double.nan
        )

        #expect(metrics.baselineY == 0.5)
        #expect(metrics.baselineArea == 0.01)
        #expect(metrics.baselineRoll == 0.0)
    }

    // MARK: - Infinite Sanitization Tests

    /// baselineYが正の無限大の場合、0.5にサニタイズされる
    @Test func sanitizesPositiveInfinityBaselineY() {
        let metrics = FaceBaselineMetrics(
            baselineY: Double.infinity,
            baselineArea: 0.1,
            baselineRoll: 0.0
        )

        #expect(metrics.baselineY == 0.5)
    }

    /// baselineYが負の無限大の場合、0.5にサニタイズされる
    @Test func sanitizesNegativeInfinityBaselineY() {
        let metrics = FaceBaselineMetrics(
            baselineY: -Double.infinity,
            baselineArea: 0.1,
            baselineRoll: 0.0
        )

        #expect(metrics.baselineY == 0.5)
    }

    /// baselineAreaが正の無限大の場合、0.01にサニタイズされる
    @Test func sanitizesPositiveInfinityBaselineArea() {
        let metrics = FaceBaselineMetrics(
            baselineY: 0.5,
            baselineArea: Double.infinity,
            baselineRoll: 0.0
        )

        #expect(metrics.baselineArea == 0.01)
    }

    /// baselineAreaが負の無限大の場合、0.01にサニタイズされる
    @Test func sanitizesNegativeInfinityBaselineArea() {
        let metrics = FaceBaselineMetrics(
            baselineY: 0.5,
            baselineArea: -Double.infinity,
            baselineRoll: 0.0
        )

        #expect(metrics.baselineArea == 0.01)
    }

    /// baselineRollが正の無限大の場合、0.0にサニタイズされる
    @Test func sanitizesPositiveInfinityBaselineRoll() {
        let metrics = FaceBaselineMetrics(
            baselineY: 0.5,
            baselineArea: 0.1,
            baselineRoll: Double.infinity
        )

        #expect(metrics.baselineRoll == 0.0)
    }

    /// baselineRollが負の無限大の場合、0.0にサニタイズされる
    @Test func sanitizesNegativeInfinityBaselineRoll() {
        let metrics = FaceBaselineMetrics(
            baselineY: 0.5,
            baselineArea: 0.1,
            baselineRoll: -Double.infinity
        )

        #expect(metrics.baselineRoll == 0.0)
    }

    /// すべての値が無限大の場合、すべてデフォルト値にサニタイズされる
    @Test func sanitizesAllInfiniteValues() {
        let metrics = FaceBaselineMetrics(
            baselineY: Double.infinity,
            baselineArea: -Double.infinity,
            baselineRoll: Double.infinity
        )

        #expect(metrics.baselineY == 0.5)
        #expect(metrics.baselineArea == 0.01)
        #expect(metrics.baselineRoll == 0.0)
    }

    // MARK: - Codable Tests

    /// エンコードとデコードが正しく動作することを確認
    @Test func codableRoundTrip() throws {
        let original = FaceBaselineMetrics(
            baselineY: 0.6,
            baselineArea: 0.15,
            baselineRoll: 0.3
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(FaceBaselineMetrics.self, from: data)

        #expect(original == decoded)
    }

    /// サニタイズ後の値がエンコード/デコードされることを確認
    @Test func codableWithSanitizedValues() throws {
        let original = FaceBaselineMetrics(
            baselineY: Double.nan,
            baselineArea: Double.infinity,
            baselineRoll: -Double.infinity
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(FaceBaselineMetrics.self, from: data)

        // サニタイズ後の値が保持される
        #expect(decoded.baselineY == 0.5)
        #expect(decoded.baselineArea == 0.01)
        #expect(decoded.baselineRoll == 0.0)
    }

    // MARK: - Equatable Tests

    /// 同じ値を持つインスタンスが等しい
    @Test func equalityWithSameValues() {
        let metrics1 = FaceBaselineMetrics(
            baselineY: 0.5,
            baselineArea: 0.1,
            baselineRoll: 0.0
        )
        let metrics2 = FaceBaselineMetrics(
            baselineY: 0.5,
            baselineArea: 0.1,
            baselineRoll: 0.0
        )

        #expect(metrics1 == metrics2)
    }

    /// 異なる値を持つインスタンスが等しくない
    @Test func inequalityWithDifferentValues() {
        let metrics1 = FaceBaselineMetrics(
            baselineY: 0.5,
            baselineArea: 0.1,
            baselineRoll: 0.0
        )
        let metrics2 = FaceBaselineMetrics(
            baselineY: 0.6,
            baselineArea: 0.1,
            baselineRoll: 0.0
        )

        #expect(metrics1 != metrics2)
    }

    /// NaN/Infiniteでサニタイズされた値同士が等しい
    @Test func equalityWithSanitizedValues() {
        let metrics1 = FaceBaselineMetrics(
            baselineY: Double.nan,
            baselineArea: Double.nan,
            baselineRoll: Double.nan
        )
        let metrics2 = FaceBaselineMetrics(
            baselineY: Double.infinity,
            baselineArea: -Double.infinity,
            baselineRoll: Double.nan
        )

        // 両方とも同じデフォルト値にサニタイズされるため等しい
        #expect(metrics1 == metrics2)
    }

    // MARK: - Default Value Constants Tests

    /// サニタイズ時のデフォルト値が仕様通りであることを確認
    @Test func sanitizationDefaultValues() {
        let metricsWithNaN = FaceBaselineMetrics(
            baselineY: Double.nan,
            baselineArea: Double.nan,
            baselineRoll: Double.nan
        )

        // data-model.mdで定義されたデフォルト値
        // baselineY: 0.5 (画面中央)
        // baselineArea: 0.01 (小さめのデフォルト)
        // baselineRoll: 0.0 (傾きなし)
        #expect(metricsWithNaN.baselineY == 0.5)
        #expect(metricsWithNaN.baselineArea == 0.01)
        #expect(metricsWithNaN.baselineRoll == 0.0)
    }
}
