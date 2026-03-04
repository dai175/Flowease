//
//  CalibrationStorageTests.swift
//  FloweaseTests
//
//  CalibrationStorageのテスト（顔ベースキャリブレーション専用）
//

import XCTest
@testable import Flowease

@MainActor
final class CalibrationStorageTests: XCTestCase {
    // MARK: - Properties

    private static let testSuiteName = "CalibrationStorageTests"

    // MARK: - Setup / Teardown

    override func tearDown() async throws {
        // 各テスト後にクリーンアップ
        let defaults = UserDefaults(suiteName: Self.testSuiteName)
        defaults?.removePersistentDomain(forName: Self.testSuiteName)
        try await super.tearDown()
    }

    // MARK: - Test Helpers

    /// テスト用のストレージを作成
    private func makeStorage() throws -> CalibrationStorage {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: Self.testSuiteName))
        defaults.removePersistentDomain(forName: Self.testSuiteName)
        return CalibrationStorage(userDefaults: defaults)
    }

    /// テスト用の有効なFaceReferencePostureを作成
    private func createValidFaceReferencePosture(
        frameCount: Int = 30,
        averageQuality: Double = 0.8,
        calibratedAt: Date = Date()
    ) -> FaceReferencePosture {
        let baselineMetrics = FaceBaselineMetrics(
            baselineY: 0.6,
            baselineArea: 0.05,
            baselineRoll: 0.0
        )
        return FaceReferencePosture(
            calibratedAt: calibratedAt,
            frameCount: frameCount,
            averageQuality: averageQuality,
            baselineMetrics: baselineMetrics
        )
    }

    // MARK: - Load Tests

    func testLoadFaceReferencePostureReturnsNilWhenEmpty() throws {
        // Given
        let storage = try makeStorage()

        // When
        let result = storage.loadFaceReferencePosture()

        // Then
        XCTAssertNil(result)
    }

    func testLoadFaceReferencePostureReturnsStoredData() throws {
        // Given
        let storage = try makeStorage()
        let originalPosture = createValidFaceReferencePosture()
        storage.saveFaceReferencePosture(originalPosture)

        // When
        let loadedPosture = storage.loadFaceReferencePosture()

        // Then
        guard let loadedPosture else {
            XCTFail("loadedPosture should not be nil")
            return
        }
        XCTAssertEqual(loadedPosture.frameCount, originalPosture.frameCount)
        XCTAssertEqual(loadedPosture.averageQuality, originalPosture.averageQuality, accuracy: 0.0001)
        XCTAssertEqual(loadedPosture.baselineMetrics.baselineY, 0.6, accuracy: 0.0001)
        XCTAssertEqual(loadedPosture.baselineMetrics.baselineArea, 0.05, accuracy: 0.0001)
        XCTAssertEqual(loadedPosture.baselineMetrics.baselineRoll, 0.0, accuracy: 0.0001)
    }

    // MARK: - Save Tests

    func testSaveFaceReferencePostureReturnsTrue() throws {
        // Given
        let storage = try makeStorage()
        let posture = createValidFaceReferencePosture()

        // When
        let result = storage.saveFaceReferencePosture(posture)

        // Then
        XCTAssertTrue(result)
    }

    func testSaveFaceReferencePostureOverwritesPrevious() throws {
        // Given
        let storage = try makeStorage()
        let posture1 = createValidFaceReferencePosture(frameCount: 20)
        let posture2 = createValidFaceReferencePosture(frameCount: 40)
        storage.saveFaceReferencePosture(posture1)

        // When
        storage.saveFaceReferencePosture(posture2)
        let loadedPosture = storage.loadFaceReferencePosture()

        // Then
        XCTAssertEqual(loadedPosture?.frameCount, 40)
    }

    // MARK: - Delete Tests

    func testDeleteFaceReferencePostureRemovesData() throws {
        // Given
        let storage = try makeStorage()
        let posture = createValidFaceReferencePosture()
        storage.saveFaceReferencePosture(posture)

        // When
        storage.deleteFaceReferencePosture()
        let loadedPosture = storage.loadFaceReferencePosture()

        // Then
        XCTAssertNil(loadedPosture)
    }

    func testDeleteFaceReferencePostureWhenEmptyDoesNotCrash() throws {
        // Given
        let storage = try makeStorage()

        // When / Then
        storage.deleteFaceReferencePosture()
        XCTAssertNil(storage.loadFaceReferencePosture())
    }

    // MARK: - isCalibrated Tests

    func testIsCalibratedReturnsFalseWhenEmpty() throws {
        // Given
        let storage = try makeStorage()

        // Then
        XCTAssertFalse(storage.isCalibrated)
    }

    func testIsCalibratedReturnsTrueWhenDataExists() throws {
        // Given
        let storage = try makeStorage()
        let posture = createValidFaceReferencePosture()
        storage.saveFaceReferencePosture(posture)

        // Then
        XCTAssertTrue(storage.isCalibrated)
    }

    func testIsCalibratedReturnsFalseAfterDelete() throws {
        // Given
        let storage = try makeStorage()
        let posture = createValidFaceReferencePosture()
        storage.saveFaceReferencePosture(posture)

        // When
        storage.deleteFaceReferencePosture()

        // Then
        XCTAssertFalse(storage.isCalibrated)
    }

    // MARK: - lastCalibratedAt Tests

    func testLastCalibratedAtReturnsNilWhenEmpty() throws {
        // Given
        let storage = try makeStorage()

        // Then
        XCTAssertNil(storage.lastCalibratedAt)
    }

    func testLastCalibratedAtReturnsCorrectDate() throws {
        // Given
        let storage = try makeStorage()
        let specificDate = Date(timeIntervalSince1970: 1_704_067_200) // 2024-01-01 00:00:00 UTC
        let posture = createValidFaceReferencePosture(calibratedAt: specificDate)
        storage.saveFaceReferencePosture(posture)

        // When
        let lastCalibrated = storage.lastCalibratedAt

        // Then
        let lastCalibratedUnwrapped = try XCTUnwrap(lastCalibrated)
        XCTAssertEqual(
            lastCalibratedUnwrapped.timeIntervalSince1970,
            specificDate.timeIntervalSince1970,
            accuracy: 1.0
        )
    }

    // MARK: - Data Integrity Tests

    func testDataIntegrityForFaceReferencePosture() throws {
        // Given
        let storage = try makeStorage()
        let baselineMetrics = FaceBaselineMetrics(
            baselineY: 0.55,
            baselineArea: 0.08,
            baselineRoll: 0.1
        )
        let originalPosture = FaceReferencePosture(
            calibratedAt: Date(),
            frameCount: 25,
            averageQuality: 0.75,
            baselineMetrics: baselineMetrics
        )

        // When
        storage.saveFaceReferencePosture(originalPosture)
        let loadedPosture = storage.loadFaceReferencePosture()

        // Then
        guard let loadedPosture else {
            XCTFail("loadedPosture should not be nil")
            return
        }
        XCTAssertEqual(loadedPosture.frameCount, originalPosture.frameCount)
        XCTAssertEqual(loadedPosture.averageQuality, originalPosture.averageQuality, accuracy: 0.0001)
        XCTAssertEqual(
            loadedPosture.baselineMetrics.baselineY,
            originalPosture.baselineMetrics.baselineY,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            loadedPosture.baselineMetrics.baselineArea,
            originalPosture.baselineMetrics.baselineArea,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            loadedPosture.baselineMetrics.baselineRoll,
            originalPosture.baselineMetrics.baselineRoll,
            accuracy: 0.0001
        )
    }

    // MARK: - Corrupted Data Tests

    func testLoadFaceReferencePostureReturnsNilForCorruptedData() throws {
        // Given
        let defaults = try XCTUnwrap(UserDefaults(suiteName: Self.testSuiteName))
        defaults.removePersistentDomain(forName: Self.testSuiteName)
        defaults.set(Data([0x00, 0x01, 0x02]), forKey: CalibrationStorageKeys.referencePosture)
        let storage = CalibrationStorage(userDefaults: defaults)

        // When
        let result = storage.loadFaceReferencePosture()

        // Then
        XCTAssertNil(result)
    }

    func testLoadFaceReferencePostureWithAutoCleanClearsCorruptedData() throws {
        // Given: 破損データが保存されている
        let defaults = try XCTUnwrap(UserDefaults(suiteName: Self.testSuiteName))
        defaults.removePersistentDomain(forName: Self.testSuiteName)
        defaults.set(Data([0x00, 0x01, 0x02]), forKey: CalibrationStorageKeys.referencePosture)
        let storage = CalibrationStorage(userDefaults: defaults)

        // Verify: データが存在する
        XCTAssertNotNil(defaults.data(forKey: CalibrationStorageKeys.referencePosture))

        // When: 自動クリア付きで読み込み
        _ = storage.loadFaceReferencePostureWithAutoClean()

        // Then: 破損データがクリアされる
        XCTAssertNil(defaults.data(forKey: CalibrationStorageKeys.referencePosture))
    }
}
