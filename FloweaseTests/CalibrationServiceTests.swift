//
//  CalibrationServiceTests.swift
//  FloweaseTests
//
//  T011: CalibrationServiceのテスト
//
//  CalibrationServiceProtocol の実装をテストする。
//  TDD方式: このテストは実装前に失敗することを確認する。
//

import XCTest
@testable import Flowease

// MARK: - CalibrationServiceTests

/// CalibrationService のユニットテスト
///
/// キャリブレーションの開始・キャンセル・リセット・フレーム処理をテスト。
/// contracts/CalibrationService.md に基づく。
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

    /// テスト用の JointPosition を作成
    private func makeJoint(
        x: Double = 0.5,
        y: Double = 0.5,
        confidence: Double = 0.9
    ) -> JointPosition {
        JointPosition(x: x, y: y, confidence: confidence)
    }

    /// 有効な BodyPose を作成（高信頼度）
    private func makeValidPose(timestamp: Date = Date()) -> BodyPose {
        BodyPose(
            nose: makeJoint(x: 0.5, y: 0.8),
            neck: makeJoint(x: 0.5, y: 0.6),
            leftShoulder: makeJoint(x: 0.35, y: 0.4),
            rightShoulder: makeJoint(x: 0.65, y: 0.4),
            leftEar: makeJoint(x: 0.45, y: 0.82),
            rightEar: makeJoint(x: 0.55, y: 0.82),
            root: makeJoint(x: 0.5, y: 0.2),
            timestamp: timestamp
        )
    }

    /// 低信頼度の BodyPose を作成
    private func makeLowConfidencePose(timestamp: Date = Date()) -> BodyPose {
        BodyPose(
            nose: makeJoint(x: 0.5, y: 0.8, confidence: 0.3),
            neck: makeJoint(x: 0.5, y: 0.6, confidence: 0.3),
            leftShoulder: makeJoint(x: 0.35, y: 0.4, confidence: 0.3),
            rightShoulder: makeJoint(x: 0.65, y: 0.4, confidence: 0.3),
            leftEar: nil,
            rightEar: nil,
            root: nil,
            timestamp: timestamp
        )
    }

    /// 人物未検出の BodyPose を作成（必須関節なし）
    private func makeNoPersonPose(timestamp: Date = Date()) -> BodyPose {
        BodyPose(
            nose: nil,
            neck: nil,
            leftShoulder: nil,
            rightShoulder: nil,
            leftEar: nil,
            rightEar: nil,
            root: nil,
            timestamp: timestamp
        )
    }

    // MARK: - Initial State Tests

    func testInitialState_isNotCalibrated() {
        // Given: 新しい CalibrationService

        // Then: 初期状態は notCalibrated
        XCTAssertTrue(sut.state.isNotCalibrated, "初期状態は notCalibrated であるべき")
    }

    func testInitialState_withStoredReferencePosture_isCompleted() async {
        // Given: ストレージに ReferencePosture が保存されている
        let posture = createValidReferencePosture()
        mockStorage.saveReferencePosture(posture)

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
        let posture = createValidReferencePosture()
        mockStorage.saveReferencePosture(posture)
        sut = CalibrationService(storage: mockStorage)
        XCTAssertTrue(sut.state.isCompleted)

        // When: キャリブレーション開始
        try await sut.startCalibration()

        // Then: inProgress 状態になる
        XCTAssertTrue(sut.state.isInProgress, "completed 状態から再開始できるべき")
    }

    func testStartCalibration_afterFailed_canRestartCalibration() async throws {
        // Given: failed 状態（キャンセルで失敗させる）
        try await sut.startCalibration()
        sut.cancelCalibration()
        XCTAssertTrue(sut.state.isFailed)

        // When: キャリブレーション開始
        try await sut.startCalibration()

        // Then: inProgress 状態になる
        XCTAssertTrue(sut.state.isInProgress, "failed 状態から再開始できるべき")
    }

    // MARK: - cancelCalibration Tests

    func testCancelCalibration_changesStateToFailed() async throws {
        // Given: inProgress 状態
        try await sut.startCalibration()

        // When: キャンセル
        sut.cancelCalibration()

        // Then: failed(.cancelled) 状態になる
        XCTAssertTrue(sut.state.isFailed, "キャンセル後は failed であるべき")
        XCTAssertEqual(sut.state.failure, .cancelled, "失敗理由は cancelled であるべき")
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
        let posture = createValidReferencePosture()
        mockStorage.saveReferencePosture(posture)
        sut = CalibrationService(storage: mockStorage)

        // When: リセット
        sut.resetCalibration()

        // Then: notCalibrated 状態になる
        XCTAssertTrue(sut.state.isNotCalibrated, "リセット後は notCalibrated であるべき")
    }

    func testResetCalibration_deletesStoredReferencePosture() async throws {
        // Given: completed 状態
        let posture = createValidReferencePosture()
        mockStorage.saveReferencePosture(posture)
        sut = CalibrationService(storage: mockStorage)

        // When: リセット
        sut.resetCalibration()

        // Then: ストレージから削除される
        XCTAssertNil(mockStorage.loadReferencePosture(), "リセット後はストレージからも削除されるべき")
    }

    func testResetCalibration_whenInProgress_cancelsAndResets() async throws {
        // Given: inProgress 状態
        try await sut.startCalibration()

        // When: リセット
        sut.resetCalibration()

        // Then: notCalibrated 状態になる
        XCTAssertTrue(sut.state.isNotCalibrated, "inProgress 中のリセットでも notCalibrated になるべき")
    }

    // MARK: - processFrame Tests

    func testProcessFrame_whenNotInProgress_isIgnored() {
        // Given: notCalibrated 状態
        let pose = makeValidPose()

        // When: フレーム処理
        sut.processFrame(pose)

        // Then: 状態は変わらない
        XCTAssertTrue(sut.state.isNotCalibrated, "inProgress でなければフレームは無視される")
    }

    func testProcessFrame_incrementsCollectedFrames() async throws {
        // Given: inProgress 状態
        try await sut.startCalibration()
        let pose = makeValidPose()

        // When: 有効なフレームを処理
        sut.processFrame(pose)

        // Then: collectedFrames が増加
        guard let progress = sut.state.progress else {
            XCTFail("inProgress 状態には progress が必要")
            return
        }
        XCTAssertEqual(progress.collectedFrames, 1, "有効なフレーム処理後は collectedFrames が 1 であるべき")
    }

    func testProcessFrame_withLowConfidence_incrementsLowConfidenceStreak() async throws {
        // Given: inProgress 状態
        try await sut.startCalibration()
        let pose = makeLowConfidencePose()

        // When: 低信頼度フレームを処理
        sut.processFrame(pose)

        // Then: lowConfidenceStreak が増加（collectedFrames は増えない）
        guard let progress = sut.state.progress else {
            XCTFail("inProgress 状態には progress が必要")
            return
        }
        XCTAssertEqual(progress.collectedFrames, 0, "低信頼度フレームでは collectedFrames は増えない")
        XCTAssertGreaterThan(progress.lowConfidenceStreak, 0, "低信頼度フレームでは lowConfidenceStreak が増加")
    }

    func testProcessFrame_lowConfidenceStreakExceedsThreshold_failsCalibration() async throws {
        // Given: inProgress 状態
        try await sut.startCalibration()
        let pose = makeLowConfidencePose()

        // When: 低信頼度フレームを連続で処理（しきい値を超える）
        for _ in 0 ..< CalibrationProgress.failureThreshold {
            sut.processFrame(pose)
        }

        // Then: failed(.lowConfidence) 状態になる
        XCTAssertTrue(sut.state.isFailed, "低信頼度が連続するとfailedになるべき")
        XCTAssertEqual(sut.state.failure, .lowConfidence, "失敗理由は lowConfidence であるべき")
    }

    // MARK: - Calibration Completion Tests

    func testProcessFrame_afterTargetDuration_completesCalibration() async throws {
        // Given: inProgress 状態（短い目標時間で設定）
        try await sut.startCalibration()
        let pose = makeValidPose()

        // When: 十分な時間経過後にフレーム処理
        // Note: 実際のテストでは時間を模擬する必要がある
        // ここでは十分なフレーム数を処理してから時間経過をシミュレート
        for _ in 0 ..< 100 {
            sut.processFrame(pose)
        }

        // 時間経過をシミュレート（3秒以上待つ）
        // テスト用に CalibrationService が時間経過をチェックする想定
        try await Task.sleep(nanoseconds: 3_100_000_000)
        sut.processFrame(pose)

        // Then: completed 状態になる
        XCTAssertTrue(sut.state.isCompleted, "目標時間後は completed であるべき")
    }

    func testProcessFrame_afterCompletion_savesReferencePosture() async throws {
        // Given: キャリブレーション完了
        try await sut.startCalibration()
        let pose = makeValidPose()

        for _ in 0 ..< 100 {
            sut.processFrame(pose)
        }

        try await Task.sleep(nanoseconds: 3_100_000_000)
        sut.processFrame(pose)

        // Then: ReferencePosture がストレージに保存される
        XCTAssertNotNil(mockStorage.loadReferencePosture(), "完了後は ReferencePosture が保存されるべき")
    }

    func testProcessFrame_afterCompletion_referencePostureHasValidData() async throws {
        // Given: キャリブレーション完了
        try await sut.startCalibration()
        let pose = makeValidPose()

        for _ in 0 ..< 100 {
            sut.processFrame(pose)
        }

        try await Task.sleep(nanoseconds: 3_100_000_000)
        sut.processFrame(pose)

        // Then: ReferencePosture が有効なデータを持つ
        guard let referencePosture = mockStorage.loadReferencePosture() else {
            XCTFail("ReferencePosture が保存されているべき")
            return
        }

        XCTAssertGreaterThanOrEqual(referencePosture.frameCount, 30, "最低30フレーム必要")
        XCTAssertGreaterThanOrEqual(referencePosture.averageConfidence, 0.7, "平均信頼度は0.7以上必要")
    }

    // MARK: - Edge Case Tests

    func testProcessFrame_withNoFaceDetected_handlesGracefully() async throws {
        // Given: inProgress 状態
        try await sut.startCalibration()
        let pose = makeNoPersonPose()

        // When: 顔未検出のフレームを処理
        sut.processFrame(pose)

        // Then: クラッシュせず、noFaceStreak が増加
        guard let progress = sut.state.progress else {
            XCTFail("inProgress 状態には progress が必要")
            return
        }
        XCTAssertEqual(progress.collectedFrames, 0, "顔未検出では collectedFrames は増えない")
        XCTAssertGreaterThan(progress.noFaceStreak, 0, "顔未検出では noFaceStreak が増加")
    }

    func testProcessFrame_noFaceStreakExceedsThreshold_failsWithNoFaceDetected() async throws {
        // Given: inProgress 状態
        try await sut.startCalibration()
        let pose = makeNoPersonPose()

        // When: 顔未検出フレームを連続で処理（しきい値を超える）
        for _ in 0 ..< CalibrationProgress.failureThreshold {
            sut.processFrame(pose)
        }

        // Then: failed(.noFaceDetected) 状態になる
        XCTAssertTrue(sut.state.isFailed, "顔未検出が連続すると failed になるべき")
        XCTAssertEqual(sut.state.failure, .noFaceDetected, "失敗理由は noFaceDetected であるべき")
    }

    func testProcessFrame_mixedHighAndLowConfidence_resetsStreak() async throws {
        // Given: inProgress 状態
        try await sut.startCalibration()

        // When: 低信頼度フレームを処理後、高信頼度フレームを処理
        for _ in 0 ..< 10 {
            sut.processFrame(makeLowConfidencePose())
        }
        sut.processFrame(makeValidPose())

        // Then: lowConfidenceStreak がリセットされる
        guard let progress = sut.state.progress else {
            XCTFail("inProgress 状態には progress が必要")
            return
        }
        XCTAssertEqual(progress.lowConfidenceStreak, 0, "高信頼度フレーム後は lowConfidenceStreak がリセット")
        XCTAssertEqual(progress.collectedFrames, 1, "高信頼度フレームが1つカウント")
    }

    func testProcessFrame_mixedNoFaceAndHighConfidence_resetsStreak() async throws {
        // Given: inProgress 状態
        try await sut.startCalibration()

        // When: 顔未検出フレームを処理後、高信頼度フレームを処理
        for _ in 0 ..< 10 {
            sut.processFrame(makeNoPersonPose())
        }
        sut.processFrame(makeValidPose())

        // Then: noFaceStreak がリセットされる
        guard let progress = sut.state.progress else {
            XCTFail("inProgress 状態には progress が必要")
            return
        }
        XCTAssertEqual(progress.noFaceStreak, 0, "高信頼度フレーム後は noFaceStreak がリセット")
        XCTAssertEqual(progress.collectedFrames, 1, "高信頼度フレームが1つカウント")
    }

    func testCalibration_insufficientFrames_failsCalibration() async throws {
        // Given: inProgress 状態
        try await sut.startCalibration()

        // When: フレームをほとんど処理せずに時間経過
        try await Task.sleep(nanoseconds: 3_100_000_000)
        sut.processFrame(makeValidPose())

        // Then: 十分なフレームがなければ failed になる
        // Note: 実装によっては completed になる可能性もある
        // フレーム数が30未満の場合は failed(.insufficientFrames) になることを期待
        if sut.state.isFailed {
            XCTAssertEqual(sut.state.failure, .insufficientFrames)
        } else if sut.state.isCompleted {
            // 時間経過だけで completed になる実装の場合
            // ReferencePosture の isValid が false になることを確認
            if let posture = mockStorage.loadReferencePosture() {
                // フレーム数が少なすぎる場合は isValid が false
                if posture.frameCount < 30 {
                    XCTAssertFalse(posture.isValid, "フレーム数が少なすぎる場合は isValid が false")
                }
            }
        }
    }

    // MARK: - Test Helpers

    /// テスト用の有効な ReferencePosture を作成
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
}

// MARK: - MockCalibrationStorage

/// テスト用のモックストレージ
@MainActor
final class MockCalibrationStorage: CalibrationStorageProtocol {
    private var storedPosture: ReferencePosture?
    private var storedFacePosture: FaceReferencePosture?

    var isCalibrated: Bool {
        storedPosture != nil || storedFacePosture != nil
    }

    var lastCalibratedAt: Date? {
        storedFacePosture?.calibratedAt ?? storedPosture?.calibratedAt
    }

    func loadReferencePosture() -> ReferencePosture? {
        storedPosture
    }

    @discardableResult
    func saveReferencePosture(_ posture: ReferencePosture) -> Bool {
        storedPosture = posture
        return true
    }

    func deleteReferencePosture() {
        storedPosture = nil
        storedFacePosture = nil
    }

    // Face-Based Calibration
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
}

// Note: CalibrationError は Flowease/Services/CalibrationService.swift で定義されています

// MARK: - Face-Based Calibration Tests (T024)

/// 顔ベースキャリブレーションのテスト
///
/// T024: CalibrationServiceをFacePositionベースに拡張するためのテスト
/// TDD方式: このテストは実装前に失敗することを確認する。
@MainActor
final class FaceCalibrationServiceTests: XCTestCase {
    // MARK: - System Under Test

    private var sut: CalibrationService!
    private var mockStorage: MockFaceCalibrationStorage!

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        mockStorage = MockFaceCalibrationStorage()
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

    /// 前傾した FacePosition を作成（面積が大きい）
    private func makeForwardLeanedFacePosition(timestamp: Date = Date()) -> FacePosition {
        FacePosition(
            centerX: 0.5,
            centerY: 0.4, // Y座標が下がる
            area: 0.08,   // 面積が大きくなる
            roll: 0.0,
            captureQuality: 0.9,
            timestamp: timestamp
        )
    }

    // MARK: - processFaceFrame Basic Tests

    func testProcessFaceFrame_whenNotInProgress_isIgnored() async throws {
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

    // MARK: - Face Position Accumulation Tests (T027)

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

    func testProcessFaceFrame_accumulatesArea() async throws {
        // Given: inProgress 状態
        try await sut.startCalibration()

        // When: 異なる面積のフレームを処理
        sut.processFaceFrame(FacePosition(
            centerX: 0.5, centerY: 0.5, area: 0.03, roll: 0.0,
            captureQuality: 0.9, timestamp: Date()
        ))
        sut.processFaceFrame(FacePosition(
            centerX: 0.5, centerY: 0.5, area: 0.07, roll: 0.0,
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

    // MARK: - FaceBaselineMetrics Calculation Tests (T028)

    func testCalibrationCompletion_calculatesFaceBaselineMetrics() async throws {
        // Given: inProgress 状態
        try await sut.startCalibration()
        let face = makeValidFacePosition()

        // When: 十分なフレームを処理してキャリブレーション完了
        for _ in 0 ..< 100 {
            sut.processFaceFrame(face)
        }

        // 時間経過をシミュレート
        try await Task.sleep(nanoseconds: 3_100_000_000)
        sut.processFaceFrame(face)

        // Then: FaceReferencePostureが保存される
        guard let facePosture = mockStorage.loadFaceReferencePosture() else {
            XCTFail("FaceReferencePosture が保存されるべき")
            return
        }

        // FaceBaselineMetricsが正しく計算されている
        XCTAssertEqual(facePosture.baselineMetrics.baselineY, 0.5, accuracy: 0.01,
                       "baselineY は入力の平均 (0.5) であるべき")
        XCTAssertEqual(facePosture.baselineMetrics.baselineArea, 0.05, accuracy: 0.01,
                       "baselineArea は入力の平均 (0.05) であるべき")
        XCTAssertEqual(facePosture.baselineMetrics.baselineRoll, 0.0, accuracy: 0.01,
                       "baselineRoll は入力の平均 (0.0) であるべき")
    }

    func testCalibrationCompletion_averagesMultipleFacePositions() async throws {
        // Given: inProgress 状態
        try await sut.startCalibration()

        // When: 異なる位置のフレームを処理
        for i in 0 ..< 50 {
            // Y座標: 0.4 と 0.6 を交互に（平均 0.5）
            let face = FacePosition(
                centerX: 0.5,
                centerY: i % 2 == 0 ? 0.4 : 0.6,
                area: 0.05,
                roll: 0.0,
                captureQuality: 0.9,
                timestamp: Date()
            )
            sut.processFaceFrame(face)
        }

        // 時間経過をシミュレート
        try await Task.sleep(nanoseconds: 3_100_000_000)
        sut.processFaceFrame(makeValidFacePosition())

        // Then: 平均値が計算される
        guard let facePosture = mockStorage.loadFaceReferencePosture() else {
            XCTFail("FaceReferencePosture が保存されるべき")
            return
        }

        XCTAssertEqual(facePosture.baselineMetrics.baselineY, 0.5, accuracy: 0.05,
                       "baselineY は平均値に近いべき")
    }

    // MARK: - FaceReferencePosture Creation Tests (T029)

    func testCalibrationCompletion_createsFaceReferencePosture() async throws {
        // Given: inProgress 状態
        try await sut.startCalibration()
        let face = makeValidFacePosition()

        // When: 十分なフレームを処理してキャリブレーション完了
        for _ in 0 ..< 100 {
            sut.processFaceFrame(face)
        }

        try await Task.sleep(nanoseconds: 3_100_000_000)
        sut.processFaceFrame(face)

        // Then: 状態が completed になる
        XCTAssertTrue(sut.state.isCompleted, "十分なフレーム後は completed であるべき")
    }

    func testCalibrationCompletion_faceReferencePostureHasValidFrameCount() async throws {
        // Given: inProgress 状態
        try await sut.startCalibration()
        let face = makeValidFacePosition()

        // When: 十分なフレームを処理
        for _ in 0 ..< 100 {
            sut.processFaceFrame(face)
        }

        try await Task.sleep(nanoseconds: 3_100_000_000)
        sut.processFaceFrame(face)

        // Then: frameCount が minimumFrameCount 以上
        guard let facePosture = mockStorage.loadFaceReferencePosture() else {
            XCTFail("FaceReferencePosture が保存されるべき")
            return
        }

        XCTAssertGreaterThanOrEqual(
            facePosture.frameCount,
            FaceReferencePosture.minimumFrameCount,
            "frameCount は最低 \(FaceReferencePosture.minimumFrameCount) 以上"
        )
    }

    func testCalibrationCompletion_faceReferencePostureHasValidAverageQuality() async throws {
        // Given: inProgress 状態
        try await sut.startCalibration()
        let face = makeValidFacePosition()

        // When: 高品質フレームを処理
        for _ in 0 ..< 100 {
            sut.processFaceFrame(face)
        }

        try await Task.sleep(nanoseconds: 3_100_000_000)
        sut.processFaceFrame(face)

        // Then: averageQuality が minimumQuality 以上
        guard let facePosture = mockStorage.loadFaceReferencePosture() else {
            XCTFail("FaceReferencePosture が保存されるべき")
            return
        }

        XCTAssertGreaterThanOrEqual(
            facePosture.averageQuality,
            FaceReferencePosture.minimumQuality,
            "averageQuality は最低 \(FaceReferencePosture.minimumQuality) 以上"
        )
    }

    func testCalibrationCompletion_faceReferencePostureIsValid() async throws {
        // Given: inProgress 状態
        try await sut.startCalibration()
        let face = makeValidFacePosition()

        // When: 十分なフレームを処理
        for _ in 0 ..< 100 {
            sut.processFaceFrame(face)
        }

        try await Task.sleep(nanoseconds: 3_100_000_000)
        sut.processFaceFrame(face)

        // Then: isValid が true
        guard let facePosture = mockStorage.loadFaceReferencePosture() else {
            XCTFail("FaceReferencePosture が保存されるべき")
            return
        }

        XCTAssertTrue(facePosture.isValid, "FaceReferencePosture.isValid は true であるべき")
    }

    func testCalibrationCompletion_insufficientFrames_failsCalibration() async throws {
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

    // MARK: - Initial State with Face Calibration Tests

    func testInitialState_withStoredFaceReferencePosture_isCompleted() async {
        // Given: ストレージに FaceReferencePosture が保存されている
        let facePosture = FaceReferencePosture(
            calibratedAt: Date(),
            frameCount: 50,
            averageQuality: 0.9,
            baselineMetrics: FaceBaselineMetrics(
                baselineY: 0.5,
                baselineArea: 0.05,
                baselineRoll: 0.0
            )
        )
        mockStorage.saveFaceReferencePosture(facePosture)

        // When: 新しい CalibrationService を作成
        let service = CalibrationService(storage: mockStorage)

        // Then: 状態は completed（アプリ再起動後もキャリブレーション済みとして認識）
        XCTAssertTrue(service.state.isCompleted, "保存済み顔ベースデータがあれば completed であるべき")
    }

    func testStorageIsCalibrated_withFaceReferencePosture_returnsTrue() async {
        // Given: ストレージに FaceReferencePosture が保存されている
        let facePosture = FaceReferencePosture(
            calibratedAt: Date(),
            frameCount: 50,
            averageQuality: 0.9,
            baselineMetrics: FaceBaselineMetrics(
                baselineY: 0.5,
                baselineArea: 0.05,
                baselineRoll: 0.0
            )
        )
        mockStorage.saveFaceReferencePosture(facePosture)

        // Then: isCalibrated は true
        XCTAssertTrue(mockStorage.isCalibrated, "顔ベースデータがあれば isCalibrated は true であるべき")
    }
}

// MARK: - MockFaceCalibrationStorage

/// 顔ベースキャリブレーション用のモックストレージ
@MainActor
final class MockFaceCalibrationStorage: CalibrationStorageProtocol {
    private var storedPosture: ReferencePosture?
    private var storedFacePosture: FaceReferencePosture?

    var isCalibrated: Bool {
        storedPosture != nil || storedFacePosture != nil
    }

    var lastCalibratedAt: Date? {
        storedFacePosture?.calibratedAt ?? storedPosture?.calibratedAt
    }

    func loadReferencePosture() -> ReferencePosture? {
        storedPosture
    }

    @discardableResult
    func saveReferencePosture(_ posture: ReferencePosture) -> Bool {
        storedPosture = posture
        return true
    }

    func deleteReferencePosture() {
        storedPosture = nil
        storedFacePosture = nil
    }

    // MARK: - Face-Based Storage

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
}
