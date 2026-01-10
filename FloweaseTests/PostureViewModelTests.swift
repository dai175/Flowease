//
//  PostureViewModelTests.swift
//  FloweaseTests
//
//  PostureViewModel のユニットテスト
//

@preconcurrency import AVFoundation
import XCTest
@testable import Flowease

// MARK: - PostureViewModelTests

/// PostureViewModel のユニットテスト
///
/// スコア履歴管理、状態更新、スムージング計算をテスト。
@MainActor
final class PostureViewModelTests: XCTestCase {
    // MARK: - System Under Test

    private var sut: PostureViewModel!
    private var mockCameraService: MockCameraServiceForViewModel!
    private var mockPostureAnalyzer: MockPostureAnalyzerForViewModel!
    private var mockCalibrationStorage: MockCalibrationStorageForViewModel!
    private var calibrationService: CalibrationService!

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        mockCameraService = MockCameraServiceForViewModel()
        mockPostureAnalyzer = MockPostureAnalyzerForViewModel()
        mockCalibrationStorage = MockCalibrationStorageForViewModel()
        calibrationService = CalibrationService(storage: mockCalibrationStorage)
        sut = PostureViewModel(
            cameraService: mockCameraService,
            postureAnalyzer: mockPostureAnalyzer,
            faceScoreCalculator: FaceScoreCalculator(),
            calibrationService: calibrationService
        )
    }

    override func tearDown() {
        sut = nil
        calibrationService = nil
        mockCalibrationStorage = nil
        mockPostureAnalyzer = nil
        mockCameraService = nil
        super.tearDown()
    }

    // MARK: - Test Helpers

    /// テスト用の PostureScore を作成
    private func makePostureScore(value: Int) -> PostureScore {
        let breakdown = ScoreBreakdown(verticalPosition: value, sizeChange: value, tilt: value)
        return PostureScore(value: value, timestamp: Date(), breakdown: breakdown, confidence: 1.0)
    }

    // MARK: - Initial State Tests

    func testInitialState_scoreHistoryIsEmpty() {
        XCTAssertTrue(sut.scoreHistory.isEmpty, "初期状態ではスコア履歴は空")
    }

    func testInitialState_smoothedScoreIsZero() {
        XCTAssertEqual(sut.smoothedScore, 0, "初期状態ではスムージングスコアは0")
    }

    func testInitialState_monitoringStateIsPaused() {
        if case .paused = sut.monitoringState {
            // 期待通り
        } else {
            XCTFail("初期状態は paused であるべき")
        }
    }

    // MARK: - addScore Tests

    func testAddScore_addsScoreToHistory() {
        // Given
        let score = makePostureScore(value: 80)

        // When
        sut.addScore(score)

        // Then
        XCTAssertEqual(sut.scoreHistory.count, 1, "スコアが1つ追加される")
        XCTAssertEqual(sut.scoreHistory.first?.value, 80, "追加されたスコアの値が正しい")
    }

    func testAddScore_updatesMonitoringStateToActive() {
        // Given
        let score = makePostureScore(value: 80)

        // When
        sut.addScore(score)

        // Then
        if case let .active(activeScore) = sut.monitoringState {
            XCTAssertEqual(activeScore.value, 80, "active 状態のスコアが正しい")
        } else {
            XCTFail("スコア追加後は active 状態であるべき")
        }
    }

    func testAddScore_respectsMaxHistoryCount() {
        // Given: 最大件数（10件）を超えるスコアを追加
        // maxScoreHistoryCount = 10
        for i in 1 ... 15 {
            sut.addScore(makePostureScore(value: i * 10))
        }

        // Then: 最大件数（10件）を超えない
        XCTAssertEqual(sut.scoreHistory.count, 10, "スコア履歴は最大10件")
    }

    // MARK: - smoothedScore Tests

    func testSmoothedScore_calculatesAverageOfHistory() {
        // Given: スコア 60, 80, 100 を追加
        sut.addScore(makePostureScore(value: 60))
        sut.addScore(makePostureScore(value: 80))
        sut.addScore(makePostureScore(value: 100))

        // Then: 平均は (60 + 80 + 100) / 3 = 80
        XCTAssertEqual(sut.smoothedScore, 80, "スムージングスコアは平均値")
    }

    func testSmoothedScore_withSingleScore_returnsScore() {
        // Given
        sut.addScore(makePostureScore(value: 75))

        // Then
        XCTAssertEqual(sut.smoothedScore, 75, "単一スコアの場合はそのまま返す")
    }

    func testSmoothedScore_withEmptyHistory_returnsZero() {
        XCTAssertEqual(sut.smoothedScore, 0, "履歴が空の場合は0")
    }

    // MARK: - clearScoreHistory Tests

    func testClearScoreHistory_removesAllScores() {
        // Given: スコアを追加
        sut.addScore(makePostureScore(value: 80))
        sut.addScore(makePostureScore(value: 90))
        XCTAssertEqual(sut.scoreHistory.count, 2)

        // When
        sut.clearScoreHistory()

        // Then
        XCTAssertTrue(sut.scoreHistory.isEmpty, "履歴がクリアされる")
        XCTAssertEqual(sut.smoothedScore, 0, "スムージングスコアも0になる")
    }

    // MARK: - iconColor Tests

    func testIconColor_whenActive_returnsScoreBasedColor() {
        // Given: 高スコア（緑に近い色）
        sut.addScore(makePostureScore(value: 100))

        // Then: active 状態では色はグレーではない
        XCTAssertNotEqual(sut.iconColor, ColorGradient.gray, "active 状態ではグレーではない")
    }

    func testIconColor_whenPaused_returnsGray() {
        // Given: 初期状態（paused）

        // Then
        XCTAssertEqual(sut.iconColor, ColorGradient.gray, "paused 状態ではグレー")
    }

    // MARK: - updateMonitoringState Tests

    func testUpdateMonitoringState_whenActive_maintainsActiveState() {
        // Given: active 状態
        sut.addScore(makePostureScore(value: 80))
        XCTAssertTrue(sut.monitoringState.isActive)

        // When
        sut.updateMonitoringState()

        // Then: active 状態が維持される
        XCTAssertTrue(sut.monitoringState.isActive, "active 状態は維持される")
    }

    func testUpdateMonitoringState_whenNotActive_updatesFromCameraService() {
        // Given: paused 状態、カメラ権限は authorized
        mockCameraService.authorizationStatus = .authorized

        // When
        sut.updateMonitoringState()

        // Then: カメラサービスの状態に基づいて更新される
        if case .paused = sut.monitoringState {
            // 期待通り（authorized でも初期化中は paused）
        } else if case .disabled = sut.monitoringState {
            XCTFail("authorized の場合は disabled にならない")
        }
    }

    func testUpdateMonitoringState_whenDenied_updatesToDisabled() {
        // Given: paused 状態、カメラ権限は denied
        mockCameraService.authorizationStatus = .denied

        // When
        sut.updateMonitoringState()

        // Then: disabled 状態になる
        if case let .disabled(reason) = sut.monitoringState {
            XCTAssertEqual(reason, .cameraPermissionDenied, "権限拒否の理由が正しい")
        } else {
            XCTFail("denied の場合は disabled 状態になるべき")
        }
    }

    // MARK: - startMonitoring Tests

    func testStartMonitoring_whenAuthorized_startsCapturing() {
        // Given
        mockCameraService.authorizationStatus = .authorized

        // When
        sut.startMonitoring()

        // Then
        XCTAssertTrue(mockCameraService.isCapturing, "キャプチャが開始される")
    }

    func testStartMonitoring_whenNotAuthorized_doesNotStartCapturing() {
        // Given
        mockCameraService.authorizationStatus = .denied

        // When
        sut.startMonitoring()

        // Then
        XCTAssertFalse(mockCameraService.isCapturing, "権限がない場合はキャプチャしない")
    }

    // MARK: - stopMonitoring Tests

    func testStopMonitoring_stopsCapturing() {
        // Given: キャプチャ中
        mockCameraService.authorizationStatus = .authorized
        sut.startMonitoring()
        XCTAssertTrue(mockCameraService.isCapturing)

        // When
        sut.stopMonitoring()

        // Then
        XCTAssertFalse(mockCameraService.isCapturing, "キャプチャが停止される")
    }

    func testStopMonitoring_clearsScoreHistory() {
        // Given: スコアがある状態
        mockCameraService.authorizationStatus = .authorized
        sut.startMonitoring()
        sut.addScore(makePostureScore(value: 80))
        XCTAssertFalse(sut.scoreHistory.isEmpty)

        // When
        sut.stopMonitoring()

        // Then
        XCTAssertTrue(sut.scoreHistory.isEmpty, "スコア履歴がクリアされる")
    }

    func testStopMonitoring_setsStateToPaused() {
        // Given: active 状態
        mockCameraService.authorizationStatus = .authorized
        sut.startMonitoring()
        sut.addScore(makePostureScore(value: 80))
        XCTAssertTrue(sut.monitoringState.isActive)

        // When
        sut.stopMonitoring()

        // Then
        if case .paused = sut.monitoringState {
            // 期待通り
        } else {
            XCTFail("停止後は paused 状態になるべき")
        }
    }
}

// MARK: - MonitoringState Extension

private extension MonitoringState {
    var isActive: Bool {
        if case .active = self { return true }
        return false
    }
}

// MARK: - Mock Classes

/// テスト用の MockCameraService
@MainActor
private final class MockCameraServiceForViewModel: CameraServiceProtocol {
    var authorizationStatus: CameraAuthorizationStatus = .notDetermined
    var isCapturing = false
    weak var frameDelegate: CameraFrameDelegate?
    var availableCameras: [CameraDevice] = []
    var selectedCameraID: String?
    private var cameraAvailable = true

    func requestAuthorization() async -> CameraAuthorizationStatus {
        authorizationStatus
    }

    func checkCameraAvailability() -> Bool {
        cameraAvailable
    }

    func toMonitoringState() -> MonitoringState {
        if !cameraAvailable {
            return .disabled(.noCameraAvailable)
        }
        switch authorizationStatus {
        case .authorized:
            return .paused(.cameraInitializing)
        case .denied:
            return .disabled(.cameraPermissionDenied)
        case .restricted:
            return .disabled(.cameraPermissionRestricted)
        case .notDetermined:
            return .paused(.cameraInitializing)
        }
    }

    func startCapturing() {
        isCapturing = true
    }

    func stopCapturing() {
        isCapturing = false
    }

    func selectCamera(_: String?) {}
}

/// テスト用の MockPostureAnalyzer
private struct MockPostureAnalyzerForViewModel: PostureAnalyzing {
    nonisolated func analyze(sampleBuffer _: CMSampleBuffer) async -> AnalysisResult {
        .noFaceDetected
    }
}

/// テスト用の MockCalibrationStorage
@MainActor
private final class MockCalibrationStorageForViewModel: CalibrationStorageProtocol {
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
