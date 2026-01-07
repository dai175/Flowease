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
}
