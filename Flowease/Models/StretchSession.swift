import Foundation

/// ストレッチセッションモデル
public struct StretchSession: Sendable {
    /// セッションに含まれるストレッチ
    public let stretches: [Stretch]

    /// 現在のストレッチインデックス
    public var currentIndex: Int

    /// 現在のストレッチ内の経過時間（秒）
    public var elapsedSeconds: Int

    /// セッション開始時刻
    public let startedAt: Date

    /// セッションが一時停止中か
    public var isPaused: Bool

    public init(
        stretches: [Stretch],
        currentIndex: Int = 0,
        elapsedSeconds: Int = 0,
        startedAt: Date = Date(),
        isPaused: Bool = false
    ) {
        self.stretches = stretches
        self.currentIndex = max(0, min(stretches.count - 1, currentIndex))
        self.elapsedSeconds = max(0, elapsedSeconds)
        self.startedAt = startedAt
        self.isPaused = isPaused
    }

    /// セッションが完了したか
    public var isCompleted: Bool {
        currentIndex >= stretches.count
    }

    /// 現在のストレッチ
    public var currentStretch: Stretch? {
        guard currentIndex < stretches.count else { return nil }
        return stretches[currentIndex]
    }

    /// 進捗率（0.0〜1.0）
    public var progress: Double {
        guard !stretches.isEmpty else { return 0.0 }
        let totalDuration = stretches.reduce(0) { $0 + $1.durationSeconds }
        guard totalDuration > 0 else { return 0.0 }
        let completedDuration = stretches.prefix(currentIndex).reduce(0) { $0 + $1.durationSeconds }
        return min(1.0, Double(completedDuration + elapsedSeconds) / Double(totalDuration))
    }

    /// 現在のストレッチの進捗率（0.0〜1.0）
    public var currentStretchProgress: Double {
        guard let stretch = currentStretch, stretch.durationSeconds > 0 else { return 0.0 }
        return min(1.0, Double(elapsedSeconds) / Double(stretch.durationSeconds))
    }

    /// 現在のストレッチの残り時間（秒）
    public var remainingSecondsForCurrentStretch: Int {
        guard let stretch = currentStretch else { return 0 }
        return max(0, stretch.durationSeconds - elapsedSeconds)
    }

    /// セッション全体の残り時間（秒）
    public var totalRemainingSeconds: Int {
        guard !stretches.isEmpty else { return 0 }
        let remainingStretches = stretches.dropFirst(currentIndex + 1)
        let remainingDuration = remainingStretches.reduce(0) { $0 + $1.durationSeconds }
        return remainingDuration + remainingSecondsForCurrentStretch
    }

    /// 残り時間をフォーマット済みで返す
    public var formattedRemainingTime: String {
        let seconds = remainingSecondsForCurrentStretch
        return String(format: "%02d", seconds)
    }
}

// MARK: - Mutations

extension StretchSession {
    /// 次のストレッチに進む
    public mutating func moveToNext() {
        guard currentIndex < stretches.count else { return }
        currentIndex += 1
        elapsedSeconds = 0
    }

    /// 現在のストレッチをスキップ
    public mutating func skip() {
        moveToNext()
    }

    /// 経過時間を更新
    public mutating func updateElapsedTime(_ seconds: Int) {
        elapsedSeconds = max(0, seconds)
    }

    /// セッションを一時停止
    public mutating func pause() {
        isPaused = true
    }

    /// セッションを再開
    public mutating func resume() {
        isPaused = false
    }
}

// MARK: - Factory Methods

extension StretchSession {
    /// 全てのストレッチを含むセッションを作成
    public static func createWithAllStretches() -> StretchSession {
        StretchSession(stretches: Stretch.allStretches)
    }

    /// カテゴリでフィルタしたセッションを作成
    public static func create(for category: StretchCategory) -> StretchSession {
        StretchSession(stretches: Stretch.stretches(for: category))
    }

    /// 指定したストレッチでセッションを作成
    public static func create(with stretches: [Stretch]) -> StretchSession {
        StretchSession(stretches: stretches)
    }
}
