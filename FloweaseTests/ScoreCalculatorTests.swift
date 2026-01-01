import XCTest
@testable import Flowease

// MARK: - ScoreCalculatorTests

/// ScoreCalculator のユニットテスト
///
/// 姿勢データ (BodyPose) から姿勢スコア (PostureScore) への変換ロジックを検証する。
/// research.md で定義されたスコア算出アルゴリズムに基づく。
///
/// スコア構成要素:
/// - 頭部傾斜 (30%): 首-鼻の垂直からの角度偏差
/// - 肩の水平バランス (25%): 左右肩のY座標差
/// - 前傾姿勢 (30%): 鼻のX座標と首の前後関係
/// - 左右対称性 (15%): 左右耳・肩の対称性
@MainActor
final class ScoreCalculatorTests: XCTestCase {
    // MARK: - System Under Test

    private var sut: ScoreCalculator!

    override func setUp() {
        super.setUp()
        sut = ScoreCalculator()
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

    /// 理想的な姿勢（良い姿勢）の BodyPose を作成
    ///
    /// - 首は中央 (0.5, 0.6)
    /// - 鼻は首の真上 (0.5, 0.8)
    /// - 肩は水平 (左: 0.35, 0.4、右: 0.65, 0.4)
    private func makeGoodPosture(timestamp: Date = Date()) -> BodyPose {
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

    /// 頭部が傾いた姿勢の BodyPose を作成
    private func makeTiltedHeadPosture(timestamp: Date = Date()) -> BodyPose {
        BodyPose(
            nose: makeJoint(x: 0.6, y: 0.75), // 右に傾いている
            neck: makeJoint(x: 0.5, y: 0.6),
            leftShoulder: makeJoint(x: 0.35, y: 0.4),
            rightShoulder: makeJoint(x: 0.65, y: 0.4),
            leftEar: makeJoint(x: 0.55, y: 0.8),
            rightEar: makeJoint(x: 0.65, y: 0.78),
            root: makeJoint(x: 0.5, y: 0.2),
            timestamp: timestamp
        )
    }

    /// 肩が傾いた姿勢の BodyPose を作成
    private func makeUnevenShouldersPosture(timestamp: Date = Date()) -> BodyPose {
        BodyPose(
            nose: makeJoint(x: 0.5, y: 0.8),
            neck: makeJoint(x: 0.5, y: 0.6),
            leftShoulder: makeJoint(x: 0.35, y: 0.45), // 左肩が上がっている
            rightShoulder: makeJoint(x: 0.65, y: 0.35), // 右肩が下がっている
            leftEar: makeJoint(x: 0.45, y: 0.82),
            rightEar: makeJoint(x: 0.55, y: 0.82),
            root: makeJoint(x: 0.5, y: 0.2),
            timestamp: timestamp
        )
    }

    /// 前傾姿勢の BodyPose を作成
    private func makeForwardLeanPosture(timestamp: Date = Date()) -> BodyPose {
        BodyPose(
            nose: makeJoint(x: 0.4, y: 0.75), // 前に出ている（X座標が小さい = 前）
            neck: makeJoint(x: 0.5, y: 0.6),
            leftShoulder: makeJoint(x: 0.35, y: 0.4),
            rightShoulder: makeJoint(x: 0.65, y: 0.4),
            leftEar: makeJoint(x: 0.35, y: 0.78),
            rightEar: makeJoint(x: 0.45, y: 0.78),
            root: makeJoint(x: 0.5, y: 0.2),
            timestamp: timestamp
        )
    }

    /// 非対称な姿勢の BodyPose を作成
    private func makeAsymmetricPosture(timestamp: Date = Date()) -> BodyPose {
        BodyPose(
            nose: makeJoint(x: 0.5, y: 0.8),
            neck: makeJoint(x: 0.5, y: 0.6),
            leftShoulder: makeJoint(x: 0.3, y: 0.4), // 左肩が遠い
            rightShoulder: makeJoint(x: 0.6, y: 0.4), // 右肩が近い
            leftEar: makeJoint(x: 0.4, y: 0.82),
            rightEar: makeJoint(x: 0.58, y: 0.8),
            root: makeJoint(x: 0.5, y: 0.2),
            timestamp: timestamp
        )
    }

    /// 悪い姿勢（複数の問題がある）の BodyPose を作成
    private func makeBadPosture(timestamp: Date = Date()) -> BodyPose {
        BodyPose(
            nose: makeJoint(x: 0.35, y: 0.7), // 前傾 + 左に傾き
            neck: makeJoint(x: 0.5, y: 0.55),
            leftShoulder: makeJoint(x: 0.3, y: 0.5), // 左肩が上
            rightShoulder: makeJoint(x: 0.7, y: 0.35), // 右肩が下
            leftEar: makeJoint(x: 0.3, y: 0.75),
            rightEar: makeJoint(x: 0.45, y: 0.72),
            root: makeJoint(x: 0.5, y: 0.2),
            timestamp: timestamp
        )
    }

    /// 無効な BodyPose を作成（必須関節の信頼度が低い）
    private func makeInvalidPosture(timestamp: Date = Date()) -> BodyPose {
        BodyPose(
            nose: makeJoint(x: 0.5, y: 0.8),
            neck: makeJoint(x: 0.5, y: 0.6, confidence: 0.3), // 低信頼度
            leftShoulder: makeJoint(x: 0.35, y: 0.4),
            rightShoulder: makeJoint(x: 0.65, y: 0.4),
            leftEar: nil,
            rightEar: nil,
            root: nil,
            timestamp: timestamp
        )
    }

    /// 必須関節が欠落した BodyPose を作成
    private func makeMissingJointsPosture(timestamp: Date = Date()) -> BodyPose {
        BodyPose(
            nose: makeJoint(x: 0.5, y: 0.8),
            neck: nil, // 首が検出されていない
            leftShoulder: makeJoint(x: 0.35, y: 0.4),
            rightShoulder: nil, // 右肩が検出されていない
            leftEar: nil,
            rightEar: nil,
            root: nil,
            timestamp: timestamp
        )
    }

    // MARK: - Good Posture Tests

    func testCalculate_goodPosture_returnsHighScore() {
        // Given: 理想的な姿勢
        let pose = makeGoodPosture()

        // When: スコアを計算
        let result = sut.calculate(from: pose)

        // Then: 高いスコア (90以上) を返す
        XCTAssertNotNil(result, "良い姿勢ではスコアが返されるべき")
        if let score = result {
            XCTAssertGreaterThanOrEqual(score.value, 90, "良い姿勢のスコアは90以上であるべき")
            XCTAssertLessThanOrEqual(score.value, 100, "スコアは100を超えない")
        }
    }

    func testCalculate_goodPosture_hasHighBreakdownScores() {
        // Given: 理想的な姿勢
        let pose = makeGoodPosture()

        // When: スコアを計算
        let result = sut.calculate(from: pose)

        // Then: 各構成要素も高スコア
        XCTAssertNotNil(result)
        if let score = result {
            XCTAssertGreaterThanOrEqual(score.breakdown.headTilt, 80, "頭部傾斜スコアは80以上")
            XCTAssertGreaterThanOrEqual(score.breakdown.shoulderBalance, 80, "肩バランススコアは80以上")
            XCTAssertGreaterThanOrEqual(score.breakdown.forwardLean, 80, "前傾スコアは80以上")
            XCTAssertGreaterThanOrEqual(score.breakdown.symmetry, 80, "対称性スコアは80以上")
        }
    }

    // MARK: - Head Tilt Tests

    func testCalculate_tiltedHead_reducesHeadTiltScore() {
        // Given: 頭部が傾いた姿勢
        let pose = makeTiltedHeadPosture()

        // When: スコアを計算
        let result = sut.calculate(from: pose)

        // Then: 頭部傾斜スコアが低下
        XCTAssertNotNil(result)
        if let score = result {
            XCTAssertLessThan(score.breakdown.headTilt, 80, "頭部が傾いていると headTilt が減少")
        }
    }

    func testCalculate_tiltedHead_reducesOverallScore() {
        // Given: 良い姿勢と頭部傾斜姿勢
        let goodPose = makeGoodPosture()
        let tiltedPose = makeTiltedHeadPosture()

        // When: スコアを計算
        let goodResult = sut.calculate(from: goodPose)
        let tiltedResult = sut.calculate(from: tiltedPose)

        // Then: 頭部傾斜姿勢の方がスコアが低い
        XCTAssertNotNil(goodResult)
        XCTAssertNotNil(tiltedResult)
        if let goodScore = goodResult, let tiltedScore = tiltedResult {
            XCTAssertLessThan(tiltedScore.value, goodScore.value, "頭部傾斜で全体スコアが低下")
        }
    }

    // MARK: - Shoulder Balance Tests

    func testCalculate_unevenShoulders_reducesShoulderBalanceScore() {
        // Given: 肩が傾いた姿勢
        let pose = makeUnevenShouldersPosture()

        // When: スコアを計算
        let result = sut.calculate(from: pose)

        // Then: 肩バランススコアが低下
        XCTAssertNotNil(result)
        if let score = result {
            XCTAssertLessThan(score.breakdown.shoulderBalance, 80, "肩が傾いていると shoulderBalance が減少")
        }
    }

    func testCalculate_unevenShoulders_reducesOverallScore() {
        // Given: 良い姿勢と肩傾斜姿勢
        let goodPose = makeGoodPosture()
        let unevenPose = makeUnevenShouldersPosture()

        // When: スコアを計算
        let goodResult = sut.calculate(from: goodPose)
        let unevenResult = sut.calculate(from: unevenPose)

        // Then: 肩傾斜姿勢の方がスコアが低い
        XCTAssertNotNil(goodResult)
        XCTAssertNotNil(unevenResult)
        if let goodScore = goodResult, let unevenScore = unevenResult {
            XCTAssertLessThan(unevenScore.value, goodScore.value, "肩傾斜で全体スコアが低下")
        }
    }

    // MARK: - Forward Lean Tests

    func testCalculate_forwardLean_reducesForwardLeanScore() {
        // Given: 前傾姿勢
        let pose = makeForwardLeanPosture()

        // When: スコアを計算
        let result = sut.calculate(from: pose)

        // Then: 前傾スコアが低下
        XCTAssertNotNil(result)
        if let score = result {
            XCTAssertLessThan(score.breakdown.forwardLean, 80, "前傾姿勢だと forwardLean が減少")
        }
    }

    func testCalculate_forwardLean_reducesOverallScore() {
        // Given: 良い姿勢と前傾姿勢
        let goodPose = makeGoodPosture()
        let leanPose = makeForwardLeanPosture()

        // When: スコアを計算
        let goodResult = sut.calculate(from: goodPose)
        let leanResult = sut.calculate(from: leanPose)

        // Then: 前傾姿勢の方がスコアが低い
        XCTAssertNotNil(goodResult)
        XCTAssertNotNil(leanResult)
        if let goodScore = goodResult, let leanScore = leanResult {
            XCTAssertLessThan(leanScore.value, goodScore.value, "前傾姿勢で全体スコアが低下")
        }
    }

    // MARK: - Symmetry Tests

    func testCalculate_asymmetricPosture_reducesSymmetryScore() {
        // Given: 非対称な姿勢
        let pose = makeAsymmetricPosture()

        // When: スコアを計算
        let result = sut.calculate(from: pose)

        // Then: 対称性スコアが低下
        XCTAssertNotNil(result)
        if let score = result {
            XCTAssertLessThan(score.breakdown.symmetry, 90, "非対称だと symmetry が減少")
        }
    }

    // MARK: - Bad Posture Tests

    func testCalculate_badPosture_returnsLowScore() {
        // Given: 悪い姿勢（複数の問題）
        let pose = makeBadPosture()

        // When: スコアを計算
        let result = sut.calculate(from: pose)

        // Then: 低いスコア (50未満) を返す
        XCTAssertNotNil(result)
        if let score = result {
            XCTAssertLessThan(score.value, 50, "悪い姿勢のスコアは50未満であるべき")
        }
    }

    // MARK: - Invalid Pose Tests

    func testCalculate_invalidPose_returnsNil() {
        // Given: 無効な姿勢（isValid = false）
        let pose = makeInvalidPosture()

        // Verify precondition
        XCTAssertFalse(pose.isValid, "テストデータは無効な姿勢であるべき")

        // When: スコアを計算
        let result = sut.calculate(from: pose)

        // Then: nil を返す
        XCTAssertNil(result, "無効な姿勢ではスコアが nil であるべき")
    }

    func testCalculate_missingJoints_returnsNil() {
        // Given: 必須関節が欠落した姿勢
        let pose = makeMissingJointsPosture()

        // Verify precondition
        XCTAssertFalse(pose.isValid, "テストデータは無効な姿勢であるべき")

        // When: スコアを計算
        let result = sut.calculate(from: pose)

        // Then: nil を返す
        XCTAssertNil(result, "必須関節が欠落していればスコアは nil")
    }

    // MARK: - Score Bounds Tests

    func testCalculate_scoreIsClampedToValidRange() {
        // Given: 良い姿勢と悪い姿勢
        let goodPose = makeGoodPosture()
        let badPose = makeBadPosture()

        // When: スコアを計算
        let goodResult = sut.calculate(from: goodPose)
        let badResult = sut.calculate(from: badPose)

        // Then: スコアは 0-100 の範囲内
        if let score = goodResult {
            XCTAssertGreaterThanOrEqual(score.value, 0, "スコアは0以上")
            XCTAssertLessThanOrEqual(score.value, 100, "スコアは100以下")
        }
        if let score = badResult {
            XCTAssertGreaterThanOrEqual(score.value, 0, "スコアは0以上")
            XCTAssertLessThanOrEqual(score.value, 100, "スコアは100以下")
        }
    }

    func testCalculate_breakdownScoresAreClampedToValidRange() {
        // Given: 任意の姿勢
        let pose = makeBadPosture()

        // When: スコアを計算
        let result = sut.calculate(from: pose)

        // Then: 各構成スコアは 0-100 の範囲内
        if let score = result {
            XCTAssertGreaterThanOrEqual(score.breakdown.headTilt, 0)
            XCTAssertLessThanOrEqual(score.breakdown.headTilt, 100)
            XCTAssertGreaterThanOrEqual(score.breakdown.shoulderBalance, 0)
            XCTAssertLessThanOrEqual(score.breakdown.shoulderBalance, 100)
            XCTAssertGreaterThanOrEqual(score.breakdown.forwardLean, 0)
            XCTAssertLessThanOrEqual(score.breakdown.forwardLean, 100)
            XCTAssertGreaterThanOrEqual(score.breakdown.symmetry, 0)
            XCTAssertLessThanOrEqual(score.breakdown.symmetry, 100)
        }
    }

    // MARK: - Timestamp Tests

    func testCalculate_preservesTimestamp() {
        // Given: 特定のタイムスタンプを持つ姿勢
        let timestamp = Date(timeIntervalSince1970: 1_000_000)
        let pose = makeGoodPosture(timestamp: timestamp)

        // When: スコアを計算
        let result = sut.calculate(from: pose)

        // Then: タイムスタンプが保持される
        XCTAssertNotNil(result)
        if let score = result {
            XCTAssertEqual(score.timestamp, timestamp, "タイムスタンプが保持されるべき")
        }
    }

    // MARK: - Confidence Tests

    func testCalculate_setsAppropriateConfidence() {
        // Given: 高信頼度の関節を持つ姿勢
        let pose = makeGoodPosture()

        // When: スコアを計算
        let result = sut.calculate(from: pose)

        // Then: 信頼度が設定されている
        XCTAssertNotNil(result)
        if let score = result {
            XCTAssertGreaterThan(score.confidence, 0.0, "信頼度は0より大きいべき")
            XCTAssertLessThanOrEqual(score.confidence, 1.0, "信頼度は1.0以下であるべき")
        }
    }

    // MARK: - Calibration Support Tests (T012)

    // MARK: - Reference Posture Property Tests

    func testReferencePosture_initiallyNil() {
        // Given: 新しい ScoreCalculator

        // Then: referencePosture は nil
        XCTAssertNil(sut.referencePosture, "初期状態では referencePosture は nil であるべき")
    }

    func testSetReferencePosture_storesValue() {
        // Given: 有効な ReferencePosture
        let posture = makeReferencePosture()

        // When: referencePosture を設定
        sut.setReferencePosture(posture)

        // Then: 値が保存される
        XCTAssertNotNil(sut.referencePosture, "referencePosture が設定されるべき")
        XCTAssertEqual(sut.referencePosture?.frameCount, posture.frameCount)
    }

    func testSetReferencePosture_nil_clearsValue() {
        // Given: referencePosture が設定されている
        let posture = makeReferencePosture()
        sut.setReferencePosture(posture)
        XCTAssertNotNil(sut.referencePosture)

        // When: nil を設定
        sut.setReferencePosture(nil)

        // Then: 値がクリアされる
        XCTAssertNil(sut.referencePosture, "nil 設定後は referencePosture が nil になるべき")
    }

    // MARK: - isCalibrated Property Tests

    func testIsCalibrated_returnsFalse_whenNoReferencePosture() {
        // Given: referencePosture が nil

        // Then: isCalibrated は false
        XCTAssertFalse(sut.isCalibrated, "referencePosture がなければ isCalibrated は false")
    }

    func testIsCalibrated_returnsTrue_whenReferencePostureSet() {
        // Given: referencePosture が設定されている
        let posture = makeReferencePosture()
        sut.setReferencePosture(posture)

        // Then: isCalibrated は true
        XCTAssertTrue(sut.isCalibrated, "referencePosture があれば isCalibrated は true")
    }

    // MARK: - Calibration Mode Score Calculation Tests

    func testCalculate_withReferencePosture_usesCalibratedScoring() {
        // Given: 基準姿勢と同じ姿勢（逸脱なし）
        let referencePosture = makeReferencePosture()
        sut.setReferencePosture(referencePosture)
        let pose = makeGoodPosture()

        // When: スコアを計算
        let result = sut.calculate(from: pose)

        // Then: 高スコアを返す（基準姿勢とほぼ同じなので）
        XCTAssertNotNil(result)
        if let score = result {
            XCTAssertGreaterThanOrEqual(score.value, 85, "基準姿勢に近いとき高スコアであるべき")
        }
    }

    func testCalculate_withReferencePosture_detectsDeviationFromBaseline() {
        // Given: 基準姿勢を設定
        let referencePosture = makeReferencePosture()
        sut.setReferencePosture(referencePosture)

        // 基準姿勢と異なる姿勢（頭が傾いている）
        let deviatedPose = makeTiltedHeadPosture()

        // When: スコアを計算
        let result = sut.calculate(from: deviatedPose)

        // Then: 基準姿勢からの逸脱でスコアが下がる
        XCTAssertNotNil(result)
        if let score = result {
            XCTAssertLessThan(score.value, 90, "基準姿勢から逸脱するとスコアが下がるべき")
        }
    }

    func testCalculate_withReferencePosture_headTiltDeviationAffectsScore() {
        // Given: 頭が真っ直ぐな基準姿勢
        let referencePosture = makeReferencePosture()
        sut.setReferencePosture(referencePosture)

        // 頭が傾いた姿勢
        let tiltedPose = makeTiltedHeadPosture()

        // When: スコアを計算
        let result = sut.calculate(from: tiltedPose)

        // Then: headTilt スコアが下がる
        XCTAssertNotNil(result)
        if let score = result {
            XCTAssertLessThan(score.breakdown.headTilt, 80, "頭傾きで headTilt スコアが下がるべき")
        }
    }

    func testCalculate_withReferencePosture_shoulderBalanceDeviationAffectsScore() {
        // Given: 肩が水平な基準姿勢
        let referencePosture = makeReferencePosture()
        sut.setReferencePosture(referencePosture)

        // 肩が傾いた姿勢
        let unevenPose = makeUnevenShouldersPosture()

        // When: スコアを計算
        let result = sut.calculate(from: unevenPose)

        // Then: shoulderBalance スコアが下がる
        XCTAssertNotNil(result)
        if let score = result {
            XCTAssertLessThan(score.breakdown.shoulderBalance, 80, "肩傾きで shoulderBalance スコアが下がるべき")
        }
    }

    func testCalculate_withReferencePosture_forwardLeanDeviationAffectsScore() {
        // Given: 前傾していない基準姿勢
        let referencePosture = makeReferencePosture()
        sut.setReferencePosture(referencePosture)

        // 前傾姿勢
        let leanPose = makeForwardLeanPosture()

        // When: スコアを計算
        let result = sut.calculate(from: leanPose)

        // Then: forwardLean スコアが下がる
        XCTAssertNotNil(result)
        if let score = result {
            XCTAssertLessThan(score.breakdown.forwardLean, 80, "前傾で forwardLean スコアが下がるべき")
        }
    }

    // MARK: - Backward Compatibility Tests

    func testCalculate_withoutReferencePosture_usesFixedThresholds() {
        // Given: referencePosture が設定されていない（固定しきい値モード）
        XCTAssertNil(sut.referencePosture)
        let pose = makeGoodPosture()

        // When: スコアを計算
        let result = sut.calculate(from: pose)

        // Then: 既存の固定しきい値でスコアが計算される（高スコア）
        XCTAssertNotNil(result)
        if let score = result {
            XCTAssertGreaterThanOrEqual(score.value, 90, "良い姿勢は固定しきい値モードでも高スコア")
        }
    }

    func testCalculate_backwardCompatibility_existingTestsStillPass() {
        // Given: referencePosture なし（デフォルト状態）
        // 既存のテストケースと同じ条件

        // When: 良い姿勢のスコアを計算
        let goodPose = makeGoodPosture()
        let goodResult = sut.calculate(from: goodPose)

        // When: 悪い姿勢のスコアを計算
        let badPose = makeBadPosture()
        let badResult = sut.calculate(from: badPose)

        // Then: 既存のテストと同じ期待値
        XCTAssertNotNil(goodResult)
        XCTAssertNotNil(badResult)
        if let goodScore = goodResult, let badScore = badResult {
            XCTAssertGreaterThanOrEqual(goodScore.value, 90, "良い姿勢は90点以上")
            XCTAssertLessThan(badScore.value, 50, "悪い姿勢は50点未満")
        }
    }

    // MARK: - Deviation Calculation Tests

    func testCalculate_relativeDeviationFromBaseline() {
        // Given: 特定の基準姿勢（若干頭が傾いている状態を基準として設定）
        let tiltedBaseline = makeReferencePostureWithTilt()
        sut.setReferencePosture(tiltedBaseline)

        // 基準姿勢と同じ程度に傾いた姿勢
        let pose = makeTiltedHeadPosture()

        // When: スコアを計算
        let result = sut.calculate(from: pose)

        // Then: 基準姿勢と同程度なので高スコア
        // （絶対的には傾いているが、相対的には基準に近い）
        XCTAssertNotNil(result)
        if let score = result {
            // 基準姿勢からの相対的な逸脱が小さければ高スコア
            XCTAssertGreaterThanOrEqual(
                score.value,
                70,
                "基準姿勢と同程度の傾きならスコアは高めであるべき"
            )
        }
    }

    // MARK: - Test Helpers for Calibration Tests

    /// 標準的な ReferencePosture を作成
    private func makeReferencePosture() -> ReferencePosture {
        ReferencePosture(
            neck: ReferenceJointPosition(x: 0.5, y: 0.6, confidence: 0.9),
            leftShoulder: ReferenceJointPosition(x: 0.35, y: 0.4, confidence: 0.9),
            rightShoulder: ReferenceJointPosition(x: 0.65, y: 0.4, confidence: 0.9),
            nose: ReferenceJointPosition(x: 0.5, y: 0.8, confidence: 0.9),
            leftEar: ReferenceJointPosition(x: 0.45, y: 0.82, confidence: 0.9),
            rightEar: ReferenceJointPosition(x: 0.55, y: 0.82, confidence: 0.9),
            calibratedAt: Date(),
            frameCount: 90,
            averageConfidence: 0.9,
            baselineMetrics: BaselineMetrics(
                headTiltDeviation: 0.0,     // 頭は真っ直ぐ
                shoulderBalance: 0.0,        // 肩は水平
                forwardLean: 0.2,            // 少し後傾（neck.y - nose.y）
                symmetry: 0.0                // 完全対称
            )
        )
    }

    /// 頭が傾いた状態を基準とした ReferencePosture を作成
    private func makeReferencePostureWithTilt() -> ReferencePosture {
        ReferencePosture(
            neck: ReferenceJointPosition(x: 0.5, y: 0.6, confidence: 0.9),
            leftShoulder: ReferenceJointPosition(x: 0.35, y: 0.4, confidence: 0.9),
            rightShoulder: ReferenceJointPosition(x: 0.65, y: 0.4, confidence: 0.9),
            nose: ReferenceJointPosition(x: 0.6, y: 0.75, confidence: 0.9), // 右に傾いている
            leftEar: ReferenceJointPosition(x: 0.55, y: 0.8, confidence: 0.9),
            rightEar: ReferenceJointPosition(x: 0.65, y: 0.78, confidence: 0.9),
            calibratedAt: Date(),
            frameCount: 90,
            averageConfidence: 0.9,
            baselineMetrics: BaselineMetrics(
                headTiltDeviation: 0.1,      // 頭が傾いている状態を基準
                shoulderBalance: 0.0,
                forwardLean: 0.15,
                symmetry: 0.02
            )
        )
    }
}
