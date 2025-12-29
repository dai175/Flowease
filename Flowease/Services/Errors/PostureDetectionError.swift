import Foundation

/// 姿勢検知サービスのエラー
public enum PostureDetectionError: Error, LocalizedError, Sendable {
    /// カメラアクセスが拒否された
    case cameraAccessDenied

    /// カメラが見つからない
    case cameraNotFound

    /// Vision Frameworkのエラー
    case visionFrameworkError(any Error & Sendable)

    /// ポーズが検出されなかった
    case noPoseDetected

    /// 検出の信頼度が不十分
    case insufficientConfidence

    /// 検知が既に実行中
    case alreadyRunning

    /// 検知が停止している
    case notRunning

    public var errorDescription: String? {
        switch self {
        case .cameraAccessDenied:
            return "カメラへのアクセスが拒否されました。システム設定からカメラへのアクセスを許可してください。"
        case .cameraNotFound:
            return "カメラが見つかりません。カメラが接続されているか確認してください。"
        case .visionFrameworkError(let error):
            return "姿勢検知でエラーが発生しました: \(error.localizedDescription)"
        case .noPoseDetected:
            return "姿勢を検出できませんでした。カメラに上半身が映るよう調整してください。"
        case .insufficientConfidence:
            return "姿勢の検出精度が低すぎます。照明や位置を調整してください。"
        case .alreadyRunning:
            return "姿勢検知は既に実行中です。"
        case .notRunning:
            return "姿勢検知は実行されていません。"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .cameraAccessDenied:
            return "システム設定 > プライバシーとセキュリティ > カメラ からFloweaseへのアクセスを許可してください。"
        case .cameraNotFound:
            return "内蔵カメラまたは外部カメラを接続してから、アプリを再起動してください。"
        case .visionFrameworkError:
            return "アプリを再起動してください。問題が解決しない場合は、開発者にお問い合わせください。"
        case .noPoseDetected:
            return "カメラの前に座り、上半身全体がカメラに映るように位置を調整してください。"
        case .insufficientConfidence:
            return "明るい場所で、背景がシンプルな環境で使用してください。"
        case .alreadyRunning:
            return nil
        case .notRunning:
            return "姿勢モニタリングを開始してください。"
        }
    }
}

// MARK: - Equatable

extension PostureDetectionError: Equatable {
    public static func == (lhs: PostureDetectionError, rhs: PostureDetectionError) -> Bool {
        switch (lhs, rhs) {
        case (.cameraAccessDenied, .cameraAccessDenied),
            (.cameraNotFound, .cameraNotFound),
            (.noPoseDetected, .noPoseDetected),
            (.insufficientConfidence, .insufficientConfidence),
            (.alreadyRunning, .alreadyRunning),
            (.notRunning, .notRunning):
            return true
        case (.visionFrameworkError, .visionFrameworkError):
            return true
        default:
            return false
        }
    }
}
