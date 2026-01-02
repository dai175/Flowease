import Foundation

/// キャリブレーションの進行状況
///
/// キャリブレーション実行中の状態を追跡する。
/// フレーム収集の進捗、残り時間、失敗判定に使用。
struct CalibrationProgress: Sendable, Equatable {
    /// キャリブレーション開始時刻
    let startTime: Date

    /// 収集済みフレーム数（信頼度0.5以上のフレームのみカウント）
    private(set) var collectedFrames: Int

    /// 目標時間（デフォルト: 3.0秒）
    let targetDuration: TimeInterval

    /// 低信頼度の連続フレーム数
    /// 信頼度0.5未満のフレームが連続した回数を記録
    private(set) var lowConfidenceStreak: Int

    /// 人物未検出の連続フレーム数
    /// 必須関節（首、両肩）が検出されなかったフレームが連続した回数を記録
    private(set) var noPersonStreak: Int

    /// 失敗判定のしきい値（約1秒 = 30フレーム）
    static let failureThreshold = 30

    /// デフォルトの目標時間（3秒）
    static let defaultTargetDuration: TimeInterval = 3.0

    /// イニシャライザ
    /// - Parameters:
    ///   - startTime: 開始時刻（デフォルト: 現在時刻）
    ///   - collectedFrames: 収集済みフレーム数（デフォルト: 0）
    ///   - targetDuration: 目標時間（デフォルト: 3.0秒）
    ///   - lowConfidenceStreak: 低信頼度連続フレーム数（デフォルト: 0）
    ///   - noPersonStreak: 人物未検出連続フレーム数（デフォルト: 0）
    init(
        startTime: Date = Date(),
        collectedFrames: Int = 0,
        targetDuration: TimeInterval = CalibrationProgress.defaultTargetDuration,
        lowConfidenceStreak: Int = 0,
        noPersonStreak: Int = 0
    ) {
        self.startTime = startTime
        self.collectedFrames = max(0, collectedFrames)
        self.targetDuration = max(0, targetDuration)
        self.lowConfidenceStreak = max(0, lowConfidenceStreak)
        self.noPersonStreak = max(0, noPersonStreak)
    }

    // MARK: - Computed Properties

    /// 経過時間（秒）
    var elapsedTime: TimeInterval {
        Date().timeIntervalSince(startTime)
    }

    /// 進捗率 (0.0 〜 1.0)
    /// 経過時間 / 目標時間で計算
    var progress: Double {
        guard targetDuration > 0 else { return 1.0 }
        return min(1.0, max(0.0, elapsedTime / targetDuration))
    }

    /// 残り秒数
    /// 0未満にはならない
    var remainingSeconds: Double {
        max(0.0, targetDuration - elapsedTime)
    }

    /// 失敗すべきかどうか
    /// 低信頼度または人物未検出が約1秒（30フレーム）連続したら失敗
    var shouldFail: Bool {
        lowConfidenceStreak >= CalibrationProgress.failureThreshold ||
            noPersonStreak >= CalibrationProgress.failureThreshold
    }

    /// 人物未検出で失敗すべきかどうか
    var shouldFailNoPersonDetected: Bool {
        noPersonStreak >= CalibrationProgress.failureThreshold
    }

    /// 低信頼度で失敗すべきかどうか
    var shouldFailLowConfidence: Bool {
        lowConfidenceStreak >= CalibrationProgress.failureThreshold
    }

    /// キャリブレーション完了判定
    /// 経過時間が目標時間に達したかどうか
    var isComplete: Bool {
        elapsedTime >= targetDuration
    }

    // MARK: - Mutating Methods

    /// フレームの品質レベル
    enum FrameQuality {
        /// 高信頼度（必須関節が検出され、信頼度が0.5以上）
        case highConfidence
        /// 低信頼度（必須関節は検出されたが信頼度が0.5未満）
        case lowConfidence
        /// 人物未検出（必須関節が検出されなかった）
        case noPersonDetected
    }

    /// フレームを追加
    /// - Parameter quality: フレームの品質レベル
    mutating func addFrame(quality: FrameQuality) {
        switch quality {
        case .highConfidence:
            collectedFrames += 1
            lowConfidenceStreak = 0
            noPersonStreak = 0
        case .lowConfidence:
            lowConfidenceStreak += 1
            noPersonStreak = 0
        case .noPersonDetected:
            noPersonStreak += 1
            lowConfidenceStreak = 0
        }
    }

    /// フレームを追加（後方互換性のため）
    /// - Parameter isHighConfidence: 信頼度が0.5以上かどうか
    mutating func addFrame(isHighConfidence: Bool) {
        addFrame(quality: isHighConfidence ? .highConfidence : .lowConfidence)
    }
}
