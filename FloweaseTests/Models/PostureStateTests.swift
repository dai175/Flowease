//
//  PostureStateTests.swift
//  FloweaseTests
//
//  Created by Daisuke Ooba on 2025/12/29.
//

import XCTest
@testable import Flowease

/// PostureState モデルのテスト
final class PostureStateTests: XCTestCase {
    // MARK: - PostureLevel Tests

    func testPostureLevelDisplayName() {
        XCTAssertEqual(PostureLevel.good.displayName, "良好")
        XCTAssertEqual(PostureLevel.warning.displayName, "注意")
        XCTAssertEqual(PostureLevel.bad.displayName, "要改善")
        XCTAssertEqual(PostureLevel.unknown.displayName, "未検出")
    }

    func testPostureLevelIconName() {
        XCTAssertEqual(PostureLevel.good.iconName, "figure.stand")
        XCTAssertEqual(PostureLevel.warning.iconName, "exclamationmark.triangle.fill")
        XCTAssertEqual(PostureLevel.bad.iconName, "xmark.circle.fill")
        XCTAssertEqual(PostureLevel.unknown.iconName, "questionmark.circle")
    }

    func testPostureLevelRawValue() {
        XCTAssertEqual(PostureLevel.good.rawValue, "good")
        XCTAssertEqual(PostureLevel.warning.rawValue, "warning")
        XCTAssertEqual(PostureLevel.bad.rawValue, "bad")
        XCTAssertEqual(PostureLevel.unknown.rawValue, "unknown")
    }

    // MARK: - PostureState Initialization Tests

    func testPostureStateInitWithExplicitLevel() {
        let state = PostureState(
            level: .good,
            score: 0.9,
            forwardLeanAngle: 5.0,
            neckTiltAngle: 10.0,
            badPostureDuration: 0,
            isFaceDetected: true
        )

        XCTAssertEqual(state.level, .good)
        XCTAssertEqual(state.score, 0.9)
        XCTAssertEqual(state.forwardLeanAngle, 5.0)
        XCTAssertEqual(state.neckTiltAngle, 10.0)
        XCTAssertEqual(state.badPostureDuration, 0)
        XCTAssertTrue(state.isFaceDetected)
    }

    func testPostureStateInitWithAutoLevelCalculation() {
        // Good posture (score >= 0.8)
        let goodState = PostureState(
            score: 0.85,
            forwardLeanAngle: 5.0,
            neckTiltAngle: 10.0
        )
        XCTAssertEqual(goodState.level, .good)

        // Warning posture (0.6 <= score < 0.8)
        let warningState = PostureState(
            score: 0.65,
            forwardLeanAngle: 12.0,
            neckTiltAngle: 15.0
        )
        XCTAssertEqual(warningState.level, .warning)

        // Bad posture (score < 0.6)
        let badState = PostureState(
            score: 0.3,
            forwardLeanAngle: 25.0,
            neckTiltAngle: 30.0
        )
        XCTAssertEqual(badState.level, .bad)
    }

    // MARK: - Score Clamping Tests

    func testScoreClampingUpperBound() {
        let state = PostureState(
            level: .good,
            score: 1.5, // Above max
            forwardLeanAngle: 5.0,
            neckTiltAngle: 10.0
        )
        XCTAssertEqual(state.score, 1.0, "Score should be clamped to 1.0")
    }

    func testScoreClampingLowerBound() {
        let state = PostureState(
            level: .bad,
            score: -0.5, // Below min
            forwardLeanAngle: 30.0,
            neckTiltAngle: 35.0
        )
        XCTAssertEqual(state.score, 0.0, "Score should be clamped to 0.0")
    }

    // MARK: - Angle Clamping Tests

    func testForwardLeanAngleClamping() {
        let stateAbove = PostureState(
            level: .bad,
            score: 0.2,
            forwardLeanAngle: 100.0, // Above max
            neckTiltAngle: 20.0
        )
        XCTAssertEqual(stateAbove.forwardLeanAngle, 90.0, "Forward lean angle should be clamped to 90.0")

        let stateBelow = PostureState(
            level: .good,
            score: 0.9,
            forwardLeanAngle: -10.0, // Below min
            neckTiltAngle: 10.0
        )
        XCTAssertEqual(stateBelow.forwardLeanAngle, 0.0, "Forward lean angle should be clamped to 0.0")
    }

    func testNeckTiltAngleClamping() {
        let stateAbove = PostureState(
            level: .bad,
            score: 0.2,
            forwardLeanAngle: 20.0,
            neckTiltAngle: 100.0 // Above max
        )
        XCTAssertEqual(stateAbove.neckTiltAngle, 90.0, "Neck tilt angle should be clamped to 90.0")

        let stateBelow = PostureState(
            level: .good,
            score: 0.9,
            forwardLeanAngle: 5.0,
            neckTiltAngle: -10.0 // Below min
        )
        XCTAssertEqual(stateBelow.neckTiltAngle, 0.0, "Neck tilt angle should be clamped to 0.0")
    }

    // MARK: - BadPostureDuration Clamping Tests

    func testBadPostureDurationClamping() {
        let state = PostureState(
            level: .bad,
            score: 0.3,
            forwardLeanAngle: 25.0,
            neckTiltAngle: 30.0,
            badPostureDuration: -5.0 // Negative value
        )
        XCTAssertEqual(state.badPostureDuration, 0.0, "Bad posture duration should be clamped to 0.0")
    }

    // MARK: - Static Values Tests

    func testNotDetectedState() {
        let state = PostureState.notDetected

        XCTAssertEqual(state.level, .unknown)
        XCTAssertEqual(state.score, 0.0)
        XCTAssertEqual(state.forwardLeanAngle, 0.0)
        XCTAssertEqual(state.neckTiltAngle, 0.0)
        XCTAssertFalse(state.isFaceDetected)
    }

    // MARK: - Threshold Tests

    func testScoreThresholdBoundaries() {
        // Exactly at good threshold
        let exactlyGood = PostureState(
            score: Constants.PostureDetection.ScoreThreshold.good,
            forwardLeanAngle: 5.0,
            neckTiltAngle: 10.0
        )
        XCTAssertEqual(exactlyGood.level, .good)

        // Just below good threshold
        let justBelowGood = PostureState(
            score: Constants.PostureDetection.ScoreThreshold.good - 0.01,
            forwardLeanAngle: 8.0,
            neckTiltAngle: 12.0
        )
        XCTAssertEqual(justBelowGood.level, .warning)

        // Exactly at warning threshold
        let exactlyWarning = PostureState(
            score: Constants.PostureDetection.ScoreThreshold.warning,
            forwardLeanAngle: 12.0,
            neckTiltAngle: 18.0
        )
        XCTAssertEqual(exactlyWarning.level, .warning)

        // Just below warning threshold
        let justBelowWarning = PostureState(
            score: Constants.PostureDetection.ScoreThreshold.warning - 0.01,
            forwardLeanAngle: 20.0,
            neckTiltAngle: 25.0
        )
        XCTAssertEqual(justBelowWarning.level, .bad)
    }
}
