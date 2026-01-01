// CalibrationService.swift
// Flowease
//
// キャリブレーションの実行と管理
//
// T013: CalibrationServiceProtocolとCalibrationServiceを作成
// T014: CalibrationErrorを作成

import Foundation
import OSLog

// MARK: - CalibrationError

/// キャリブレーション処理で発生するエラー
enum CalibrationError: Error, Equatable, Sendable {
    /// 既にキャリブレーション実行中
    case alreadyInProgress

    /// 人物が検出されなかった
    case noPersonDetected

    /// 信頼度が低い状態が続いた
    case lowConfidence

    /// 十分なフレームが収集できなかった
    case insufficientFrames
}

// MARK: - CalibrationServiceProtocol

/// キャリブレーションサービスのプロトコル
///
/// キャリブレーションの開始・キャンセル・リセット・フレーム処理を定義する。
/// テスト時にはモック実装に差し替え可能。
@MainActor
protocol CalibrationServiceProtocol: AnyObject {
    /// 現在のキャリブレーション状態
    var state: CalibrationState { get }

    /// 現在の基準姿勢（完了時のみ有効）
    var referencePosture: ReferencePosture? { get }

    /// キャリブレーションを開始
    /// - Throws: CalibrationError.alreadyInProgress（既に実行中の場合）
    func startCalibration() async throws

    /// キャリブレーションをキャンセル
    /// 実行中でない場合は何もしない
    func cancelCalibration()

    /// キャリブレーションをリセット（基準姿勢を削除）
    func resetCalibration()

    /// フレームを処理してキャリブレーションデータを収集
    /// - Parameter pose: 検出された姿勢データ
    func processFrame(_ pose: BodyPose)
}

// MARK: - CalibrationService

/// キャリブレーションサービスの実装
///
/// ユーザーの「良い姿勢」を基準として記録し、永続化する。
/// 3秒間（約90フレーム）の複数フレームを平均化して基準姿勢を生成。
@MainActor
final class CalibrationService: CalibrationServiceProtocol {
    // MARK: - Properties

    /// 現在のキャリブレーション状態
    private(set) var state: CalibrationState

    /// 永続化ストレージ
    private let storage: CalibrationStorageProtocol

    /// ロガー
    private let logger = Logger(subsystem: "cc.focuswave.Flowease", category: "CalibrationService")

    /// 信頼度閾値（0.7以上で有効フレーム）
    private let confidenceThreshold: Double = 0.7

    // MARK: - Calibration Data Collection

    /// 収集中のフレームデータ（位置の累積値）
    private var accumulatedPositions: AccumulatedPositions?

    /// 収集中の進捗情報
    private var currentProgress: CalibrationProgress?

    // MARK: - Computed Properties

    /// 現在の基準姿勢
    var referencePosture: ReferencePosture? {
        storage.loadReferencePosture()
    }

    // MARK: - Initializer

    /// イニシャライザ
    /// - Parameter storage: 永続化ストレージ
    init(storage: CalibrationStorageProtocol) {
        self.storage = storage

        // 初期状態はストレージの内容から導出
        if storage.loadReferencePosture() != nil {
            state = .completed
        } else {
            state = .notCalibrated
        }

        logger.debug("CalibrationService 初期化完了: state=\(self.state.statusDescription)")
    }

    // MARK: - CalibrationServiceProtocol

    func startCalibration() async throws {
        // 既に実行中の場合はエラー
        if state.isInProgress {
            logger.warning("キャリブレーション開始失敗: 既に実行中")
            throw CalibrationError.alreadyInProgress
        }

        // 進捗情報を初期化
        let progress = CalibrationProgress()
        currentProgress = progress
        accumulatedPositions = AccumulatedPositions()

        // 状態を更新
        state = .inProgress(progress)
        logger.info("キャリブレーション開始")
    }

    func cancelCalibration() {
        // 実行中でなければ何もしない
        guard state.isInProgress else {
            return
        }

        // キャンセル状態に移行
        state = .failed(.cancelled)
        currentProgress = nil
        accumulatedPositions = nil
        logger.info("キャリブレーションをキャンセルしました")
    }

    func resetCalibration() {
        // 実行中ならキャンセル
        if state.isInProgress {
            currentProgress = nil
            accumulatedPositions = nil
        }

        // ストレージから削除
        storage.deleteReferencePosture()

        // 状態を未キャリブレーションに
        state = .notCalibrated
        logger.info("キャリブレーションをリセットしました")
    }

    func processFrame(_ pose: BodyPose) {
        // 実行中でなければ無視
        guard state.isInProgress,
              var progress = currentProgress,
              var accumulated = accumulatedPositions
        else {
            return
        }

        // フレームの信頼度をチェック
        let isHighConfidence = isFrameHighConfidence(pose)

        // 進捗を更新
        progress.addFrame(isHighConfidence: isHighConfidence)

        // 高信頼度フレームなら位置データを累積
        if isHighConfidence {
            accumulated.add(pose)
        }

        // 失敗判定
        if progress.shouldFail {
            state = .failed(.lowConfidence)
            currentProgress = nil
            accumulatedPositions = nil
            logger.warning("キャリブレーション失敗: 低信頼度が連続")
            return
        }

        // 完了判定
        if progress.isComplete {
            completeCalibration(accumulated: accumulated, progress: progress)
            return
        }

        // 状態を更新
        currentProgress = progress
        accumulatedPositions = accumulated
        state = .inProgress(progress)
    }

    // MARK: - Private Methods

    /// フレームが高信頼度かどうかを判定
    private func isFrameHighConfidence(_ pose: BodyPose) -> Bool {
        // 必須関節が検出されているか
        guard let neck = pose.neck,
              let leftShoulder = pose.leftShoulder,
              let rightShoulder = pose.rightShoulder
        else {
            return false
        }

        // 必須関節の信頼度が閾値以上か
        let requiredConfidences = [neck.confidence, leftShoulder.confidence, rightShoulder.confidence]
        return requiredConfidences.allSatisfy { $0 >= confidenceThreshold }
    }

    /// キャリブレーションを完了
    private func completeCalibration(accumulated: AccumulatedPositions, progress: CalibrationProgress) {
        // フレーム数が不足していれば失敗
        guard accumulated.frameCount >= ReferencePosture.minimumFrameCount else {
            state = .failed(.insufficientFrames)
            currentProgress = nil
            accumulatedPositions = nil
            logger.warning("キャリブレーション失敗: フレーム数不足 (\(accumulated.frameCount) < \(ReferencePosture.minimumFrameCount))")
            return
        }

        // 平均位置を計算
        let referencePosture = accumulated.createReferencePosture()

        // 信頼度チェック
        guard referencePosture.isValid else {
            state = .failed(.lowConfidence)
            currentProgress = nil
            accumulatedPositions = nil
            logger.warning("キャリブレーション失敗: 平均信頼度が不足")
            return
        }

        // ストレージに保存
        storage.saveReferencePosture(referencePosture)

        // 状態を完了に
        state = .completed
        currentProgress = nil
        accumulatedPositions = nil

        logger.info("""
        キャリブレーション完了: frameCount=\(referencePosture.frameCount), \
        avgConfidence=\(String(format: "%.2f", referencePosture.averageConfidence))
        """)
    }
}

// MARK: - AccumulatedPositions

/// キャリブレーション中の位置データ累積
private struct AccumulatedPositions {
    /// フレームがない場合のダミーデータ
    static let emptyReferencePosture = ReferencePosture(
        neck: ReferenceJointPosition(x: 0, y: 0, confidence: 0),
        leftShoulder: ReferenceJointPosition(x: 0, y: 0, confidence: 0),
        rightShoulder: ReferenceJointPosition(x: 0, y: 0, confidence: 0),
        frameCount: 0, averageConfidence: 0,
        baselineMetrics: BaselineMetrics(headTiltDeviation: 0, shoulderBalance: 0, forwardLean: 0, symmetry: 0)
    )

    // 必須関節
    var neckX: Double = 0
    var neckY: Double = 0
    var neckConfidence: Double = 0

    var leftShoulderX: Double = 0
    var leftShoulderY: Double = 0
    var leftShoulderConfidence: Double = 0

    var rightShoulderX: Double = 0
    var rightShoulderY: Double = 0
    var rightShoulderConfidence: Double = 0

    // オプショナル関節
    var noseX: Double = 0
    var noseY: Double = 0
    var noseConfidence: Double = 0
    var noseCount: Int = 0

    var leftEarX: Double = 0
    var leftEarY: Double = 0
    var leftEarConfidence: Double = 0
    var leftEarCount: Int = 0

    var rightEarX: Double = 0
    var rightEarY: Double = 0
    var rightEarConfidence: Double = 0
    var rightEarCount: Int = 0

    var rootX: Double = 0
    var rootY: Double = 0
    var rootConfidence: Double = 0
    var rootCount: Int = 0

    /// フレーム数
    var frameCount: Int = 0

    /// フレームデータを追加
    mutating func add(_ pose: BodyPose) {
        guard let neck = pose.neck,
              let leftShoulder = pose.leftShoulder,
              let rightShoulder = pose.rightShoulder
        else {
            return
        }

        frameCount += 1

        // 必須関節
        neckX += neck.x
        neckY += neck.y
        neckConfidence += neck.confidence

        leftShoulderX += leftShoulder.x
        leftShoulderY += leftShoulder.y
        leftShoulderConfidence += leftShoulder.confidence

        rightShoulderX += rightShoulder.x
        rightShoulderY += rightShoulder.y
        rightShoulderConfidence += rightShoulder.confidence

        // オプショナル関節
        if let nose = pose.nose {
            noseX += nose.x
            noseY += nose.y
            noseConfidence += nose.confidence
            noseCount += 1
        }

        if let leftEar = pose.leftEar {
            leftEarX += leftEar.x
            leftEarY += leftEar.y
            leftEarConfidence += leftEar.confidence
            leftEarCount += 1
        }

        if let rightEar = pose.rightEar {
            rightEarX += rightEar.x
            rightEarY += rightEar.y
            rightEarConfidence += rightEar.confidence
            rightEarCount += 1
        }

        if let root = pose.root {
            rootX += root.x
            rootY += root.y
            rootConfidence += root.confidence
            rootCount += 1
        }
    }

    /// 平均位置からReferencePostureを生成
    func createReferencePosture() -> ReferencePosture {
        let count = Double(frameCount)
        guard count > 0 else { return Self.emptyReferencePosture }

        // 必須関節の平均
        let avgNeck = ReferenceJointPosition(x: neckX / count, y: neckY / count, confidence: neckConfidence / count)
        let avgLeftShoulder = ReferenceJointPosition(
            x: leftShoulderX / count, y: leftShoulderY / count, confidence: leftShoulderConfidence / count
        )
        let avgRightShoulder = ReferenceJointPosition(
            x: rightShoulderX / count, y: rightShoulderY / count, confidence: rightShoulderConfidence / count
        )

        // オプショナル関節の平均
        let avgNose = averageOptionalJoint(
            x: noseX, y: noseY, confidence: noseConfidence, count: noseCount
        )
        let avgLeftEar = averageOptionalJoint(
            x: leftEarX, y: leftEarY, confidence: leftEarConfidence, count: leftEarCount
        )
        let avgRightEar = averageOptionalJoint(
            x: rightEarX, y: rightEarY, confidence: rightEarConfidence, count: rightEarCount
        )
        let avgRoot = averageOptionalJoint(
            x: rootX, y: rootY, confidence: rootConfidence, count: rootCount
        )

        // 平均信頼度（必須関節のみ）
        let avgConfidence = (avgNeck.confidence + avgLeftShoulder.confidence + avgRightShoulder.confidence) / 3.0

        // 基準メトリクスを計算
        let baselineMetrics = calculateBaselineMetrics(
            neck: avgNeck,
            leftShoulder: avgLeftShoulder,
            rightShoulder: avgRightShoulder,
            nose: avgNose,
            ears: (left: avgLeftEar, right: avgRightEar)
        )

        return ReferencePosture(
            neck: avgNeck,
            leftShoulder: avgLeftShoulder,
            rightShoulder: avgRightShoulder,
            nose: avgNose,
            leftEar: avgLeftEar,
            rightEar: avgRightEar,
            root: avgRoot,
            frameCount: frameCount,
            averageConfidence: avgConfidence,
            baselineMetrics: baselineMetrics
        )
    }

    /// オプショナル関節の平均を計算
    private func averageOptionalJoint(x: Double, y: Double, confidence: Double, count: Int) -> ReferenceJointPosition? {
        guard count > 0 else { return nil }
        let countDouble = Double(count)
        return ReferenceJointPosition(x: x / countDouble, y: y / countDouble, confidence: confidence / countDouble)
    }

    /// 基準メトリクスを計算
    private func calculateBaselineMetrics(
        neck: ReferenceJointPosition,
        leftShoulder: ReferenceJointPosition,
        rightShoulder: ReferenceJointPosition,
        nose: ReferenceJointPosition?,
        ears: (left: ReferenceJointPosition?, right: ReferenceJointPosition?)
    ) -> BaselineMetrics {
        let leftEar = ears.left
        let rightEar = ears.right
        // 頭傾き: 首-鼻のX座標差
        let headTiltDeviation: Double = if let nose {
            nose.x - neck.x
        } else {
            0
        }

        // 肩バランス: 左右肩のY座標差
        let shoulderBalance = leftShoulder.y - rightShoulder.y

        // 前傾: 首-鼻のY座標差（前傾時は鼻が下がる）
        // Vision座標系: Y=0が下端、Y=1が上端
        // 良い姿勢: nose.y > neck.y（鼻が首より上）
        // 前傾姿勢: nose.y が neck.y に近づく、または下回る
        let forwardLean: Double = if let nose {
            max(0, neck.y - nose.y)
        } else {
            0
        }

        // 対称性: 左右の偏差の平均
        var deviations: [Double] = []

        // 肩の中心からのずれ
        let shoulderCenterX = (leftShoulder.x + rightShoulder.x) / 2
        deviations.append(abs(shoulderCenterX - neck.x))

        // 左右肩の首からの距離の差
        let leftShoulderDistance = abs(leftShoulder.x - neck.x)
        let rightShoulderDistance = abs(rightShoulder.x - neck.x)
        deviations.append(abs(leftShoulderDistance - rightShoulderDistance))

        // 耳の対称性
        if let leftEar, let rightEar {
            let leftEarDistance = abs(leftEar.x - neck.x)
            let rightEarDistance = abs(rightEar.x - neck.x)
            deviations.append(abs(leftEarDistance - rightEarDistance))
        }

        let symmetry = deviations.isEmpty ? 0 : deviations.reduce(0, +) / Double(deviations.count)

        return BaselineMetrics(
            headTiltDeviation: headTiltDeviation,
            shoulderBalance: shoulderBalance,
            forwardLean: forwardLean,
            symmetry: symmetry
        )
    }
}
