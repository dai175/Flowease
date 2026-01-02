import Foundation
import OSLog

/// キャリブレーション画面のViewModel
///
/// CalibrationServiceをラップし、UIからの操作を提供する。
/// キャリブレーションの開始・キャンセル・状態監視を担当。
@MainActor
@Observable
final class CalibrationViewModel {
    // MARK: - Published State

    /// 現在のキャリブレーション状態
    var state: CalibrationState {
        calibrationService.state
    }

    /// キャリブレーション進捗（0.0〜1.0）
    /// 実行中でない場合は0を返す
    var progress: Double {
        state.progress?.progress ?? 0
    }

    /// 残り秒数
    /// 実行中でない場合は0を返す
    var remainingSeconds: Double {
        state.progress?.remainingSeconds ?? 0
    }

    /// 現在の検出品質レベル
    /// 実行中でない場合は.goodを返す
    var qualityLevel: CalibrationProgress.QualityLevel {
        state.progress?.currentQualityLevel ?? .good
    }

    /// 検出品質に応じた警告メッセージ
    /// 問題がない場合はnilを返す
    var qualityWarningMessage: String? {
        guard isInProgress else { return nil }

        switch qualityLevel {
        case .good:
            return nil
        case .lowConfidence:
            return "姿勢の検出精度が低下しています"
        case .noPersonDetected:
            return "カメラに上半身が映っていることを確認してください"
        }
    }

    /// キャリブレーション済みかどうか
    var isCalibrated: Bool {
        state.isCompleted
    }

    /// キャリブレーション実行中かどうか
    var isInProgress: Bool {
        state.isInProgress
    }

    /// 基準姿勢
    var referencePosture: ReferencePosture? {
        calibrationService.referencePosture
    }

    // MARK: - Error State

    /// 最後のエラーメッセージ（表示用）
    private(set) var errorMessage: String?

    /// エラーを表示中かどうか
    var showError: Bool {
        errorMessage != nil
    }

    // MARK: - Dependencies

    /// キャリブレーションサービス
    private let calibrationService: CalibrationServiceProtocol

    /// ロガー
    private let logger = Logger(subsystem: "cc.focuswave.Flowease", category: "CalibrationViewModel")

    // MARK: - Initialization

    /// イニシャライザ
    /// - Parameter calibrationService: キャリブレーションサービス
    init(calibrationService: CalibrationServiceProtocol) {
        self.calibrationService = calibrationService
        logger.debug("CalibrationViewModel 初期化完了")
    }

    // MARK: - Public Methods

    /// キャリブレーションを開始
    ///
    /// 既に実行中の場合はエラーを設定する。
    func startCalibration() async {
        errorMessage = nil

        do {
            try await calibrationService.startCalibration()
            logger.info("キャリブレーション開始")
        } catch let error as CalibrationError {
            errorMessage = error.localizedDescription
            logger.warning("キャリブレーション開始失敗: \(error.localizedDescription)")
        } catch {
            errorMessage = "予期しないエラーが発生しました"
            logger.error("キャリブレーション開始で予期しないエラー: \(error.localizedDescription)")
        }
    }

    /// キャリブレーションをキャンセル
    func cancelCalibration() {
        calibrationService.cancelCalibration()
        logger.info("キャリブレーションをキャンセル")
    }

    /// キャリブレーションをリセット（基準姿勢を削除）
    ///
    /// 保存された基準姿勢を削除し、固定しきい値モードに戻る。
    func resetCalibration() {
        calibrationService.resetCalibration()
        logger.info("キャリブレーションをリセット")
    }

    /// エラーメッセージをクリア
    func clearError() {
        errorMessage = nil
    }

    /// 状態説明テキストを取得
    var statusText: String {
        switch state {
        case .notCalibrated:
            return "キャリブレーション未設定"
        case .inProgress:
            let seconds = Int(ceil(remainingSeconds))
            return "キャリブレーション中... 残り\(seconds)秒"
        case .completed:
            return "キャリブレーション完了"
        case let .failed(failure):
            return failure.userMessage
        }
    }

    // MARK: - Status Display Properties

    /// キャリブレーション推奨メッセージ
    /// 未キャリブレーション時かつ実行中でない場合にユーザーに推奨を表示するためのテキスト
    var recommendationMessage: String? {
        guard shouldShowRecommendation else { return nil }
        return "キャリブレーションを設定すると、より正確な姿勢評価ができます"
    }

    /// 推奨メッセージを表示すべきかどうか
    var shouldShowRecommendation: Bool {
        !isCalibrated && !isInProgress
    }

    /// キャリブレーション完了日時のフォーマット済みテキスト
    var calibratedAtText: String? {
        guard let date = referencePosture?.calibratedAt else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }

    /// キャリブレーション状態の短い説明
    var statusSummary: String {
        if isCalibrated {
            if let dateText = calibratedAtText {
                return "完了 (\(dateText))"
            }
            return "完了"
        } else {
            return "未設定"
        }
    }
}
