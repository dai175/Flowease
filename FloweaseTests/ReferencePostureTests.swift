//
//  ReferencePostureTests.swift
//  FloweaseTests
//
//  T009: ReferencePostureのCodableテスト
//

import XCTest
@testable import Flowease

@MainActor
final class ReferencePostureTests: XCTestCase {
    // MARK: - Test Helpers

    /// テスト用の有効なReferencePostureを作成
    private func createValidReferencePosture(
        frameCount: Int = 90,
        averageConfidence: Double = 0.85,
        calibratedAt: Date = Date()
    ) -> ReferencePosture {
        ReferencePosture(
            neck: ReferenceJointPosition(x: 0.5, y: 0.7, confidence: 0.9),
            leftShoulder: ReferenceJointPosition(x: 0.3, y: 0.5, confidence: 0.85),
            rightShoulder: ReferenceJointPosition(x: 0.7, y: 0.5, confidence: 0.85),
            nose: ReferenceJointPosition(x: 0.5, y: 0.8, confidence: 0.9),
            leftEar: ReferenceJointPosition(x: 0.35, y: 0.75, confidence: 0.8),
            rightEar: ReferenceJointPosition(x: 0.65, y: 0.75, confidence: 0.8),
            root: ReferenceJointPosition(x: 0.5, y: 0.3, confidence: 0.7),
            calibratedAt: calibratedAt,
            frameCount: frameCount,
            averageConfidence: averageConfidence,
            baselineMetrics: BaselineMetrics(
                headTiltDeviation: 0.01,
                shoulderBalance: 0.02,
                forwardLean: 0.1,
                symmetry: 0.015
            )
        )
    }

    // MARK: - Codable Tests

    func testReferencePostureEncodeDecode() throws {
        // Given
        let originalPosture = createValidReferencePosture()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // When
        let data = try encoder.encode(originalPosture)
        let decodedPosture = try decoder.decode(ReferencePosture.self, from: data)

        // Then
        XCTAssertEqual(decodedPosture.neck.x, originalPosture.neck.x, accuracy: 0.0001)
        XCTAssertEqual(decodedPosture.neck.y, originalPosture.neck.y, accuracy: 0.0001)
        XCTAssertEqual(decodedPosture.leftShoulder.x, originalPosture.leftShoulder.x, accuracy: 0.0001)
        XCTAssertEqual(decodedPosture.rightShoulder.x, originalPosture.rightShoulder.x, accuracy: 0.0001)
        XCTAssertEqual(decodedPosture.frameCount, originalPosture.frameCount)
        XCTAssertEqual(decodedPosture.averageConfidence, originalPosture.averageConfidence, accuracy: 0.0001)
    }

    func testReferencePostureEncodeDecodeWithOptionalFields() throws {
        // Given: 必須フィールドのみ
        let minimalPosture = ReferencePosture(
            neck: ReferenceJointPosition(x: 0.5, y: 0.7, confidence: 0.9),
            leftShoulder: ReferenceJointPosition(x: 0.3, y: 0.5, confidence: 0.85),
            rightShoulder: ReferenceJointPosition(x: 0.7, y: 0.5, confidence: 0.85),
            frameCount: 60,
            averageConfidence: 0.8,
            baselineMetrics: BaselineMetrics(
                headTiltDeviation: 0.0,
                shoulderBalance: 0.0,
                forwardLean: 0.0,
                symmetry: 0.0
            )
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // When
        let data = try encoder.encode(minimalPosture)
        let decodedPosture = try decoder.decode(ReferencePosture.self, from: data)

        // Then
        XCTAssertNil(decodedPosture.nose)
        XCTAssertNil(decodedPosture.leftEar)
        XCTAssertNil(decodedPosture.rightEar)
        XCTAssertNil(decodedPosture.root)
    }

    func testReferencePostureDatePreservation() throws {
        // Given
        let specificDate = Date(timeIntervalSince1970: 1704067200) // 2024-01-01 00:00:00 UTC
        let posture = createValidReferencePosture(calibratedAt: specificDate)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // When
        let data = try encoder.encode(posture)
        let decodedPosture = try decoder.decode(ReferencePosture.self, from: data)

        // Then: 日付が正確に保持されていることを確認
        XCTAssertEqual(
            decodedPosture.calibratedAt.timeIntervalSince1970,
            specificDate.timeIntervalSince1970,
            accuracy: 1.0
        )
    }

    // MARK: - Validation Tests

    func testIsValidWithValidData() {
        // Given: 有効なデータ (frameCount >= 30, confidence >= 0.7)
        let posture = createValidReferencePosture(frameCount: 90, averageConfidence: 0.85)

        // Then
        XCTAssertTrue(posture.isValid)
    }

    func testIsValidWithMinimumFrameCount() {
        // Given: 境界値 (frameCount == 30)
        let posture = createValidReferencePosture(frameCount: 30, averageConfidence: 0.7)

        // Then
        XCTAssertTrue(posture.isValid)
    }

    func testIsValidWithInsufficientFrameCount() {
        // Given: フレーム数不足 (frameCount < 30)
        let posture = createValidReferencePosture(frameCount: 29, averageConfidence: 0.85)

        // Then
        XCTAssertFalse(posture.isValid)
    }

    func testIsValidWithLowConfidence() {
        // Given: 信頼度不足 (confidence < 0.7)
        let posture = createValidReferencePosture(frameCount: 90, averageConfidence: 0.69)

        // Then
        XCTAssertFalse(posture.isValid)
    }

    // MARK: - Input Clamping Tests

    func testFrameCountClampedToZero() {
        // Given: 負のフレーム数
        let posture = createValidReferencePosture(frameCount: -10)

        // Then: 0にクランプされる
        XCTAssertEqual(posture.frameCount, 0)
    }

    func testConfidenceClampedToValidRange() {
        // Given: 範囲外の信頼度
        let postureOver = createValidReferencePosture(averageConfidence: 1.5)
        let postureUnder = createValidReferencePosture(averageConfidence: -0.5)

        // Then: 0.0〜1.0にクランプされる
        XCTAssertEqual(postureOver.averageConfidence, 1.0, accuracy: 0.0001)
        XCTAssertEqual(postureUnder.averageConfidence, 0.0, accuracy: 0.0001)
    }

    func testConfidenceNaNHandling() {
        // Given: NaN値
        let posture = createValidReferencePosture(averageConfidence: Double.nan)

        // Then: 0.0として扱われる
        XCTAssertEqual(posture.averageConfidence, 0.0, accuracy: 0.0001)
    }

    // MARK: - Computed Property Tests

    func testTimeSinceCalibration() {
        // Given: 1時間前のキャリブレーション
        let oneHourAgo = Date().addingTimeInterval(-3600)
        let posture = createValidReferencePosture(calibratedAt: oneHourAgo)

        // Then: 経過時間が約3600秒
        XCTAssertEqual(posture.timeSinceCalibration, 3600, accuracy: 1.0)
    }

    func testFormattedCalibrationDateNotEmpty() {
        // Given
        let posture = createValidReferencePosture()

        // Then: 空でない文字列が返される
        XCTAssertFalse(posture.formattedCalibrationDate.isEmpty)
    }

    // MARK: - Equatable Tests

    func testEquatable() {
        // Given
        let date = Date()
        let posture1 = createValidReferencePosture(calibratedAt: date)
        let posture2 = createValidReferencePosture(calibratedAt: date)

        // Then
        XCTAssertEqual(posture1, posture2)
    }
}
