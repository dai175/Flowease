import Foundation

/// カメラサービスのエラー
public enum CameraError: Error, LocalizedError, Sendable {
    /// カメラアクセスが拒否された
    case accessDenied

    /// 指定されたデバイスが見つからない
    case deviceNotFound(deviceID: String)

    /// セッションの設定に失敗した
    case sessionConfigurationFailed

    /// カメラは既に実行中
    case alreadyRunning

    /// カメラの開始に失敗した
    case startFailed(any Error & Sendable)

    /// 入力の追加に失敗した
    case inputAddFailed

    /// 出力の追加に失敗した
    case outputAddFailed

    public var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "カメラへのアクセスが拒否されました。"
        case .deviceNotFound(let deviceID):
            return "カメラデバイス '\(deviceID)' が見つかりません。"
        case .sessionConfigurationFailed:
            return "カメラセッションの設定に失敗しました。"
        case .alreadyRunning:
            return "カメラは既に実行中です。"
        case .startFailed(let error):
            return "カメラの開始に失敗しました: \(error.localizedDescription)"
        case .inputAddFailed:
            return "カメラ入力の追加に失敗しました。"
        case .outputAddFailed:
            return "カメラ出力の追加に失敗しました。"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .accessDenied:
            return "システム設定 > プライバシーとセキュリティ > カメラ からFloweaseへのアクセスを許可してください。"
        case .deviceNotFound:
            return "別のカメラを選択するか、カメラが正しく接続されているか確認してください。"
        case .sessionConfigurationFailed:
            return "アプリを再起動してください。"
        case .alreadyRunning:
            return nil
        case .startFailed:
            return "他のアプリがカメラを使用していないか確認し、アプリを再起動してください。"
        case .inputAddFailed, .outputAddFailed:
            return "アプリを再起動してください。問題が解決しない場合は、開発者にお問い合わせください。"
        }
    }
}

// MARK: - Equatable

extension CameraError: Equatable {
    public static func == (lhs: CameraError, rhs: CameraError) -> Bool {
        switch (lhs, rhs) {
        case (.accessDenied, .accessDenied),
            (.sessionConfigurationFailed, .sessionConfigurationFailed),
            (.alreadyRunning, .alreadyRunning),
            (.inputAddFailed, .inputAddFailed),
            (.outputAddFailed, .outputAddFailed):
            return true
        case (.deviceNotFound(let lhsID), .deviceNotFound(let rhsID)):
            return lhsID == rhsID
        case (.startFailed(let lhsError), .startFailed(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}
