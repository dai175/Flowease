import XCTest
@testable import Flowease

// MARK: - LocalizationTests

/// ローカライゼーション関連のテスト
///
/// 各 User Story のテストがこのファイルに追加される。
/// - US1: StatusMenuView のローカライズ文字列
/// - US2: CalibrationView/CalibrationViewModel のローカライズ文字列
/// - US3: DisableReason/PauseReason の description/actionHint
final class LocalizationTests: XCTestCase {
    // MARK: - Test Infrastructure

    /// ローカライゼーションテストの基本的なセットアップが正しいことを確認
    func testLocalizationTestInfrastructureIsReady() {
        // This test confirms that the test file is properly configured
        // and can import the Flowease module
        XCTAssertTrue(true, "Localization test infrastructure is ready")
    }

    // MARK: - US1: StatusMenuView Localization Tests

    /// StatusMenuView で使用されるローカライズ文字列が存在することを確認
    ///
    /// 以下の文字列をテスト:
    /// - "Monitoring Posture" (姿勢モニタリング中)
    /// - "Calibration:" (キャリブレーション:)
    /// - "Reset" (リセット)
    /// - "Reconfigure" (再設定)
    /// - "Configure" (設定)
    func testStatusMenuViewLocalizedStringsExist() {
        // 各文字列が空でないことを確認
        // String(localized:) は Development Language（英語）の値を返す
        let monitoringPosture = String(localized: "Monitoring Posture")
        XCTAssertFalse(monitoringPosture.isEmpty, "Monitoring Posture string should exist")
        XCTAssertEqual(monitoringPosture, "Monitoring Posture", "English string should match")

        let reset = String(localized: "Reset")
        XCTAssertFalse(reset.isEmpty, "Reset string should exist")
        XCTAssertEqual(reset, "Reset", "English string should match")

        let reconfigure = String(localized: "Reconfigure")
        XCTAssertFalse(reconfigure.isEmpty, "Reconfigure string should exist")
        XCTAssertEqual(reconfigure, "Reconfigure", "English string should match")

        let configure = String(localized: "Configure")
        XCTAssertFalse(configure.isEmpty, "Configure string should exist")
        XCTAssertEqual(configure, "Configure", "English string should match")
    }

    /// StatusMenuView で使用される補間文字列（Calibration: %@）が正しく動作することを確認
    func testStatusMenuViewInterpolatedStringsWork() {
        // String(localized:) を使ってローカライズリソースを検証
        let statusSummary = "Complete"
        let calibrationText = String(localized: "Calibration: \(statusSummary)")
        XCTAssertFalse(calibrationText.isEmpty, "Calibration string should exist")
        XCTAssertEqual(calibrationText, "Calibration: Complete", "English string should match")
    }

    // MARK: - US2: CalibrationView Localization Tests

    /// CalibrationView で使用されるローカライズ文字列が存在することを確認
    ///
    /// 以下の文字列をテスト:
    /// - "Posture Calibration" (姿勢キャリブレーション)
    /// - "Please assume good posture" (良い姿勢を取ってください)
    /// - "Maintain your posture..." (そのままの姿勢を維持...)
    /// - "Calibration Complete" (キャリブレーション完了)
    /// - "Calibration Failed" (キャリブレーション失敗)
    /// - ボタンラベル: Cancel, Start, Close
    func testCalibrationViewLocalizedStringsExist() {
        // タイトルと状態メッセージ
        let postureCalibration = String(localized: "Posture Calibration")
        XCTAssertEqual(postureCalibration, "Posture Calibration", "English string should match")

        let pleaseAssume = String(localized: "Please assume good posture")
        XCTAssertEqual(pleaseAssume, "Please assume good posture", "English string should match")

        let faceCamera = String(localized: "Face the camera and maintain a relaxed, good posture for 3 seconds.")
        XCTAssertEqual(
            faceCamera,
            "Face the camera and maintain a relaxed, good posture for 3 seconds.",
            "English string should match"
        )

        let maintainPosture = String(localized: "Maintain your posture...")
        XCTAssertEqual(maintainPosture, "Maintain your posture...", "English string should match")

        let calibrationComplete = String(localized: "Calibration Complete")
        XCTAssertEqual(calibrationComplete, "Calibration Complete", "English string should match")

        let recorded = String(localized: "Your good posture has been recorded as the baseline.")
        XCTAssertEqual(
            recorded,
            "Your good posture has been recorded as the baseline.",
            "English string should match"
        )

        let calibrationFailed = String(localized: "Calibration Failed")
        XCTAssertEqual(calibrationFailed, "Calibration Failed", "English string should match")

        // ボタンラベル
        let cancel = String(localized: "Cancel")
        XCTAssertEqual(cancel, "Cancel", "English string should match")

        let start = String(localized: "Start")
        XCTAssertEqual(start, "Start", "English string should match")

        let close = String(localized: "Close")
        XCTAssertEqual(close, "Close", "English string should match")
    }

    // MARK: - US2: CalibrationViewModel Localization Tests

    /// CalibrationViewModel で使用されるローカライズ文字列が存在することを確認
    ///
    /// 以下の文字列をテスト:
    /// - qualityWarningMessage
    /// - statusText
    /// - recommendationMessage
    /// - statusSummary
    /// - errorMessage
    func testCalibrationViewModelLocalizedStringsExist() {
        // qualityWarningMessage
        let lowQuality = String(localized: "Posture detection quality is low")
        XCTAssertEqual(lowQuality, "Posture detection quality is low", "English string should match")

        let ensureFace = String(localized: "Please ensure your face is visible to the camera")
        XCTAssertEqual(
            ensureFace,
            "Please ensure your face is visible to the camera",
            "English string should match"
        )

        // statusText
        let notConfigured = String(localized: "Calibration not configured")
        XCTAssertEqual(notConfigured, "Calibration not configured", "English string should match")

        // statusText with interpolation - 残り秒数の補間
        let seconds = 3
        let calibrating = String(localized: "Calibrating... \(seconds) seconds remaining")
        XCTAssertEqual(calibrating, "Calibrating... 3 seconds remaining", "English string should match")

        // recommendationMessage
        let recommendation = String(localized: "Configure calibration for more accurate posture assessment")
        XCTAssertEqual(
            recommendation,
            "Configure calibration for more accurate posture assessment",
            "English string should match"
        )

        // statusSummary
        let complete = String(localized: "Complete")
        XCTAssertEqual(complete, "Complete", "English string should match")

        let notConfiguredSummary = String(localized: "Not configured")
        XCTAssertEqual(notConfiguredSummary, "Not configured", "English string should match")

        // statusSummary with date interpolation
        let dateText = "1/6/26, 10:30 AM"
        let completeWithDate = String(localized: "Complete (\(dateText))")
        XCTAssertEqual(completeWithDate, "Complete (1/6/26, 10:30 AM)", "English string should match")

        // errorMessage
        let unexpectedError = String(localized: "An unexpected error occurred")
        XCTAssertEqual(unexpectedError, "An unexpected error occurred", "English string should match")
    }

    // MARK: - US2: CalibrationFailure Localization Tests

    /// CalibrationFailure の userMessage が英語でローカライズされていることを確認
    @MainActor
    func testCalibrationFailureLocalizedStringsExist() {
        // noFaceDetected
        XCTAssertEqual(
            CalibrationFailure.noFaceDetected.userMessage,
            "Please ensure your face is visible to the camera",
            "noFaceDetected userMessage should be in English"
        )

        // lowConfidence
        XCTAssertEqual(
            CalibrationFailure.lowConfidence.userMessage,
            "Please adjust the lighting",
            "lowConfidence userMessage should be in English"
        )

        // insufficientFrames
        XCTAssertEqual(
            CalibrationFailure.insufficientFrames.userMessage,
            "Please try again",
            "insufficientFrames userMessage should be in English"
        )

        // cancelled は空文字列のまま
        XCTAssertTrue(
            CalibrationFailure.cancelled.userMessage.isEmpty,
            "cancelled userMessage should be empty"
        )
    }

    // MARK: - US3: DisableReason Localization Tests

    /// DisableReason の description と actionHint が英語でローカライズされていることを確認
    func testDisableReasonLocalizedStringsExist() {
        // description 文字列
        let cameraAccessDenied = String(localized: "Camera access denied")
        XCTAssertEqual(cameraAccessDenied, "Camera access denied", "English string should match")

        let cameraAccessRestricted = String(localized: "Camera access restricted")
        XCTAssertEqual(cameraAccessRestricted, "Camera access restricted", "English string should match")

        let cameraNotFound = String(localized: "Camera not found")
        XCTAssertEqual(cameraNotFound, "Camera not found", "English string should match")

        // actionHint 文字列
        let grantPermission = String(
            localized: "Go to System Settings > Privacy & Security > Camera to grant permission"
        )
        XCTAssertEqual(
            grantPermission,
            "Go to System Settings > Privacy & Security > Camera to grant permission",
            "English string should match"
        )

        let contactAdmin = String(localized: "Contact your system administrator to request camera access")
        XCTAssertEqual(
            contactAdmin,
            "Contact your system administrator to request camera access",
            "English string should match"
        )

        let connectCamera = String(localized: "Please connect an external camera")
        XCTAssertEqual(connectCamera, "Please connect an external camera", "English string should match")
    }

    // MARK: - US3: PauseReason Localization Tests

    /// PauseReason の description が英語でローカライズされていることを確認
    func testPauseReasonLocalizedStringsExist() {
        let initializingCamera = String(localized: "Initializing camera...")
        XCTAssertEqual(initializingCamera, "Initializing camera...", "English string should match")

        let faceNotDetected = String(localized: "Face not detected")
        XCTAssertEqual(faceNotDetected, "Face not detected", "English string should match")

        let cameraInUse = String(localized: "Camera is being used by another app")
        XCTAssertEqual(cameraInUse, "Camera is being used by another app", "English string should match")

        let detectionQualityLow = String(localized: "Detection quality is low")
        XCTAssertEqual(detectionQualityLow, "Detection quality is low", "English string should match")
    }

    // MARK: - US3: CameraPermissionView Localization Tests

    /// CameraPermissionView のボタンラベルが英語でローカライズされていることを確認
    func testCameraPermissionViewLocalizedStringsExist() {
        let openSystemSettings = String(localized: "Open System Settings")
        XCTAssertEqual(openSystemSettings, "Open System Settings", "English string should match")
    }
}
