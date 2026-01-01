//
//  CalibrationStorageTests.swift
//  FloweaseTests
//
//  T010: CalibrationStorageのテスト
//

import XCTest
@testable import Flowease

@MainActor
final class CalibrationStorageTests: XCTestCase {
    // MARK: - Properties

    private static let testSuiteName = "CalibrationStorageTests"

    // MARK: - Setup / Teardown

    override func tearDown() {
        // 各テスト後にクリーンアップ
        let defaults = UserDefaults(suiteName: Self.testSuiteName)
        defaults?.removePersistentDomain(forName: Self.testSuiteName)
        super.tearDown()
    }

    // MARK: - Test Helpers

    /// テスト用のストレージを作成
    private func makeStorage() -> CalibrationStorage {
        let defaults = UserDefaults(suiteName: Self.testSuiteName)!
        defaults.removePersistentDomain(forName: Self.testSuiteName)
        return CalibrationStorage(userDefaults: defaults)
    }

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

    // MARK: - Load Tests

    func testLoadReferencePostureReturnsNilWhenEmpty() {
        // Given
        let storage = makeStorage()

        // When
        let result = storage.loadReferencePosture()

        // Then
        XCTAssertNil(result)
    }

    func testLoadReferencePostureReturnsStoredData() {
        // Given
        let storage = makeStorage()
        let originalPosture = createValidReferencePosture()
        storage.saveReferencePosture(originalPosture)

        // When
        let loadedPosture = storage.loadReferencePosture()

        // Then
        guard let loadedPosture else {
            XCTFail("loadedPosture should not be nil")
            return
        }
        XCTAssertEqual(loadedPosture.frameCount, originalPosture.frameCount)
        XCTAssertEqual(loadedPosture.averageConfidence, originalPosture.averageConfidence, accuracy: 0.0001)
    }

    // MARK: - Save Tests

    func testSaveReferencePostureReturnsTrue() {
        // Given
        let storage = makeStorage()
        let posture = createValidReferencePosture()

        // When
        let result = storage.saveReferencePosture(posture)

        // Then
        XCTAssertTrue(result)
    }

    func testSaveReferencePostureOverwritesPrevious() {
        // Given
        let storage = makeStorage()
        let posture1 = createValidReferencePosture(frameCount: 60)
        let posture2 = createValidReferencePosture(frameCount: 90)
        storage.saveReferencePosture(posture1)

        // When
        storage.saveReferencePosture(posture2)
        let loadedPosture = storage.loadReferencePosture()

        // Then
        XCTAssertEqual(loadedPosture?.frameCount, 90)
    }

    // MARK: - Delete Tests

    func testDeleteReferencePostureRemovesData() {
        // Given
        let storage = makeStorage()
        let posture = createValidReferencePosture()
        storage.saveReferencePosture(posture)

        // When
        storage.deleteReferencePosture()
        let loadedPosture = storage.loadReferencePosture()

        // Then
        XCTAssertNil(loadedPosture)
    }

    func testDeleteReferencePostureWhenEmptyDoesNotCrash() {
        // Given
        let storage = makeStorage()

        // When / Then
        storage.deleteReferencePosture()
        XCTAssertNil(storage.loadReferencePosture())
    }

    // MARK: - isCalibrated Tests

    func testIsCalibratedReturnsFalseWhenEmpty() {
        // Given
        let storage = makeStorage()

        // Then
        XCTAssertFalse(storage.isCalibrated)
    }

    func testIsCalibratedReturnsTrueWhenDataExists() {
        // Given
        let storage = makeStorage()
        let posture = createValidReferencePosture()
        storage.saveReferencePosture(posture)

        // Then
        XCTAssertTrue(storage.isCalibrated)
    }

    func testIsCalibratedReturnsFalseAfterDelete() {
        // Given
        let storage = makeStorage()
        let posture = createValidReferencePosture()
        storage.saveReferencePosture(posture)

        // When
        storage.deleteReferencePosture()

        // Then
        XCTAssertFalse(storage.isCalibrated)
    }

    // MARK: - lastCalibratedAt Tests

    func testLastCalibratedAtReturnsNilWhenEmpty() {
        // Given
        let storage = makeStorage()

        // Then
        XCTAssertNil(storage.lastCalibratedAt)
    }

    func testLastCalibratedAtReturnsCorrectDate() {
        // Given
        let storage = makeStorage()
        let specificDate = Date(timeIntervalSince1970: 1_704_067_200) // 2024-01-01 00:00:00 UTC
        let posture = createValidReferencePosture(calibratedAt: specificDate)
        storage.saveReferencePosture(posture)

        // When
        let lastCalibrated = storage.lastCalibratedAt

        // Then
        XCTAssertNotNil(lastCalibrated)
        XCTAssertEqual(
            lastCalibrated!.timeIntervalSince1970,
            specificDate.timeIntervalSince1970,
            accuracy: 1.0
        )
    }

    // MARK: - Data Integrity Tests

    func testDataIntegrityAfterSaveAndLoad() {
        // Given
        let storage = makeStorage()
        let originalPosture = createValidReferencePosture()

        // When
        storage.saveReferencePosture(originalPosture)
        let loadedPosture = storage.loadReferencePosture()

        // Then
        guard let loadedPosture else {
            XCTFail("loadedPosture should not be nil")
            return
        }
        XCTAssertEqual(loadedPosture.neck.x, originalPosture.neck.x, accuracy: 0.0001)
        XCTAssertEqual(loadedPosture.neck.y, originalPosture.neck.y, accuracy: 0.0001)
        XCTAssertEqual(loadedPosture.leftShoulder.x, originalPosture.leftShoulder.x, accuracy: 0.0001)
        XCTAssertEqual(loadedPosture.rightShoulder.x, originalPosture.rightShoulder.x, accuracy: 0.0001)
        if let loadedNose = loadedPosture.nose, let originalNose = originalPosture.nose {
            XCTAssertEqual(loadedNose.x, originalNose.x, accuracy: 0.0001)
            XCTAssertEqual(loadedNose.y, originalNose.y, accuracy: 0.0001)
        } else {
            XCTAssertNil(loadedPosture.nose)
            XCTAssertNil(originalPosture.nose)
        }
        XCTAssertEqual(loadedPosture.frameCount, originalPosture.frameCount)
        XCTAssertEqual(loadedPosture.averageConfidence, originalPosture.averageConfidence, accuracy: 0.0001)
        XCTAssertEqual(
            loadedPosture.baselineMetrics.headTiltDeviation,
            originalPosture.baselineMetrics.headTiltDeviation,
            accuracy: 0.0001
        )
    }

    // MARK: - Corrupted Data Tests

    func testLoadReturnsNilForCorruptedData() {
        // Given
        let defaults = UserDefaults(suiteName: Self.testSuiteName)!
        defaults.removePersistentDomain(forName: Self.testSuiteName)
        defaults.set(Data([0x00, 0x01, 0x02]), forKey: CalibrationStorageKeys.referencePosture)
        let storage = CalibrationStorage(userDefaults: defaults)

        // When
        let result = storage.loadReferencePosture()

        // Then
        XCTAssertNil(result)
    }
}
