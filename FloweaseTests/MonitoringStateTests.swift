import XCTest
@testable import Flowease

// MARK: - MonitoringStateTests

/// MonitoringState の状態遷移テスト
///
/// data-model.md で定義された状態遷移を検証する。
@MainActor
final class MonitoringStateTests: XCTestCase {
    // MARK: - Test Helpers

    /// テスト用の PostureScore を作成
    private func makePostureScore(
        value: Int = 75,
        timestamp: Date = Date(),
        confidence: Double = 0.9
    ) -> PostureScore {
        let breakdown = ScoreBreakdown(
            verticalPosition: 80,
            sizeChange: 70,
            tilt: 75
        )
        return PostureScore(
            value: value,
            timestamp: timestamp,
            breakdown: breakdown,
            confidence: confidence
        )
    }

    // MARK: - MonitoringState Basic State Tests

    func testActiveStateWithPostureScore() {
        // Given
        let score = makePostureScore(value: 85)

        // When
        let state = MonitoringState.active(score)

        // Then
        if case let .active(resultScore) = state {
            XCTAssertEqual(resultScore.value, 85)
        } else {
            XCTFail("Expected active state")
        }
    }

    func testPausedStateWithReason() {
        // Given / When
        let state = MonitoringState.paused(.cameraInitializing)

        // Then
        if case let .paused(reason) = state {
            XCTAssertEqual(reason, .cameraInitializing)
        } else {
            XCTFail("Expected paused state")
        }
    }

    func testDisabledStateWithReason() {
        // Given / When
        let state = MonitoringState.disabled(.cameraPermissionDenied)

        // Then
        if case let .disabled(reason) = state {
            XCTAssertEqual(reason, .cameraPermissionDenied)
        } else {
            XCTFail("Expected disabled state")
        }
    }

    // MARK: - MonitoringState Equatable Tests

    func testEquality_sameActiveStates() {
        // Given
        let timestamp = Date()
        let score1 = makePostureScore(value: 75, timestamp: timestamp)
        let score2 = makePostureScore(value: 75, timestamp: timestamp)

        // When
        let state1 = MonitoringState.active(score1)
        let state2 = MonitoringState.active(score2)

        // Then
        XCTAssertEqual(state1, state2)
    }

    func testEquality_differentActiveStates() {
        // Given
        let score1 = makePostureScore(value: 75)
        let score2 = makePostureScore(value: 50)

        // When
        let state1 = MonitoringState.active(score1)
        let state2 = MonitoringState.active(score2)

        // Then
        XCTAssertNotEqual(state1, state2)
    }

    func testEquality_samePausedStates() {
        // Given / When
        let state1 = MonitoringState.paused(.noFaceDetected)
        let state2 = MonitoringState.paused(.noFaceDetected)

        // Then
        XCTAssertEqual(state1, state2)
    }

    func testEquality_differentPausedStates() {
        // Given / When
        let state1 = MonitoringState.paused(.cameraInitializing)
        let state2 = MonitoringState.paused(.cameraInUse)

        // Then
        XCTAssertNotEqual(state1, state2)
    }

    func testEquality_sameDisabledStates() {
        // Given / When
        let state1 = MonitoringState.disabled(.noCameraAvailable)
        let state2 = MonitoringState.disabled(.noCameraAvailable)

        // Then
        XCTAssertEqual(state1, state2)
    }

    func testEquality_differentDisabledStates() {
        // Given / When
        let state1 = MonitoringState.disabled(.cameraPermissionDenied)
        let state2 = MonitoringState.disabled(.cameraPermissionRestricted)

        // Then
        XCTAssertNotEqual(state1, state2)
    }

    func testInequality_differentStateTypes() {
        // Given
        let score = makePostureScore()

        // When
        let activeState = MonitoringState.active(score)
        let pausedState = MonitoringState.paused(.noFaceDetected)
        let disabledState = MonitoringState.disabled(.cameraPermissionDenied)

        // Then
        XCTAssertNotEqual(activeState, pausedState)
        XCTAssertNotEqual(pausedState, disabledState)
        XCTAssertNotEqual(activeState, disabledState)
    }

    // MARK: - PauseReason Description Tests
    //
    // 注: description/actionHint は String(localized:) を使用しローカライズされるため、
    // ロケールに依存しない検証として「空でないこと」のみを確認します。

    func testPauseReason_cameraInitializing_description() {
        let reason = PauseReason.cameraInitializing
        XCTAssertFalse(reason.description.isEmpty)
    }

    func testPauseReason_noFaceDetected_description() {
        let reason = PauseReason.noFaceDetected
        XCTAssertFalse(reason.description.isEmpty)
    }

    func testPauseReason_cameraInUse_description() {
        let reason = PauseReason.cameraInUse
        XCTAssertFalse(reason.description.isEmpty)
    }

    // MARK: - DisableReason Description Tests

    func testDisableReason_cameraPermissionDenied_description() {
        let reason = DisableReason.cameraPermissionDenied
        XCTAssertFalse(reason.description.isEmpty)
    }

    func testDisableReason_cameraPermissionDenied_actionHint() {
        let reason = DisableReason.cameraPermissionDenied
        XCTAssertFalse(reason.actionHint.isEmpty)
    }

    func testDisableReason_cameraPermissionRestricted_description() {
        let reason = DisableReason.cameraPermissionRestricted
        XCTAssertFalse(reason.description.isEmpty)
    }

    func testDisableReason_cameraPermissionRestricted_actionHint() {
        let reason = DisableReason.cameraPermissionRestricted
        XCTAssertFalse(reason.actionHint.isEmpty)
    }

    func testDisableReason_noCameraAvailable_description() {
        let reason = DisableReason.noCameraAvailable
        XCTAssertFalse(reason.description.isEmpty)
    }

    func testDisableReason_noCameraAvailable_actionHint() {
        let reason = DisableReason.noCameraAvailable
        XCTAssertFalse(reason.actionHint.isEmpty)
    }

    // MARK: - State Transition Scenario Tests

    /// 状態遷移: paused (.cameraInitializing) → active
    /// シナリオ: カメラ準備完了後、人物を検出してスコア算出開始
    func testStateTransition_pausedToActive() {
        // Given: 初期状態はカメラ準備中
        var currentState: MonitoringState = .paused(.cameraInitializing)

        // When: カメラ準備完了・人物検出・スコア算出
        let score = makePostureScore(value: 80)
        currentState = .active(score)

        // Then: active 状態に遷移
        if case let .active(resultScore) = currentState {
            XCTAssertEqual(resultScore.value, 80)
        } else {
            XCTFail("Expected active state after transition")
        }
    }

    /// 状態遷移: active → paused (.noFaceDetected)
    /// シナリオ: 監視中にユーザーがカメラから離れた
    func testStateTransition_activeToPaused() {
        // Given: 初期状態は監視中
        let score = makePostureScore(value: 75)
        var currentState: MonitoringState = .active(score)

        // When: 顔が検出されなくなった
        currentState = .paused(.noFaceDetected)

        // Then: paused 状態に遷移
        if case let .paused(reason) = currentState {
            XCTAssertEqual(reason, .noFaceDetected)
        } else {
            XCTFail("Expected paused state after transition")
        }
    }

    /// 状態遷移: disabled (.cameraPermissionDenied) → paused (.cameraInitializing)
    /// シナリオ: ユーザーがシステム設定でカメラ権限を許可した
    func testStateTransition_disabledToPaused() {
        // Given: 初期状態はカメラ権限拒否
        var currentState: MonitoringState = .disabled(.cameraPermissionDenied)

        // When: ユーザーが権限を付与（アプリは再初期化を開始）
        currentState = .paused(.cameraInitializing)

        // Then: paused 状態に遷移
        if case let .paused(reason) = currentState {
            XCTAssertEqual(reason, .cameraInitializing)
        } else {
            XCTFail("Expected paused state after transition")
        }
    }

    /// 状態遷移: active → paused (.cameraInUse)
    /// シナリオ: 他のアプリがカメラを使用し始めた
    func testStateTransition_activeToPaused_cameraInUse() {
        // Given: 初期状態は監視中
        let score = makePostureScore(value: 70)
        var currentState: MonitoringState = .active(score)

        // When: 他のアプリがカメラを占有
        currentState = .paused(.cameraInUse)

        // Then: paused 状態に遷移
        if case let .paused(reason) = currentState {
            XCTAssertEqual(reason, .cameraInUse)
        } else {
            XCTFail("Expected paused state after transition")
        }
    }

    /// 状態遷移: paused (.noFaceDetected) → active
    /// シナリオ: ユーザーがカメラ前に戻ってきた
    func testStateTransition_pausedNoFaceToActive() {
        // Given: 初期状態は顔未検出
        var currentState: MonitoringState = .paused(.noFaceDetected)

        // When: 顔を再検出
        let score = makePostureScore(value: 65)
        currentState = .active(score)

        // Then: active 状態に遷移
        if case let .active(resultScore) = currentState {
            XCTAssertEqual(resultScore.value, 65)
        } else {
            XCTFail("Expected active state after transition")
        }
    }

    /// 状態遷移: paused (.cameraInUse) → active
    /// シナリオ: 他のアプリがカメラを解放した
    func testStateTransition_pausedCameraInUseToActive() {
        // Given: 初期状態はカメラ使用中
        var currentState: MonitoringState = .paused(.cameraInUse)

        // When: カメラが利用可能になり、人物を検出
        let score = makePostureScore(value: 90)
        currentState = .active(score)

        // Then: active 状態に遷移
        if case let .active(resultScore) = currentState {
            XCTAssertEqual(resultScore.value, 90)
        } else {
            XCTFail("Expected active state after transition")
        }
    }

    // MARK: - T020: PauseReason.selectedCameraDisconnected Tests

    /// PauseReason.selectedCameraDisconnected のハンドリングテスト
    ///
    /// T020 [US2]: Test PauseReason.selectedCameraDisconnected handling
    ///
    /// これらのテストは selectedCameraDisconnected ケースの状態遷移を検証

    /// PauseReason.selectedCameraDisconnected の description を確認
    func testPauseReason_selectedCameraDisconnected_description() {
        let reason = PauseReason.selectedCameraDisconnected
        XCTAssertFalse(reason.description.isEmpty)
    }

    /// 状態遷移: active → paused (.selectedCameraDisconnected)
    /// シナリオ: 監視中に選択されたカメラが切断された
    func testStateTransition_activeToPaused_selectedCameraDisconnected() {
        // Given: 初期状態は監視中
        let score = makePostureScore(value: 80)
        var currentState: MonitoringState = .active(score)

        // When: 選択されたカメラが切断された
        currentState = .paused(.selectedCameraDisconnected)

        // Then: paused 状態に遷移
        if case let .paused(reason) = currentState {
            XCTAssertEqual(reason, .selectedCameraDisconnected)
        } else {
            XCTFail("Expected paused state after camera disconnection")
        }
    }

    /// 状態遷移: paused (.selectedCameraDisconnected) → active
    /// シナリオ: 選択されたカメラが再接続され、顔を検出した
    func testStateTransition_pausedSelectedCameraDisconnectedToActive() {
        // Given: 初期状態はカメラ切断
        var currentState: MonitoringState = .paused(.selectedCameraDisconnected)

        // When: カメラが再接続され、顔を検出
        let score = makePostureScore(value: 75)
        currentState = .active(score)

        // Then: active 状態に遷移
        if case let .active(resultScore) = currentState {
            XCTAssertEqual(resultScore.value, 75)
        } else {
            XCTFail("Expected active state after camera reconnection")
        }
    }

    /// 状態遷移: paused (.selectedCameraDisconnected) → paused (.cameraInitializing)
    /// シナリオ: 選択されたカメラが再接続され、初期化開始
    func testStateTransition_pausedDisconnectedToPausedInitializing() {
        // Given: 初期状態はカメラ切断
        var currentState: MonitoringState = .paused(.selectedCameraDisconnected)

        // When: カメラが再接続され、初期化開始
        currentState = .paused(.cameraInitializing)

        // Then: cameraInitializing 状態に遷移
        if case let .paused(reason) = currentState {
            XCTAssertEqual(reason, .cameraInitializing)
        } else {
            XCTFail("Expected paused(.cameraInitializing) state")
        }
    }

    /// PauseReason.selectedCameraDisconnected の Equatable 準拠を確認
    func testPauseReason_selectedCameraDisconnected_equatable() {
        // Given
        let reason1 = PauseReason.selectedCameraDisconnected
        let reason2 = PauseReason.selectedCameraDisconnected
        let reason3 = PauseReason.noFaceDetected

        // Then
        XCTAssertEqual(reason1, reason2, "Same reasons should be equal")
        XCTAssertNotEqual(reason1, reason3, "Different reasons should not be equal")
    }

    /// MonitoringState.paused(.selectedCameraDisconnected) の Equatable 準拠を確認
    func testMonitoringState_pausedSelectedCameraDisconnected_equatable() {
        // Given
        let state1 = MonitoringState.paused(.selectedCameraDisconnected)
        let state2 = MonitoringState.paused(.selectedCameraDisconnected)
        let state3 = MonitoringState.paused(.cameraInUse)

        // Then
        XCTAssertEqual(state1, state2, "Same states should be equal")
        XCTAssertNotEqual(state1, state3, "Different states should not be equal")
    }

    /// PauseReason.lowDetectionQuality の description を確認
    func testPauseReason_lowDetectionQuality_description() {
        let reason = PauseReason.lowDetectionQuality
        XCTAssertFalse(reason.description.isEmpty)
    }
}
