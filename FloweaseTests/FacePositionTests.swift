import Testing
import Foundation
@testable import Flowease

/// FacePositionモデルのテスト
///
/// TDD: T008 - data-model.mdで定義されたバリデーションルールを検証
@MainActor
struct FacePositionTests {
    // MARK: - Validation Tests

    /// centerX/centerYが範囲内（0-1）であることを検証
    @Test func validCoordinates() {
        let position = FacePosition(
            centerX: 0.5,
            centerY: 0.5,
            area: 0.1,
            width: 0.25,
            height: 0.4,
            roll: 0.0,
            captureQuality: 0.5,
            timestamp: Date()
        )

        #expect(position.isValid)
    }

    /// centerXが範囲外（< 0）の場合は無効
    @Test func invalidCenterXBelowZero() {
        let position = FacePosition(
            centerX: -0.1,
            centerY: 0.5,
            area: 0.1,
            width: 0.25,
            height: 0.4,
            roll: 0.0,
            captureQuality: 0.5,
            timestamp: Date()
        )

        #expect(!position.isValid)
    }

    /// centerXが範囲外（> 1）の場合は無効
    @Test func invalidCenterXAboveOne() {
        let position = FacePosition(
            centerX: 1.1,
            centerY: 0.5,
            area: 0.1,
            width: 0.25,
            height: 0.4,
            roll: 0.0,
            captureQuality: 0.5,
            timestamp: Date()
        )

        #expect(!position.isValid)
    }

    /// centerYが範囲外（< 0）の場合は無効
    @Test func invalidCenterYBelowZero() {
        let position = FacePosition(
            centerX: 0.5,
            centerY: -0.1,
            area: 0.1,
            width: 0.25,
            height: 0.4,
            roll: 0.0,
            captureQuality: 0.5,
            timestamp: Date()
        )

        #expect(!position.isValid)
    }

    /// centerYが範囲外（> 1）の場合は無効
    @Test func invalidCenterYAboveOne() {
        let position = FacePosition(
            centerX: 0.5,
            centerY: 1.1,
            area: 0.1,
            width: 0.25,
            height: 0.4,
            roll: 0.0,
            captureQuality: 0.5,
            timestamp: Date()
        )

        #expect(!position.isValid)
    }

    /// areaが範囲外（<= 0）の場合は無効
    @Test func invalidAreaZero() {
        let position = FacePosition(
            centerX: 0.5,
            centerY: 0.5,
            area: 0.0,
            width: 0.0,
            height: 0.0,
            roll: 0.0,
            captureQuality: 0.5,
            timestamp: Date()
        )

        #expect(!position.isValid)
    }

    /// areaが範囲外（負の値）の場合は無効
    @Test func invalidAreaNegative() {
        let position = FacePosition(
            centerX: 0.5,
            centerY: 0.5,
            area: -0.1,
            width: 0.0,
            height: 0.0,
            roll: 0.0,
            captureQuality: 0.5,
            timestamp: Date()
        )

        #expect(!position.isValid)
    }

    /// areaが範囲外（> 1）の場合は無効
    @Test func invalidAreaAboveOne() {
        let position = FacePosition(
            centerX: 0.5,
            centerY: 0.5,
            area: 1.1,
            width: 1.1,
            height: 1.0,
            roll: 0.0,
            captureQuality: 0.5,
            timestamp: Date()
        )

        #expect(!position.isValid)
    }

    /// rollが範囲外（< -π）の場合は無効
    @Test func invalidRollBelowMinusPi() {
        let position = FacePosition(
            centerX: 0.5,
            centerY: 0.5,
            area: 0.1,
            width: 0.25,
            height: 0.4,
            roll: -.pi - 0.1,
            captureQuality: 0.5,
            timestamp: Date()
        )

        #expect(!position.isValid)
    }

    /// rollが範囲外（>= π）の場合は無効
    @Test func invalidRollAboveOrEqualPi() {
        let position = FacePosition(
            centerX: 0.5,
            centerY: 0.5,
            area: 0.1,
            width: 0.25,
            height: 0.4,
            roll: .pi,
            captureQuality: 0.5,
            timestamp: Date()
        )

        #expect(!position.isValid)
    }

    /// rollがnilの場合は有効（roll未取得）
    @Test func validWithNilRoll() {
        let position = FacePosition(
            centerX: 0.5,
            centerY: 0.5,
            area: 0.1,
            width: 0.25,
            height: 0.4,
            roll: nil,
            captureQuality: 0.5,
            timestamp: Date()
        )

        #expect(position.isValid)
    }

    /// captureQualityが範囲外（< 0）の場合は無効
    @Test func invalidCaptureQualityNegative() {
        let position = FacePosition(
            centerX: 0.5,
            centerY: 0.5,
            area: 0.1,
            width: 0.25,
            height: 0.4,
            roll: 0.0,
            captureQuality: -0.1,
            timestamp: Date()
        )

        #expect(!position.isValid)
    }

    /// captureQualityが範囲外（> 1）の場合は無効
    @Test func invalidCaptureQualityAboveOne() {
        let position = FacePosition(
            centerX: 0.5,
            centerY: 0.5,
            area: 0.1,
            width: 0.25,
            height: 0.4,
            roll: 0.0,
            captureQuality: 1.1,
            timestamp: Date()
        )

        #expect(!position.isValid)
    }

    // MARK: - Boundary Tests

    /// 座標の境界値（0.0）が有効
    @Test func validCoordinatesAtLowerBound() {
        let position = FacePosition(
            centerX: 0.0,
            centerY: 0.0,
            area: 0.001,
            width: 0.01,
            height: 0.1,
            roll: -.pi,
            captureQuality: 0.0,
            timestamp: Date()
        )

        #expect(position.isValid)
    }

    /// 座標の境界値（1.0）が有効
    @Test func validCoordinatesAtUpperBound() {
        let position = FacePosition(
            centerX: 1.0,
            centerY: 1.0,
            area: 1.0,
            width: 1.0,
            height: 1.0,
            roll: .pi - 0.0001,
            captureQuality: 1.0,
            timestamp: Date()
        )

        #expect(position.isValid)
    }

    /// rollが-π（下限）で有効
    @Test func validRollAtLowerBound() {
        let position = FacePosition(
            centerX: 0.5,
            centerY: 0.5,
            area: 0.1,
            width: 0.25,
            height: 0.4,
            roll: -.pi,
            captureQuality: 0.5,
            timestamp: Date()
        )

        #expect(position.isValid)
    }

    /// rollがπ未満の最大値で有効
    @Test func validRollJustBelowPi() {
        let position = FacePosition(
            centerX: 0.5,
            centerY: 0.5,
            area: 0.1,
            width: 0.25,
            height: 0.4,
            roll: .pi - 0.0001,
            captureQuality: 0.5,
            timestamp: Date()
        )

        #expect(position.isValid)
    }

    // MARK: - hasAcceptableQuality Tests

    /// captureQuality >= 0.3 で hasAcceptableQuality が true
    @Test func hasAcceptableQualityWhenAboveThreshold() {
        let position = FacePosition(
            centerX: 0.5,
            centerY: 0.5,
            area: 0.1,
            width: 0.25,
            height: 0.4,
            roll: 0.0,
            captureQuality: 0.3,
            timestamp: Date()
        )

        #expect(position.hasAcceptableQuality)
    }

    /// captureQuality < 0.3 で hasAcceptableQuality が false
    @Test func hasUnacceptableQualityWhenBelowThreshold() {
        let position = FacePosition(
            centerX: 0.5,
            centerY: 0.5,
            area: 0.1,
            width: 0.25,
            height: 0.4,
            roll: 0.0,
            captureQuality: 0.29,
            timestamp: Date()
        )

        #expect(!position.hasAcceptableQuality)
    }

    // MARK: - minimumCaptureQuality Tests

    /// minimumCaptureQualityが0.3であることを確認
    @Test func minimumCaptureQualityValue() {
        #expect(FacePosition.minimumCaptureQuality == 0.3)
    }

    // MARK: - Equatable Tests

    /// 同じ値を持つFacePositionが等しい
    @Test func equalityWithSameValues() {
        let date = Date()
        let position1 = FacePosition(
            centerX: 0.5,
            centerY: 0.5,
            area: 0.1,
            width: 0.25,
            height: 0.4,
            roll: 0.0,
            captureQuality: 0.5,
            timestamp: date
        )
        let position2 = FacePosition(
            centerX: 0.5,
            centerY: 0.5,
            area: 0.1,
            width: 0.25,
            height: 0.4,
            roll: 0.0,
            captureQuality: 0.5,
            timestamp: date
        )

        #expect(position1 == position2)
    }

    /// 異なる値を持つFacePositionが等しくない
    @Test func inequalityWithDifferentValues() {
        let date = Date()
        let position1 = FacePosition(
            centerX: 0.5,
            centerY: 0.5,
            area: 0.1,
            width: 0.25,
            height: 0.4,
            roll: 0.0,
            captureQuality: 0.5,
            timestamp: date
        )
        let position2 = FacePosition(
            centerX: 0.6,
            centerY: 0.5,
            area: 0.1,
            width: 0.25,
            height: 0.4,
            roll: 0.0,
            captureQuality: 0.5,
            timestamp: date
        )

        #expect(position1 != position2)
    }
}
