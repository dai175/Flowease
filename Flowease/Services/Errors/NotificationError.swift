import Foundation

/// 通知権限リクエスト時のエラー
public enum AuthorizationError: Error, LocalizedError, Sendable {
    /// 権限が拒否された
    case denied

    /// 権限が制限されている（ペアレンタルコントロールなど）
    case restricted

    /// システムエラー
    case systemError(Error)

    public var errorDescription: String? {
        switch self {
        case .denied:
            return "通知の権限が拒否されました。"
        case .restricted:
            return "通知の権限が制限されています。"
        case .systemError(let error):
            return "通知の権限リクエストでエラーが発生しました: \(error.localizedDescription)"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .denied:
            return "システム設定 > 通知 > Flowease から通知を許可してください。"
        case .restricted:
            return "デバイスの管理者に連絡して、通知の制限を解除してください。"
        case .systemError:
            return "アプリを再起動してから、もう一度お試しください。"
        }
    }
}

// MARK: - Equatable

extension AuthorizationError: Equatable {
    public static func == (lhs: AuthorizationError, rhs: AuthorizationError) -> Bool {
        switch (lhs, rhs) {
        case (.denied, .denied),
            (.restricted, .restricted):
            return true
        case (.systemError(let lhsError), .systemError(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

/// 通知送信時のエラー
public enum NotificationError: Error, LocalizedError, Sendable {
    /// 通知の配信に失敗した
    case deliveryFailed(Error)

    /// 通知のコンテンツが無効
    case invalidContent

    /// 通知の権限がない
    case notAuthorized

    public var errorDescription: String? {
        switch self {
        case .deliveryFailed(let error):
            return "通知の送信に失敗しました: \(error.localizedDescription)"
        case .invalidContent:
            return "通知の内容が無効です。"
        case .notAuthorized:
            return "通知の権限がありません。"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .deliveryFailed:
            return "もう一度お試しください。"
        case .invalidContent:
            return "開発者にお問い合わせください。"
        case .notAuthorized:
            return "システム設定 > 通知 > Flowease から通知を許可してください。"
        }
    }
}

// MARK: - Equatable

extension NotificationError: Equatable {
    public static func == (lhs: NotificationError, rhs: NotificationError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidContent, .invalidContent),
            (.notAuthorized, .notAuthorized):
            return true
        case (.deliveryFailed(let lhsError), .deliveryFailed(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}
