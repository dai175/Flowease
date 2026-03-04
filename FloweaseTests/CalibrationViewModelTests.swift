//
//  CalibrationViewModelTests.swift
//  FloweaseTests
//
//  CalibrationViewModel のユニットテスト
//

import XCTest
@testable import Flowease

// MARK: - CalibrationViewModelTests

/// CalibrationViewModel のユニットテスト
///
/// 状態表示プロパティ、キャリブレーション操作をテスト。
@MainActor
final class CalibrationViewModelTests: XCTestCase {
    // MARK: - System Under Test

    private var sut: CalibrationViewModel!
    private var mockStorage: MockCalibrationStorageForCalibrationVM!
    private var calibrationService: CalibrationService!

    // MARK: - Setup / Teardown

    override func setUp() async throws {
        try await super.setUp()
        mockStorage = MockCalibrationStorageForCalibrationVM()
        calibrationService = CalibrationService(storage: mockStorage)
        sut = CalibrationViewModel(calibrationService: calibrationService)
    }

    override func tearDown() async throws {
        sut = nil
        calibrationService = nil
        mockStorage = nil
        try await super.tearDown()
    }

    // MARK: - Test Helpers

    /// 有効な FaceReferencePosture を作成
    private func makeValidFaceReferencePosture(calibratedAt: Date = Date()) -> FaceReferencePosture {
        FaceReferencePosture(
            calibratedAt: calibratedAt,
            frameCount: 90,
            averageQuality: 0.85,
            baselineMetrics: FaceBaselineMetrics(baselineY: 0.5, baselineArea: 0.05, baselineRoll: 0.0)
        )
    }

    // MARK: - Initial State Tests

    func testInitialState_isNotCalibrated() {
        XCTAssertFalse(sut.isCalibrated, "初期状態はキャリブレーション未完了")
    }

    func testInitialState_isNotInProgress() {
        XCTAssertFalse(sut.isInProgress, "初期状態はキャリブレーション実行中でない")
    }

    func testInitialState_progressIsZero() {
        XCTAssertEqual(sut.displayProgress, 0, "初期状態の進捗は0")
    }

    func testInitialState_errorMessageIsNil() {
        XCTAssertNil(sut.errorMessage, "初期状態ではエラーなし")
    }

    // MARK: - State Delegation Tests

    func testState_delegatesToCalibrationService() {
        // Given: CalibrationService の状態が notCalibrated

        // Then: ViewModel の状態も一致する
        XCTAssertTrue(sut.state.isNotCalibrated, "状態が CalibrationService と一致")
    }

    // MARK: - statusText Tests

    func testStatusText_whenNotCalibrated_returnsNotConfigured() {
        XCTAssertEqual(sut.statusText, "Calibration not configured", "未キャリブレーション時のステータステキスト")
    }

    func testStatusText_whenCompleted_returnsComplete() async throws {
        // Given: 完了状態
        mockStorage.saveFaceReferencePosture(makeValidFaceReferencePosture())
        calibrationService = CalibrationService(storage: mockStorage)
        sut = CalibrationViewModel(calibrationService: calibrationService)

        // Then
        XCTAssertEqual(sut.statusText, "Calibration Complete", "完了時のステータステキスト")
    }

    // MARK: - statusSummary Tests

    func testStatusSummary_whenNotCalibrated_returnsNotConfigured() {
        XCTAssertEqual(sut.statusSummary, "Not configured", "未キャリブレーション時のサマリー")
    }

    // MARK: - recommendationMessage Tests

    func testRecommendationMessage_whenNotCalibrated_returnsMessage() {
        XCTAssertNotNil(sut.recommendationMessage, "未キャリブレーション時は推奨メッセージあり")
        XCTAssertEqual(
            sut.recommendationMessage,
            "Configure calibration for more accurate posture assessment",
            "推奨メッセージの内容が正しい"
        )
    }

    // MARK: - qualityWarningMessage Tests

    func testQualityWarningMessage_whenNotInProgress_returnsNil() {
        XCTAssertNil(sut.qualityWarningMessage, "実行中でなければ警告メッセージなし")
    }

    // MARK: - startCalibration Tests

    func testStartCalibration_setsIsInProgressToTrue() async {
        // When
        await sut.startCalibration()

        // Then
        XCTAssertTrue(sut.isInProgress, "開始後は実行中")
    }

    func testStartCalibration_whenAlreadyInProgress_setsErrorMessage() async {
        // Given: 既に実行中
        await sut.startCalibration()
        XCTAssertTrue(sut.isInProgress)
        XCTAssertNil(sut.errorMessage)

        // When: 再度開始
        await sut.startCalibration()

        // Then: エラーメッセージが設定される
        XCTAssertNotNil(sut.errorMessage, "二重開始時はエラーメッセージあり")
    }

    // MARK: - cancelCalibration Tests

    func testCancelCalibration_setsStateToNotCalibrated() async {
        // Given: 実行中
        await sut.startCalibration()
        XCTAssertTrue(sut.isInProgress)

        // When
        sut.cancelCalibration()

        // Then
        XCTAssertTrue(sut.state.isNotCalibrated, "キャンセル後は notCalibrated 状態")
    }

    // MARK: - clearError Tests

    func testClearError_clearsErrorMessage() async {
        // Given: エラーがある状態
        await sut.startCalibration()
        await sut.startCalibration() // 二重開始でエラー発生
        XCTAssertNotNil(sut.errorMessage)

        // When
        sut.clearError()

        // Then
        XCTAssertNil(sut.errorMessage, "エラーがクリアされる")
    }

    // MARK: - showError Tests

    func testShowError_whenErrorMessageExists_returnsTrue() async {
        // Given: エラーがある状態
        await sut.startCalibration()
        await sut.startCalibration() // 二重開始でエラー発生
        XCTAssertNotNil(sut.errorMessage)

        // Then
        XCTAssertTrue(sut.showError, "エラーメッセージがあれば showError は true")
    }

    func testShowError_whenNoError_returnsFalse() {
        XCTAssertFalse(sut.showError, "エラーがなければ showError は false")
    }

    // MARK: - faceReferencePosture Tests

    func testFaceReferencePosture_whenNotCompleted_returnsNil() {
        XCTAssertNil(sut.faceReferencePosture, "未完了では基準姿勢は nil")
    }

    // MARK: - calibratedAtText Tests

    func testCalibratedAtText_whenNotCompleted_returnsNil() {
        XCTAssertNil(sut.calibratedAtText, "未完了では日時テキストは nil")
    }
}

// MARK: - Mock Classes

/// テスト用の MockCalibrationStorage
@MainActor
private final class MockCalibrationStorageForCalibrationVM: CalibrationStorageProtocol {
    private var storedFacePosture: FaceReferencePosture?

    var isCalibrated: Bool { storedFacePosture != nil }
    var lastCalibratedAt: Date? { storedFacePosture?.calibratedAt }

    func loadFaceReferencePosture() -> FaceReferencePosture? { storedFacePosture }
    func loadFaceReferencePostureWithAutoClean() -> FaceReferencePosture? { storedFacePosture }

    @discardableResult
    func saveFaceReferencePosture(_ posture: FaceReferencePosture) -> Bool {
        storedFacePosture = posture
        return true
    }

    func deleteFaceReferencePosture() { storedFacePosture = nil }
}
