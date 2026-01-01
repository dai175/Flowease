import Foundation

/// ユーザーがキャリブレーションで設定した基準姿勢
///
/// 複数フレームから平均化された関節位置と評価項目の基準値を保持する。
/// UserDefaultsへの永続化に対応するためCodableを実装。
struct ReferencePosture: Codable, Sendable, Equatable {
    // MARK: - Required Joint Positions

    /// 首の平均位置（必須）
    let neck: ReferenceJointPosition

    /// 左肩の平均位置（必須）
    let leftShoulder: ReferenceJointPosition

    /// 右肩の平均位置（必須）
    let rightShoulder: ReferenceJointPosition

    // MARK: - Optional Joint Positions

    /// 鼻の平均位置
    let nose: ReferenceJointPosition?

    /// 左耳の平均位置
    let leftEar: ReferenceJointPosition?

    /// 右耳の平均位置
    let rightEar: ReferenceJointPosition?

    /// 体の中心の平均位置
    let root: ReferenceJointPosition?

    // MARK: - Calibration Metadata

    /// キャリブレーション完了日時
    let calibratedAt: Date

    /// 平均化に使用したフレーム数
    let frameCount: Int

    /// 全フレームの平均信頼度 (0.0〜1.0)
    let averageConfidence: Double

    /// 基準姿勢時の各評価項目の値
    let baselineMetrics: BaselineMetrics

    // MARK: - Validation Constants

    /// 最低必要フレーム数（約1秒分）
    static let minimumFrameCount = 30

    /// 最低必要信頼度
    static let minimumConfidence = 0.7

    // MARK: - Private Helpers

    /// キャリブレーション日時表示用のDateFormatter（キャッシュ）
    private static let calibrationDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    // MARK: - Initializer

    /// イニシャライザ
    /// - Parameters:
    ///   - neck: 首の位置（必須）
    ///   - leftShoulder: 左肩の位置（必須）
    ///   - rightShoulder: 右肩の位置（必須）
    ///   - nose: 鼻の位置
    ///   - leftEar: 左耳の位置
    ///   - rightEar: 右耳の位置
    ///   - root: 体の中心の位置
    ///   - calibratedAt: キャリブレーション日時（デフォルト: 現在時刻）
    ///   - frameCount: フレーム数
    ///   - averageConfidence: 平均信頼度
    ///   - baselineMetrics: 基準評価項目
    init(
        neck: ReferenceJointPosition,
        leftShoulder: ReferenceJointPosition,
        rightShoulder: ReferenceJointPosition,
        nose: ReferenceJointPosition? = nil,
        leftEar: ReferenceJointPosition? = nil,
        rightEar: ReferenceJointPosition? = nil,
        root: ReferenceJointPosition? = nil,
        calibratedAt: Date = Date(),
        frameCount: Int,
        averageConfidence: Double,
        baselineMetrics: BaselineMetrics
    ) {
        self.neck = neck
        self.leftShoulder = leftShoulder
        self.rightShoulder = rightShoulder
        self.nose = nose
        self.leftEar = leftEar
        self.rightEar = rightEar
        self.root = root
        self.calibratedAt = calibratedAt
        self.frameCount = max(0, frameCount)
        self.averageConfidence = averageConfidence.isNaN ? 0.0 : min(max(averageConfidence, 0.0), 1.0)
        self.baselineMetrics = baselineMetrics
    }

    // MARK: - Validation

    /// 有効なキャリブレーションデータかどうか
    /// frameCount >= 30 かつ averageConfidence >= 0.7 の場合にtrue
    var isValid: Bool {
        frameCount >= ReferencePosture.minimumFrameCount &&
            averageConfidence >= ReferencePosture.minimumConfidence
    }

    /// キャリブレーションからの経過時間
    var timeSinceCalibration: TimeInterval {
        Date().timeIntervalSince(calibratedAt)
    }

    /// キャリブレーション日時のフォーマット済み文字列
    /// ユーザーのシステムロケールに従ってフォーマットされる
    var formattedCalibrationDate: String {
        Self.calibrationDateFormatter.string(from: calibratedAt)
    }
}
