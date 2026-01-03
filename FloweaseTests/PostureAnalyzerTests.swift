@preconcurrency import AVFoundation
import XCTest
@testable import Flowease

// MARK: - PostureAnalyzerTests

/// PostureAnalyzer のユニットテスト
///
/// Vision フレームワークを使用した姿勢分析のテスト。
/// 実際の Vision 処理はモック化し、BodyPose への変換ロジックを検証する。
///
/// テスト対象:
/// - VNHumanBodyPoseObservation → BodyPose 変換
/// - 人物未検出時の挙動
/// - 低信頼度検出時の挙動
/// - 必須関節欠落時の挙動
@MainActor
final class PostureAnalyzerTests: XCTestCase {
    // MARK: - System Under Test

    private var sut: PostureAnalyzer!

    override func setUp() {
        super.setUp()
        sut = PostureAnalyzer()
    }

    override func tearDown() {
        sut = nil
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

    /// 完全な検出結果を持つ BodyPose を作成
    private func makeCompleteBodyPose(timestamp: Date = Date()) -> BodyPose {
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

    /// 低信頼度の検出結果を持つ BodyPose を作成
    private func makeLowConfidenceBodyPose(timestamp: Date = Date()) -> BodyPose {
        BodyPose(
            nose: makeJoint(x: 0.5, y: 0.8, confidence: 0.3),
            neck: makeJoint(x: 0.5, y: 0.6, confidence: 0.2),
            leftShoulder: makeJoint(x: 0.35, y: 0.4, confidence: 0.4),
            rightShoulder: makeJoint(x: 0.65, y: 0.4, confidence: 0.3),
            leftEar: nil,
            rightEar: nil,
            root: nil,
            timestamp: timestamp
        )
    }

    /// 部分的な検出結果を持つ BodyPose を作成（首のみ欠落）
    private func makePartialBodyPose_missingNeck(timestamp: Date = Date()) -> BodyPose {
        BodyPose(
            nose: makeJoint(x: 0.5, y: 0.8),
            neck: nil,
            leftShoulder: makeJoint(x: 0.35, y: 0.4),
            rightShoulder: makeJoint(x: 0.65, y: 0.4),
            leftEar: makeJoint(x: 0.45, y: 0.82),
            rightEar: makeJoint(x: 0.55, y: 0.82),
            root: makeJoint(x: 0.5, y: 0.2),
            timestamp: timestamp
        )
    }

    /// 部分的な検出結果を持つ BodyPose を作成（肩が欠落）
    private func makePartialBodyPose_missingShoulders(timestamp: Date = Date()) -> BodyPose {
        BodyPose(
            nose: makeJoint(x: 0.5, y: 0.8),
            neck: makeJoint(x: 0.5, y: 0.6),
            leftShoulder: nil,
            rightShoulder: nil,
            leftEar: makeJoint(x: 0.45, y: 0.82),
            rightEar: makeJoint(x: 0.55, y: 0.82),
            root: makeJoint(x: 0.5, y: 0.2),
            timestamp: timestamp
        )
    }

    // MARK: - BodyPose Validation Tests

    func testBodyPose_completeDetection_isValid() {
        // Given: 完全な検出結果
        let pose = makeCompleteBodyPose()

        // When / Then: isValid は true
        XCTAssertTrue(pose.isValid, "必須関節が全て高信頼度で検出されている場合は有効")
    }

    func testBodyPose_lowConfidenceDetection_isNotValid() {
        // Given: 低信頼度の検出結果
        let pose = makeLowConfidenceBodyPose()

        // When / Then: isValid は false
        XCTAssertFalse(pose.isValid, "信頼度が 0.5 未満の場合は無効")
    }

    func testBodyPose_missingNeck_isNotValid() {
        // Given: 首が欠落した検出結果
        let pose = makePartialBodyPose_missingNeck()

        // When / Then: isValid は false
        XCTAssertFalse(pose.isValid, "首が検出されていない場合は無効")
    }

    func testBodyPose_missingShoulders_isNotValid() {
        // Given: 肩が欠落した検出結果
        let pose = makePartialBodyPose_missingShoulders()

        // When / Then: isValid は false
        XCTAssertFalse(pose.isValid, "肩が検出されていない場合は無効")
    }

    // MARK: - PostureAnalyzer Protocol Tests

    func testAnalyzer_conformsToPostureAnalyzing() {
        // Given: PostureAnalyzer インスタンス

        // When / Then: PostureAnalyzing プロトコルに準拠しているか確認
        XCTAssertTrue(sut is PostureAnalyzing, "PostureAnalyzer は PostureAnalyzing に準拠すべき")
    }

    // MARK: - Minimum Confidence Tests

    func testBodyPose_neckConfidenceAtThreshold_isValid() {
        // Given: 首の信頼度がちょうど 0.5 の検出結果
        let pose = BodyPose(
            nose: makeJoint(x: 0.5, y: 0.8),
            neck: makeJoint(x: 0.5, y: 0.6, confidence: 0.5),
            leftShoulder: makeJoint(x: 0.35, y: 0.4, confidence: 0.5),
            rightShoulder: makeJoint(x: 0.65, y: 0.4, confidence: 0.5),
            leftEar: nil,
            rightEar: nil,
            root: nil,
            timestamp: Date()
        )

        // When / Then: isValid は true（境界値）
        XCTAssertTrue(pose.isValid, "信頼度がちょうど 0.5 の場合は有効")
    }

    func testBodyPose_neckConfidenceBelowThreshold_isNotValid() {
        // Given: 首の信頼度が 0.5 未満の検出結果
        let pose = BodyPose(
            nose: makeJoint(x: 0.5, y: 0.8),
            neck: makeJoint(x: 0.5, y: 0.6, confidence: 0.49),
            leftShoulder: makeJoint(x: 0.35, y: 0.4),
            rightShoulder: makeJoint(x: 0.65, y: 0.4),
            leftEar: nil,
            rightEar: nil,
            root: nil,
            timestamp: Date()
        )

        // When / Then: isValid は false
        XCTAssertFalse(pose.isValid, "信頼度が 0.5 未満の場合は無効")
    }

    // MARK: - JointPosition Clamping Tests

    func testJointPosition_coordinatesAreClamped() {
        // Given: 範囲外の座標
        let outOfRangeJoint = JointPosition(x: 1.5, y: -0.5, confidence: 2.0)

        // When / Then: 値はクランプされる
        XCTAssertEqual(outOfRangeJoint.x, 1.0, "x は 1.0 にクランプされるべき")
        XCTAssertEqual(outOfRangeJoint.y, 0.0, "y は 0.0 にクランプされるべき")
        XCTAssertEqual(outOfRangeJoint.confidence, 1.0, "confidence は 1.0 にクランプされるべき")
    }

    func testJointPosition_nanValuesAreHandled() {
        // Given: NaN 値
        let nanJoint = JointPosition(x: .nan, y: .nan, confidence: .nan)

        // When / Then: NaN は 0 に変換される
        XCTAssertEqual(nanJoint.x, 0.0, "x の NaN は 0 に変換されるべき")
        XCTAssertEqual(nanJoint.y, 0.0, "y の NaN は 0 に変換されるべき")
        XCTAssertEqual(nanJoint.confidence, 0.0, "confidence の NaN は 0 に変換されるべき")
    }

    // MARK: - BodyPose Equatable Tests

    func testBodyPose_equatable_sameValues() {
        // Given: 同じ値を持つ2つの BodyPose
        let timestamp = Date()
        let pose1 = BodyPose(
            nose: makeJoint(x: 0.5, y: 0.8),
            neck: makeJoint(x: 0.5, y: 0.6),
            leftShoulder: makeJoint(x: 0.35, y: 0.4),
            rightShoulder: makeJoint(x: 0.65, y: 0.4),
            leftEar: nil,
            rightEar: nil,
            root: nil,
            timestamp: timestamp
        )
        let pose2 = BodyPose(
            nose: makeJoint(x: 0.5, y: 0.8),
            neck: makeJoint(x: 0.5, y: 0.6),
            leftShoulder: makeJoint(x: 0.35, y: 0.4),
            rightShoulder: makeJoint(x: 0.65, y: 0.4),
            leftEar: nil,
            rightEar: nil,
            root: nil,
            timestamp: timestamp
        )

        // When / Then: 等しい
        XCTAssertEqual(pose1, pose2)
    }

    func testBodyPose_equatable_differentTimestamp() {
        // Given: 異なるタイムスタンプを持つ2つの BodyPose
        let pose1 = makeCompleteBodyPose(timestamp: Date(timeIntervalSince1970: 1000))
        let pose2 = makeCompleteBodyPose(timestamp: Date(timeIntervalSince1970: 2000))

        // When / Then: 等しくない
        XCTAssertNotEqual(pose1, pose2)
    }

    // MARK: - Optional Joint Tests

    func testBodyPose_optionalJointsAreOptional() {
        // Given: 最小限の関節のみを持つ BodyPose
        let minimalPose = BodyPose(
            nose: nil,
            neck: makeJoint(x: 0.5, y: 0.6),
            leftShoulder: makeJoint(x: 0.35, y: 0.4),
            rightShoulder: makeJoint(x: 0.65, y: 0.4),
            leftEar: nil,
            rightEar: nil,
            root: nil,
            timestamp: Date()
        )

        // When / Then: 必須関節のみで isValid は true
        XCTAssertTrue(minimalPose.isValid, "首と両肩があれば有効")
        XCTAssertNil(minimalPose.nose, "鼻はオプショナル")
        XCTAssertNil(minimalPose.leftEar, "左耳はオプショナル")
        XCTAssertNil(minimalPose.rightEar, "右耳はオプショナル")
        XCTAssertNil(minimalPose.root, "ルートはオプショナル")
    }

    // MARK: - Sendable Tests

    func testBodyPose_isSendable() {
        // Given: BodyPose のタイプ

        // When / Then: Sendable に準拠していることを確認
        // コンパイル時にチェックされるため、このテストはコンパイルが通れば成功
        let pose = makeCompleteBodyPose()
        Task {
            // Sendable でなければコンパイルエラーになる
            let _ = pose
        }
    }

    func testJointPosition_isSendable() {
        // Given: JointPosition のタイプ

        // When / Then: Sendable に準拠していることを確認
        let joint = makeJoint()
        Task {
            let _ = joint
        }
    }
}

// MARK: - Mock PostureAnalyzer

/// テスト用のモック PostureAnalyzer
final class MockPostureAnalyzer: PostureAnalyzing {
    /// 返却する AnalysisResult
    @MainActor var resultToReturn: AnalysisResult = .noFaceDetected

    /// analyze が呼ばれた回数
    @MainActor private(set) var analyzeCallCount = 0

    nonisolated func analyze(sampleBuffer _: CMSampleBuffer) async -> AnalysisResult {
        await MainActor.run {
            analyzeCallCount += 1
            return resultToReturn
        }
    }
}
