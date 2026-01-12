import Foundation

/// NSLock の拡張メソッド
///
/// ロックの取得・解放パターンを簡潔に記述するためのヘルパーメソッドを提供します。
extension NSLock {
    /// ロックを取得してクロージャを実行し、完了後にロックを解放
    ///
    /// - Parameter body: ロック保持中に実行するクロージャ
    /// - Returns: クロージャの戻り値
    /// - Throws: クロージャがスローした場合は再スロー
    @discardableResult
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
