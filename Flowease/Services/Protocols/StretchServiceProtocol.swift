import Combine
import Foundation

/// ストレッチサービスプロトコル
public protocol StretchServiceProtocol: AnyObject {

    // MARK: - Properties

    /// 利用可能なストレッチ一覧
    var stretches: [Stretch] { get }

    /// 現在のセッション
    var currentSession: CurrentValueSubject<StretchSession?, Never> { get }

    /// セッションが進行中か
    var isSessionActive: Bool { get }

    // MARK: - Methods

    /// 新しいストレッチセッションを開始
    /// - Parameter stretches: セッションに含めるストレッチ（nilの場合は全て）
    func startSession(stretches: [Stretch]?)

    /// セッションを終了
    func endSession()

    /// 現在のストレッチを完了し、次に進む
    func nextStretch()

    /// 現在のストレッチをスキップ
    func skipStretch()

    /// セッションを一時停止
    func pauseSession()

    /// セッションを再開
    func resumeSession()

    /// カテゴリでストレッチをフィルタ
    /// - Parameter category: ストレッチカテゴリ
    /// - Returns: フィルタされたストレッチ
    func stretches(for category: StretchCategory) -> [Stretch]
}
