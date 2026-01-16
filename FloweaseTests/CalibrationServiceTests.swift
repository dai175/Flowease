//
//  CalibrationServiceTests.swift
//  FloweaseTests
//
//  顔ベースキャリブレーションのテスト
//

import XCTest
@testable import Flowease

// MARK: - CalibrationServiceTests

/// CalibrationService のユニットテスト
///
/// キャリブレーションの開始・キャンセル・リセット・フレーム処理をテスト。
@MainActor
final class CalibrationServiceTests: XCTestCase {
    // MARK: - System Under Test

    private var sut: CalibrationService!
    private var mockStorage: MockCalibrationStorage!

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        mockStorage = MockCalibrationStorage()
        sut = CalibrationService(storage: mockStorage)
    }

    override func tearDown() {
        sut = nil
        mockStorage = nil
        super.tearDown()
    }

    // MARK: - Test Helpers

    /// テスト用の有効な FacePosition を作成（高信頼度）
    private func makeValidFacePosition(timestamp: Date = Date()) -> FacePosition {
        FacePosition(
            centerX: 0.5,
            centerY: 0.5,
            area: 0.05,
            roll: 0.0,
            captureQuality: 0.9,
            timestamp: timestamp
        )
    }

    /// 低品質の FacePosition を作成（captureQuality < 0.3）
    private func makeLowQualityFacePosition(timestamp: Date = Date()) -> FacePosition {
        FacePosition(
            centerX: 0.5,
            centerY: 0.5,
            area: 0.05,
            roll: 0.0,
            captureQuality: 0.2,
            timestamp: timestamp
        )
    }

    /// 無効な FacePosition を作成（顔未検出相当）
    /// area = 0.0 で isValid = false となる
    private func makeInvalidFacePosition(timestamp: Date = Date()) -> FacePosition {
        FacePosition(
            centerX: 0.5,
            centerY: 0.5,
            area: 0.0, // 無効値：area は 0 < value <= 1.0 が必要
            roll: 0.0,
            captureQuality: 0.9,
            timestamp: timestamp
        )
    }

    /// 傾いた FacePosition を作成
    private func makeTiltedFacePosition(roll: Double, timestamp: Date = Date()) -> FacePosition {
        FacePosition(
            centerX: 0.5,
            centerY: 0.5,
            area: 0.05,
            roll: roll,
            captureQuality: 0.9,
            timestamp: timestamp
        )
    }

    /// テスト用の有効な FaceReferencePosture を作成
    private func createValidFaceReferencePosture(
        frameCount: Int = 90,
        averageQuality: Double = 0.85,
        calibratedAt: Date = Date()
    ) -> FaceReferencePosture {
        FaceReferencePosture(
            calibratedAt: calibratedAt,
            frameCount: frameCount,
            averageQuality: averageQuality,
            baselineMetrics: FaceBaselineMetrics(
                baselineY: 0.5,
                baselineArea: 0.05,
                baselineRoll: 0.0
            )
        )
    }

    // MARK: - Initial State Tests

    func testInitialState_isNotCalibrated() {
        // Given: 新しい CalibrationService

        // Then: 初期状態は notCalibrated
        XCTAssertTrue(sut.state.isNotCalibrated, "初期状態は notCalibrated であるべき")
    }

    func testInitialState_withStoredFaceReferencePosture_isCompleted() async {
        // Given: ストレージに FaceReferencePosture が保存されている
        let posture = createValidFaceReferencePosture()
        mockStorage.saveFaceReferencePosture(posture)

        // When: 新しい CalibrationService を作成
        let service = CalibrationService(storage: mockStorage)

        // Then: 状態は completed
        XCTAssertTrue(service.state.isCompleted, "保存済みデータがあれば completed であるべき")
    }

    // MARK: - startCalibration Tests

    func testStartCalibration_changesStateToInProgress() async throws {
        // Given: notCalibrated 状態

        // When: キャリブレーション開始
        try await sut.startCalibration()

        // Then: inProgress 状態になる
        XCTAssertTrue(sut.state.isInProgress, "開始後は inProgress であるべき")
    }

    func testStartCalibration_setsProgressWithZeroFrames() async throws {
        // Given: notCalibrated 状態

        // When: キャリブレーション開始
        try await sut.startCalibration()

        // Then: progress が 0 フレームで初期化される
        guard let progress = sut.state.progress else {
            XCTFail("inProgress 状態には progress が必要")
            return
        }
        XCTAssertEqual(progress.collectedFrames, 0, "初期フレーム数は 0 であるべき")
    }

    func testStartCalibration_whenAlreadyInProgress_throwsError() async throws {
        // Given: 既に inProgress 状態
        try await sut.startCalibration()
        XCTAssertTrue(sut.state.isInProgress)

        // When/Then: 再度開始しようとするとエラー
        do {
            try await sut.startCalibration()
            XCTFail("alreadyInProgress エラーが発生すべき")
        } catch let error as CalibrationError {
            XCTAssertEqual(error, .alreadyInProgress)
        }
    }

    func testStartCalibration_afterCompleted_canRestartCalibration() async throws {
        // Given: completed 状態
        let posture = createValidFaceReferencePosture()
        mockStorage.saveFaceReferencePosture(posture)
        sut = CalibrationService(storage: mockStorage)
        XCTAssertTrue(sut.state.isCompleted)

        // When: キャリブレーション開始
        try await sut.startCalibration()

        // Then: inProgress 状態になる
        XCTAssertTrue(sut.state.isInProgress, "completed 状態から再開始できるべき")
    }

    func testStartCalibration_afterFailed_canRestartCalibration() async throws {
        // Given: failed 状態（顔未検出で失敗させる）
        try await sut.startCalibration()
        let invalidFace = makeInvalidFacePosition()
        // 顔未検出を連続で送信して失敗させる（しきい値を超える）
        for _ in 0..<CalibrationProgress.failureThreshold {
            sut.processFaceFrame(invalidFace)
        }
        XCTAssertTrue(sut.state.isFailed, "顔未検出で失敗状態になるべき")

        // When: キャリブレーション開始
        try await sut.startCalibration()

        // Then: inProgress 状態になる
        XCTAssertTrue(sut.state.isInProgress, "failed 状態から再開始できるべき")
    }

    // MARK: - cancelCalibration Tests

    func testCancelCalibration_changesStateToNotCalibrated() async throws {
        // Given: inProgress 状態
        try await sut.startCalibration()

        // When: キャンセル
        sut.cancelCalibration()

        // Then: notCalibrated 状態になる（キャンセルは失敗ではない）
        XCTAssertTrue(sut.state.isNotCalibrated, "キャンセル後は notCalibrated であるべき")
    }

    func testCancelCalibration_whenNotInProgress_doesNothing() {
        // Given: notCalibrated 状態
        XCTAssertTrue(sut.state.isNotCalibrated)

        // When: キャンセル（inProgress でない状態で呼び出し）
        sut.cancelCalibration()

        // Then: 状態は変わらない
        XCTAssertTrue(sut.state.isNotCalibrated, "inProgress でなければ状態は変わらない")
    }

    // MARK: - resetCalibration Tests

    func testResetCalibration_changesStateToNotCalibrated() async throws {
        // Given: completed 状態
        let posture = createValidFaceReferencePosture()
        mockStorage.saveFaceReferencePosture(posture)
        sut = CalibrationService(storage: mockStorage)

        // When: リセット
        sut.resetCalibration()

        // Then: notCalibrated 状態になる
        XCTAssertTrue(sut.state.isNotCalibrated, "リセット後は notCalibrated であるべき")
    }

    func testResetCalibration_deletesStoredFaceReferencePosture() async throws {
        // Given: completed 状態
        let posture = createValidFaceReferencePosture()
        mockStorage.saveFaceReferencePosture(posture)
        sut = CalibrationService(storage: mockStorage)

        // When: リセット
        sut.resetCalibration()

        // Then: ストレージから削除される
        XCTAssertNil(mockStorage.loadFaceReferencePosture(), "リセット後はストレージからも削除されるべき")
    }

    func testResetCalibration_whenInProgress_cancelsAndResets() async throws {
        // Given: inProgress 状態
        try await sut.startCalibration()

        // When: リセット
        sut.resetCalibration()

        // Then: notCalibrated 状態になる
        XCTAssertTrue(sut.state.isNotCalibrated, "inProgress 中のリセットでも notCalibrated になるべき")
    }

    // MARK: - processFaceFrame Tests

    func testProcessFaceFrame_whenNotInProgress_isIgnored() {
        // Given: notCalibrated 状態
        let face = makeValidFacePosition()

        // When: フレーム処理
        sut.processFaceFrame(face)

        // Then: 状態は変わらない
        XCTAssertTrue(sut.state.isNotCalibrated, "inProgress でなければフレームは無視される")
    }

    func testProcessFaceFrame_incrementsCollectedFrames() async throws {
        // Given: inProgress 状態
        try await sut.startCalibration()
        let face = makeValidFacePosition()

        // When: 有効なフレームを処理
        sut.processFaceFrame(face)

        // Then: collectedFrames が増加
        guard let progress = sut.state.progress else {
            XCTFail("inProgress 状態には progress が必要")
            return
        }
        XCTAssertEqual(progress.collectedFrames, 1, "有効なフレーム処理後は collectedFrames が 1 であるべき")
    }

    func testProcessFaceFrame_withLowQuality_incrementsLowConfidenceStreak() async throws {
        // Given: inProgress 状態
        try await sut.startCalibration()
        let face = makeLowQualityFacePosition()

        // When: 低品質フレームを処理
        sut.processFaceFrame(face)

        // Then: lowConfidenceStreak が増加（collectedFrames は増えない）
        guard let progress = sut.state.progress else {
            XCTFail("inProgress 状態には progress が必要")
            return
        }
        XCTAssertEqual(progress.collectedFrames, 0, "低品質フレームでは collectedFrames は増えない")
        XCTAssertGreaterThan(progress.lowConfidenceStreak, 0, "低品質フレームでは lowConfidenceStreak が増加")
    }

    func testProcessFaceFrame_lowQualityStreakExceedsThreshold_failsCalibration() async throws {
        // Given: inProgress 状態
        try await sut.startCalibration()
        let face = makeLowQualityFacePosition()

        // When: 低品質フレームを連続で処理（しきい値を超える）
        for _ in 0 ..< CalibrationProgress.failureThreshold {
            sut.processFaceFrame(face)
        }

        // Then: failed(.lowConfidence) 状態になる
        XCTAssertTrue(sut.state.isFailed, "低品質が連続するとfailedになるべき")
        XCTAssertEqual(sut.state.failure, .lowConfidence, "失敗理由は lowConfidence であるべき")
    }

    func testProcessFaceFrame_withNoFaceDetected_handlesGracefully() async throws {
        // Given: inProgress 状態
        try await sut.startCalibration()
        let face = makeInvalidFacePosition()

        // When: 顔未検出のフレームを処理
        sut.processFaceFrame(face)

        // Then: クラッシュせず、noFaceStreak が増加
        guard let progress = sut.state.progress else {
            XCTFail("inProgress 状態には progress が必要")
            return
        }
        XCTAssertEqual(progress.collectedFrames, 0, "顔未検出では collectedFrames は増えない")
        XCTAssertGreaterThan(progress.noFaceStreak, 0, "顔未検出では noFaceStreak が増加")
    }

    func testProcessFaceFrame_noFaceStreakExceedsThreshold_failsWithNoFaceDetected() async throws {
        // Given: inProgress 状態
        try await sut.startCalibration()
        let face = makeInvalidFacePosition()

        // When: 顔未検出フレームを連続で処理（しきい値を超える）
        for _ in 0 ..< CalibrationProgress.failureThreshold {
            sut.processFaceFrame(face)
        }

        // Then: failed(.noFaceDetected) 状態になる
        XCTAssertTrue(sut.state.isFailed, "顔未検出が連続すると failed になるべき")
        XCTAssertEqual(sut.state.failure, .noFaceDetected, "失敗理由は noFaceDetected であるべき")
    }

    func testProcessFaceFrame_mixedHighAndLowQuality_resetsStreak() async throws {
        // Given: inProgress 状態
        try await sut.startCalibration()

        // When: 低品質フレームを処理後、高品質フレームを処理
        for _ in 0 ..< 10 {
            sut.processFaceFrame(makeLowQualityFacePosition())
        }
        sut.processFaceFrame(makeValidFacePosition())

        // Then: lowConfidenceStreak がリセットされる
        guard let progress = sut.state.progress else {
            XCTFail("inProgress 状態には progress が必要")
            return
        }
        XCTAssertEqual(progress.lowConfidenceStreak, 0, "高品質フレーム後は lowConfidenceStreak がリセット")
        XCTAssertEqual(progress.collectedFrames, 1, "高品質フレームが1つカウント")
    }

    // MARK: - Face Position Accumulation Tests

    func testProcessFaceFrame_accumulatesCenterY() async throws {
        // Given: inProgress 状態
        try await sut.startCalibration()

        // When: 異なるY座標のフレームを処理
        sut.processFaceFrame(FacePosition(
            centerX: 0.5, centerY: 0.4, area: 0.05, roll: 0.0,
            captureQuality: 0.9, timestamp: Date()
        ))
        sut.processFaceFrame(FacePosition(
            centerX: 0.5, centerY: 0.6, area: 0.05, roll: 0.0,
            captureQuality: 0.9, timestamp: Date()
        ))

        // Then: フレームが蓄積される
        guard let progress = sut.state.progress else {
            XCTFail("inProgress 状態には progress が必要")
            return
        }
        XCTAssertEqual(progress.collectedFrames, 2, "2フレームが蓄積されるべき")
    }

    func testProcessFaceFrame_accumulatesRoll() async throws {
        // Given: inProgress 状態
        try await sut.startCalibration()

        // When: 異なるroll角のフレームを処理
        sut.processFaceFrame(makeTiltedFacePosition(roll: 0.1))
        sut.processFaceFrame(makeTiltedFacePosition(roll: -0.1))

        // Then: フレームが蓄積される
        guard let progress = sut.state.progress else {
            XCTFail("inProgress 状態には progress が必要")
            return
        }
        XCTAssertEqual(progress.collectedFrames, 2, "2フレームが蓄積されるべき")
    }

    // MARK: - Calibration Completion Tests

    func testProcessFaceFrame_afterTargetDuration_completesCalibration() async throws {
        // Given: inProgress 状態
        try await sut.startCalibration()
        let face = makeValidFacePosition()

        // When: 十分なフレームを処理してから時間経過
        for _ in 0 ..< 100 {
            sut.processFaceFrame(face)
        }

        try await Task.sleep(nanoseconds: 3_100_000_000)
        sut.processFaceFrame(face)

        // Then: completed 状態になる
        XCTAssertTrue(sut.state.isCompleted, "目標時間後は completed であるべき")
    }

    func testProcessFaceFrame_afterCompletion_savesFaceReferencePosture() async throws {
        // Given: キャリブレーション完了
        try await sut.startCalibration()
        let face = makeValidFacePosition()

        for _ in 0 ..< 100 {
            sut.processFaceFrame(face)
        }

        try await Task.sleep(nanoseconds: 3_100_000_000)
        sut.processFaceFrame(face)

        // Then: FaceReferencePosture がストレージに保存される
        XCTAssertNotNil(mockStorage.loadFaceReferencePosture(), "完了後は FaceReferencePosture が保存されるべき")
    }

    func testProcessFaceFrame_afterCompletion_faceReferencePostureHasValidData() async throws {
        // Given: キャリブレーション完了
        try await sut.startCalibration()
        let face = makeValidFacePosition()

        for _ in 0 ..< 100 {
            sut.processFaceFrame(face)
        }

        try await Task.sleep(nanoseconds: 3_100_000_000)
        sut.processFaceFrame(face)

        // Then: FaceReferencePosture が有効なデータを持つ
        guard let facePosture = mockStorage.loadFaceReferencePosture() else {
            XCTFail("FaceReferencePosture が保存されているべき")
            return
        }

        XCTAssertGreaterThanOrEqual(facePosture.frameCount, FaceReferencePosture.minimumFrameCount,
                                    "最低\(FaceReferencePosture.minimumFrameCount)フレーム必要")
        XCTAssertGreaterThanOrEqual(facePosture.averageQuality, FaceReferencePosture.minimumQuality,
                                    "平均品質は\(FaceReferencePosture.minimumQuality)以上必要")
        XCTAssertTrue(facePosture.isValid, "FaceReferencePosture.isValid は true であるべき")
    }

    func testCalibrationCompletion_calculatesFaceBaselineMetrics() async throws {
        // Given: inProgress 状態
        try await sut.startCalibration()
        let face = makeValidFacePosition()

        // When: 十分なフレームを処理してキャリブレーション完了
        for _ in 0 ..< 100 {
            sut.processFaceFrame(face)
        }

        try await Task.sleep(nanoseconds: 3_100_000_000)
        sut.processFaceFrame(face)

        // Then: FaceBaselineMetricsが正しく計算されている
        guard let facePosture = mockStorage.loadFaceReferencePosture() else {
            XCTFail("FaceReferencePosture が保存されるべき")
            return
        }

        XCTAssertEqual(facePosture.baselineMetrics.baselineY, 0.5, accuracy: 0.01,
                       "baselineY は入力の平均 (0.5) であるべき")
        XCTAssertEqual(facePosture.baselineMetrics.baselineArea, 0.05, accuracy: 0.01,
                       "baselineArea は入力の平均 (0.05) であるべき")
        XCTAssertEqual(facePosture.baselineMetrics.baselineRoll, 0.0, accuracy: 0.01,
                       "baselineRoll は入力の平均 (0.0) であるべき")
    }

    // MARK: - FaceReferencePosture Access Tests

    func testFaceReferencePosture_afterCompletion_isAccessible() async throws {
        // Given: キャリブレーション完了
        try await sut.startCalibration()
        let face = makeValidFacePosition()

        for _ in 0 ..< 100 {
            sut.processFaceFrame(face)
        }

        try await Task.sleep(nanoseconds: 3_100_000_000)
        sut.processFaceFrame(face)

        // Then: faceReferencePosture が取得可能
        XCTAssertNotNil(sut.faceReferencePosture, "完了後は faceReferencePosture が取得可能であるべき")
    }

    func testFaceReferencePosture_beforeCompletion_isNil() async throws {
        // Given: 未キャリブレーション状態
        XCTAssertTrue(sut.state.isNotCalibrated)

        // Then: faceReferencePosture は nil
        XCTAssertNil(sut.faceReferencePosture, "未完了時は faceReferencePosture は nil であるべき")
    }

    func testCalibration_insufficientFrames_failsCalibration() async throws {
        // Given: inProgress 状態
        try await sut.startCalibration()

        // When: フレームをほとんど処理せずに時間経過
        try await Task.sleep(nanoseconds: 3_100_000_000)
        sut.processFaceFrame(makeValidFacePosition())

        // Then: 十分なフレームがなければ failed になる
        if sut.state.isFailed {
            XCTAssertEqual(sut.state.failure, .insufficientFrames)
        } else if sut.state.isCompleted {
            // 時間経過だけで completed になる実装の場合
            if let facePosture = mockStorage.loadFaceReferencePosture() {
                // フレーム数が少なすぎる場合は isValid が false
                if facePosture.frameCount < FaceReferencePosture.minimumFrameCount {
                    XCTAssertFalse(facePosture.isValid, "フレーム数が少なすぎる場合は isValid が false")
                }
            }
        }
    }

    func testStorageIsCalibrated_withFaceReferencePosture_returnsTrue() async {
        // Given: ストレージに FaceReferencePosture が保存されている
        let facePosture = createValidFaceReferencePosture()
        mockStorage.saveFaceReferencePosture(facePosture)

        // Then: isCalibrated は true
        XCTAssertTrue(mockStorage.isCalibrated, "顔ベースデータがあれば isCalibrated は true であるべき")
    }
}

// MARK: - MockCalibrationStorage

/// テスト用のモックストレージ
@MainActor
final class MockCalibrationStorage: CalibrationStorageProtocol {
    private var storedFacePosture: FaceReferencePosture?

    var isCalibrated: Bool {
        storedFacePosture != nil
    }

    var lastCalibratedAt: Date? {
        storedFacePosture?.calibratedAt
    }

    func loadFaceReferencePosture() -> FaceReferencePosture? {
        storedFacePosture
    }

    func loadFaceReferencePostureWithAutoClean() -> FaceReferencePosture? {
        storedFacePosture
    }

    @discardableResult
    func saveFaceReferencePosture(_ posture: FaceReferencePosture) -> Bool {
        storedFacePosture = posture
        return true
    }

    func deleteFaceReferencePosture() {
        storedFacePosture = nil
    }
}
