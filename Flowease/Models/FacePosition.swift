import Foundation

/// 顔検出結果データ
///
/// VNFaceObservationから取得した顔の位置・サイズ・傾き情報を保持する。
/// 姿勢スコアの算出に使用される。
///
/// Note: nonisolated宣言により、バックグラウンドスレッドからもプロパティにアクセス可能。
/// FaceDetectorでの顔検出時に使用される。
nonisolated struct FacePosition: Sendable, Equatable {
    /// 顔中心のX座標（正規化座標 0-1）
    let centerX: Double

    /// 顔中心のY座標（正規化座標 0-1、Y=0が下端）
    let centerY: Double

    /// 顔の面積（width × height、正規化座標）
    let area: Double

    /// 顔の傾き（roll角、ラジアン単位、[-π, π)）
    /// nilの場合はroll角取得不可
    let roll: Double?

    /// 検出品質（0-1、VNDetectFaceCaptureQualityRequest由来）
    let captureQuality: Double

    /// 検出時刻
    let timestamp: Date

    /// 最小検出品質しきい値
    static let minimumCaptureQuality: Double = 0.3

    /// 検出品質が十分かどうか
    var hasAcceptableQuality: Bool {
        captureQuality >= Self.minimumCaptureQuality
    }

    // MARK: - Validation

    /// FacePositionのすべてのプロパティが有効な範囲内にあるかを判定
    ///
    /// バリデーションルール（data-model.md準拠）:
    /// - centerX, centerY: 0.0 ≤ value ≤ 1.0
    /// - area: 0.0 < value ≤ 1.0
    /// - roll: -π ≤ value < π (nilの場合はroll未取得として有効)
    /// - captureQuality: 0.0 ≤ value ≤ 1.0
    var isValid: Bool {
        // centerX/centerY: 0.0 ≤ value ≤ 1.0
        guard (0.0 ... 1.0).contains(centerX) else { return false }
        guard (0.0 ... 1.0).contains(centerY) else { return false }

        // area: 0.0 < value ≤ 1.0 (0は無効)
        guard area > 0.0, area <= 1.0 else { return false }

        // roll: -π ≤ value < π (半開区間) または nil
        if let roll {
            // -π ≤ roll < π (πは無効)
            guard roll >= -.pi, roll < .pi else { return false }
        }

        // captureQuality: 0.0 ≤ value ≤ 1.0
        guard (0.0 ... 1.0).contains(captureQuality) else { return false }

        return true
    }
}
