// AccumulatedPositions.swift
// Flowease
//
// キャリブレーション中の位置データ累積
//

import Foundation

// MARK: - AccumulatedPositions

/// キャリブレーション中の位置データ累積
///
/// CalibrationServiceがフレームデータを収集し、
/// 平均位置からReferencePostureを生成するために使用する。
struct AccumulatedPositions {
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
