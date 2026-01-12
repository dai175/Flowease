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

    /// 顔未検出の連続フレーム数
    /// 顔が検出されなかったフレームが連続した回数を記録
    private(set) var noFaceStreak: Int

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
    ///   - noFaceStreak: 顔未検出連続フレーム数（デフォルト: 0）
    init(
        startTime: Date = Date(),
        collectedFrames: Int = 0,
        targetDuration: TimeInterval = CalibrationProgress.defaultTargetDuration,
        lowConfidenceStreak: Int = 0,
        noFaceStreak: Int = 0
    ) {
        self.startTime = startTime
        self.collectedFrames = max(0, collectedFrames)
        self.targetDuration = max(0, targetDuration)
        self.lowConfidenceStreak = max(0, lowConfidenceStreak)
        self.noFaceStreak = max(0, noFaceStreak)
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

    /// 失敗理由（失敗すべき状態でない場合はnil）
    /// 低信頼度または顔未検出が約1秒（30フレーム）連続したら失敗と判定
    /// 顔未検出を優先して判定
    var failureReason: CalibrationFailure? {
        if noFaceStreak >= Self.failureThreshold {
            return .noFaceDetected
        }
        if lowConfidenceStreak >= Self.failureThreshold {
            return .lowConfidence
        }
        return nil
    }

    /// キャリブレーション完了判定
    /// 経過時間が目標時間に達したかどうか
    var isComplete: Bool {
        elapsedTime >= targetDuration
    }

    /// 現在の検出品質レベル
    /// 低信頼度または顔未検出の連続フレーム数に応じて品質を判定
    var currentQualityLevel: QualityLevel {
        // 顔未検出が10フレーム以上連続
        if noFaceStreak >= 10 {
            return .noFaceDetected
        }
        // 低信頼度が10フレーム以上連続
        if lowConfidenceStreak >= 10 {
            return .lowConfidence
        }
        return .good
    }

    /// 検出品質レベル
    enum QualityLevel: Sendable {
        /// 良好（高信頼度で検出中）
        case good
        /// 低信頼度（検出されているが信頼度が低い）
        case lowConfidence
        /// 顔未検出（顔が検出されていない）
        case noFaceDetected
    }

    // MARK: - Mutating Methods

    /// フレームの品質レベル
    enum FrameQuality {
        /// 高信頼度（顔が検出され、信頼度が0.5以上）
        case highConfidence
        /// 低信頼度（顔は検出されたが信頼度が0.5未満）
        case lowConfidence
        /// 顔未検出（顔が検出されなかった）
        case noFaceDetected
    }

    /// フレームを追加
    /// - Parameter quality: フレームの品質レベル
    mutating func addFrame(quality: FrameQuality) {
        switch quality {
        case .highConfidence:
            collectedFrames += 1
            lowConfidenceStreak = 0
            noFaceStreak = 0
        case .lowConfidence:
            lowConfidenceStreak += 1
            noFaceStreak = 0
        case .noFaceDetected:
            noFaceStreak += 1
            lowConfidenceStreak = 0
        }
    }

    /// フレームを追加（後方互換性のため）
    /// - Parameter isHighConfidence: 信頼度が0.5以上かどうか
    mutating func addFrame(isHighConfidence: Bool) {
        addFrame(quality: isHighConfidence ? .highConfidence : .lowConfidence)
    }
}
