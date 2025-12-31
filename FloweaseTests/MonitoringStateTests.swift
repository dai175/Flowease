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
            headTilt: 80,
            shoulderBalance: 70,
            forwardLean: 75,
            symmetry: 75
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
        let state1 = MonitoringState.paused(.noPersonDetected)
        let state2 = MonitoringState.paused(.noPersonDetected)

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
        let pausedState = MonitoringState.paused(.noPersonDetected)
        let disabledState = MonitoringState.disabled(.cameraPermissionDenied)

        // Then
        XCTAssertNotEqual(activeState, pausedState)
        XCTAssertNotEqual(pausedState, disabledState)
        XCTAssertNotEqual(activeState, disabledState)
    }

    // MARK: - PauseReason Description Tests

    func testPauseReason_cameraInitializing_description() {
        // Given / When
        let reason = PauseReason.cameraInitializing

        // Then
        XCTAssertEqual(reason.description, "カメラを準備中...")
    }

    func testPauseReason_noPersonDetected_description() {
        // Given / When
        let reason = PauseReason.noPersonDetected

        // Then
        XCTAssertEqual(reason.description, "人物が検出されません")
    }

    func testPauseReason_cameraInUse_description() {
        // Given / When
        let reason = PauseReason.cameraInUse

        // Then
        XCTAssertEqual(reason.description, "カメラが他のアプリで使用中です")
    }

    // MARK: - DisableReason Description Tests

    func testDisableReason_cameraPermissionDenied_description() {
        // Given / When
        let reason = DisableReason.cameraPermissionDenied

        // Then
        XCTAssertEqual(reason.description, "カメラへのアクセスが拒否されています")
    }

    func testDisableReason_cameraPermissionDenied_actionHint() {
        // Given / When
        let reason = DisableReason.cameraPermissionDenied

        // Then
        XCTAssertEqual(
            reason.actionHint,
            "システム設定 > プライバシーとセキュリティ > カメラ から許可してください"
        )
    }

    func testDisableReason_cameraPermissionRestricted_description() {
        // Given / When
        let reason = DisableReason.cameraPermissionRestricted

        // Then
        XCTAssertEqual(reason.description, "カメラへのアクセスが制限されています")
    }

    func testDisableReason_cameraPermissionRestricted_actionHint() {
        // Given / When
        let reason = DisableReason.cameraPermissionRestricted

        // Then
        XCTAssertEqual(
            reason.actionHint,
            "システム管理者に連絡してカメラの使用許可を依頼してください"
        )
    }

    func testDisableReason_noCameraAvailable_description() {
        // Given / When
        let reason = DisableReason.noCameraAvailable

        // Then
        XCTAssertEqual(reason.description, "カメラが見つかりません")
    }

    func testDisableReason_noCameraAvailable_actionHint() {
        // Given / When
        let reason = DisableReason.noCameraAvailable

        // Then
        XCTAssertEqual(reason.actionHint, "外部カメラを接続してください")
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

    /// 状態遷移: active → paused (.noPersonDetected)
    /// シナリオ: 監視中にユーザーがカメラから離れた
    func testStateTransition_activeToPaused() {
        // Given: 初期状態は監視中
        let score = makePostureScore(value: 75)
        var currentState: MonitoringState = .active(score)

        // When: 人物が検出されなくなった
        currentState = .paused(.noPersonDetected)

        // Then: paused 状態に遷移
        if case let .paused(reason) = currentState {
            XCTAssertEqual(reason, .noPersonDetected)
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

    /// 状態遷移: paused (.noPersonDetected) → active
    /// シナリオ: ユーザーがカメラ前に戻ってきた
    func testStateTransition_pausedNoPersonToActive() {
        // Given: 初期状態は人物未検出
        var currentState: MonitoringState = .paused(.noPersonDetected)

        // When: 人物を再検出
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
}
