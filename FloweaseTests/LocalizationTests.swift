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
}
