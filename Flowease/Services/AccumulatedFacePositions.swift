// AccumulatedFacePositions.swift
// Flowease
//
// 顔ベースキャリブレーション中の位置データ累積

import Foundation

// MARK: - AccumulatedFacePositions

/// 顔ベースキャリブレーション中の位置データ累積
///
/// CalibrationServiceがFacePositionフレームデータを収集し、
/// 平均位置からFaceReferencePostureを生成するために使用する。
struct AccumulatedFacePositions {
    /// フレームがない場合のダミーデータ
    static let emptyFaceReferencePosture = FaceReferencePosture(
        calibratedAt: Date(),
        frameCount: 0,
        averageQuality: 0,
        baselineMetrics: FaceBaselineMetrics(
            baselineY: 0.5,
            baselineArea: 0.01,
            baselineRoll: 0.0
        )
    )

    // 累積値
    private var totalCenterY: Double = 0
    private var totalArea: Double = 0
    private var totalRoll: Double = 0
    private var totalQuality: Double = 0

    /// roll角が利用可能なフレーム数
    private var rollCount: Int = 0

    /// フレーム数
    private(set) var frameCount: Int = 0

    /// フレームデータを追加
    ///
    /// - Parameter face: 追加するFacePositionデータ
    mutating func add(_ face: FacePosition) {
        frameCount += 1

        // 累積値に追加
        totalCenterY += face.centerY
        totalArea += face.area
        totalQuality += face.captureQuality

        // roll角はオプショナル
        if let roll = face.roll {
            totalRoll += roll
            rollCount += 1
        }
    }

    /// 平均位置からFaceReferencePostureを生成
    ///
    /// - Returns: 蓄積されたデータから計算された基準姿勢
    func createFaceReferencePosture() -> FaceReferencePosture {
        let count = Double(frameCount)
        guard count > 0 else { return Self.emptyFaceReferencePosture }

        // 平均値を計算
        let avgCenterY = totalCenterY / count
        let avgArea = totalArea / count
        let avgQuality = totalQuality / count

        // roll角の平均（利用可能なフレームのみ）
        let avgRoll: Double = rollCount > 0 ? totalRoll / Double(rollCount) : 0.0

        // FaceBaselineMetricsを作成
        let baselineMetrics = FaceBaselineMetrics(
            baselineY: avgCenterY,
            baselineArea: avgArea,
            baselineRoll: avgRoll
        )

        return FaceReferencePosture(
            calibratedAt: Date(),
            frameCount: frameCount,
            averageQuality: avgQuality,
            baselineMetrics: baselineMetrics
        )
    }
}
