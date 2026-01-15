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
            return String(localized: "Posture detection quality is low")
        case .noFaceDetected:
            return String(localized: "Please ensure your face is visible to the camera")
        }
    }

    /// キャリブレーション済みかどうか
    /// ストレージにデータがあるかで判定（状態に関係なく）
    var isCalibrated: Bool {
        faceReferencePosture != nil
    }

    /// キャリブレーション実行中かどうか
    var isInProgress: Bool {
        state.isInProgress
    }

    /// 顔ベース基準姿勢
    var faceReferencePosture: FaceReferencePosture? {
        calibrationService.faceReferencePosture
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
    private let logger = Logger.calibrationViewModel

    /// 日付フォーマッター（キャッシュ）
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none // 時刻を省略してコンパクトに表示
        return formatter
    }()

    // MARK: - Initialization

    /// イニシャライザ
    /// - Parameter calibrationService: キャリブレーションサービス
    init(calibrationService: CalibrationServiceProtocol) {
        self.calibrationService = calibrationService
        logger.debug("CalibrationViewModel initialized")
    }

    // MARK: - Public Methods

    /// キャリブレーションを開始
    ///
    /// 既に実行中の場合はエラーを設定する。
    func startCalibration() async {
        errorMessage = nil

        do {
            try await calibrationService.startCalibration()
            logger.info("Calibration started")
        } catch let error as CalibrationError {
            errorMessage = error.localizedDescription
            logger.warning("Failed to start calibration: \(error.localizedDescription)")
        } catch {
            errorMessage = String(localized: "An unexpected error occurred")
            logger.error("Unexpected error starting calibration: \(error.localizedDescription)")
        }
    }

    /// キャリブレーションをキャンセル
    func cancelCalibration() {
        calibrationService.cancelCalibration()
        logger.info("Calibration cancelled")
    }

    /// 再キャリブレーション用にUI状態をリセット
    ///
    /// ウィンドウを開く際に呼び出し、開始画面を表示する。
    /// 既存のキャリブレーションデータは保持される。
    func prepareForRecalibration() {
        calibrationService.prepareForRecalibration()
        errorMessage = nil
        logger.debug("Prepared for recalibration")
    }

    /// キャリブレーションをリセット（基準姿勢を削除）
    ///
    /// 保存された基準姿勢を削除し、固定しきい値モードに戻る。
    /// リセット完了後、`.calibrationReset` 通知を送信する。
    func resetCalibration() {
        calibrationService.resetCalibration()
        NotificationCenter.default.post(name: .calibrationReset, object: nil)
        logger.info("Calibration reset")
    }

    /// エラーメッセージをクリア
    func clearError() {
        errorMessage = nil
    }

    /// 状態説明テキストを取得
    var statusText: String {
        switch state {
        case .notCalibrated:
            return String(localized: "Calibration not configured")
        case .inProgress:
            let seconds = Int(ceil(remainingSeconds))
            return String(localized: "Calibrating... \(seconds) seconds remaining")
        case .completed:
            return String(localized: "Calibration Complete")
        case let .failed(failure):
            return failure.userMessage
        }
    }

    // MARK: - Status Display Properties

    /// キャリブレーション推奨メッセージ
    /// 未キャリブレーション時かつ実行中でない場合にユーザーに推奨を表示するためのテキスト
    var recommendationMessage: String? {
        guard shouldShowRecommendation else { return nil }
        return String(localized: "Configure calibration for more accurate posture assessment")
    }

    /// 推奨メッセージを表示すべきかどうか
    var shouldShowRecommendation: Bool {
        !isCalibrated && !isInProgress
    }

    /// キャリブレーション完了日時のフォーマット済みテキスト
    var calibratedAtText: String? {
        guard let date = faceReferencePosture?.calibratedAt else { return nil }
        return Self.dateFormatter.string(from: date)
    }

    /// キャリブレーション状態の短い説明
    var statusSummary: String {
        if isCalibrated {
            if let dateText = calibratedAtText {
                return String(localized: "Complete (\(dateText))")
            }
            return String(localized: "Complete")
        } else {
            return String(localized: "Not configured")
        }
    }
}
