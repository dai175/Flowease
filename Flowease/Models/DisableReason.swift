import Foundation

// MARK: - DisableReason

/// 監視無効の理由
///
/// 姿勢監視が無効化されている理由を表す。
/// これらの状態はユーザーの操作なしには解消されない。
enum DisableReason: Sendable, Equatable {
    /// カメラアクセス権限が拒否されている
    ///
    /// ユーザーがカメラアクセスを明示的に拒否した場合。
    /// システム設定から許可を変更する必要がある。
    case cameraPermissionDenied

    /// カメラアクセス権限が制限されている
    ///
    /// ペアレンタルコントロールやMDMなどによりカメラアクセスが制限されている場合。
    case cameraPermissionRestricted

    /// カメラデバイスが存在しない
    ///
    /// Macに内蔵カメラがなく、外部カメラも接続されていない場合。
    case noCameraAvailable
}

// MARK: CustomStringConvertible

extension DisableReason: CustomStringConvertible {
    /// ユーザー向けの説明文
    var description: String {
        switch self {
        case .cameraPermissionDenied:
            "カメラへのアクセスが拒否されています"
        case .cameraPermissionRestricted:
            "カメラへのアクセスが制限されています"
        case .noCameraAvailable:
            "カメラが見つかりません"
        }
    }

    /// ユーザーへの対処法案内
    var actionHint: String {
        switch self {
        case .cameraPermissionDenied:
            "システム設定 > プライバシーとセキュリティ > カメラ から許可してください"
        case .cameraPermissionRestricted:
            "システム管理者に連絡してカメラの使用許可を依頼してください"
        case .noCameraAvailable:
            "外部カメラを接続してください"
        }
    }
}
