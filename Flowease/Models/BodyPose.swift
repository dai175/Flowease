import Foundation

/// 上半身の姿勢データ
///
/// Vision フレームワークで検出された上半身の関節位置を保持する。
/// 姿勢スコアの算出に使用される。
struct BodyPose: Sendable, Equatable {
    /// 鼻の位置（頭部位置の基準点）
    let nose: JointPosition?

    /// 首の位置（頭部傾斜・前傾検出に使用）
    let neck: JointPosition?

    /// 左肩の位置（肩の水平バランスに使用）
    let leftShoulder: JointPosition?

    /// 右肩の位置（肩の水平バランスに使用）
    let rightShoulder: JointPosition?

    /// 左耳の位置（頭部回転検出に使用）
    let leftEar: JointPosition?

    /// 右耳の位置（頭部回転検出に使用）
    let rightEar: JointPosition?

    /// 体の中心位置（背骨の垂直アライメントに使用）
    let root: JointPosition?

    /// 検出時刻
    let timestamp: Date

    /// 姿勢スコア算出に必要な最小信頼度
    private static let minimumConfidence: Double = 0.5

    /// 姿勢スコア算出に必要な関節が全て検出されているか
    ///
    /// 首、左肩、右肩が全て検出され、かつ信頼度が0.5以上の場合に `true` を返す。
    var isValid: Bool {
        [neck, leftShoulder, rightShoulder].allSatisfy { joint in
            guard let joint else { return false }
            return joint.confidence >= Self.minimumConfidence
        }
    }
}
