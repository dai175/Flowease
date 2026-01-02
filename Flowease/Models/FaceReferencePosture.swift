import Foundation

/// 顔ベースの基準姿勢
///
/// 複数フレームから平均化された顔位置と評価項目の基準値を保持する。
/// UserDefaultsへの永続化に対応するためCodableを実装。
struct FaceReferencePosture: Codable, Sendable, Equatable {
    /// キャリブレーション完了日時
    let calibratedAt: Date

    /// 平均化に使用したフレーム数
    let frameCount: Int

    /// 全フレームの平均検出品質 (0.0〜1.0)
    let averageQuality: Double

    /// 基準姿勢時の評価項目値
    let baselineMetrics: FaceBaselineMetrics

    /// 最低必要フレーム数（約1秒分、15FPS処理前提）
    static let minimumFrameCount = 15

    /// 最低必要検出品質
    static let minimumQuality = 0.3

    /// 有効なキャリブレーションデータかどうか
    var isValid: Bool {
        frameCount >= Self.minimumFrameCount &&
            averageQuality >= Self.minimumQuality
    }
}
