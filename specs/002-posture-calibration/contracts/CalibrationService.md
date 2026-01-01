# Contract: CalibrationService

**Feature**: 002-posture-calibration

キャリブレーションサービスのインターフェース定義。

## CalibrationServiceProtocol

キャリブレーションの開始・停止・状態管理を担当する。MainActorで実行され、UIからの呼び出しに対応する。

```swift
@MainActor
protocol CalibrationServiceProtocol: AnyObject {
    /// 現在のキャリブレーション状態
    var state: CalibrationState { get }

    /// キャリブレーションを開始する
    ///
    /// - Precondition: state == .notCalibrated || state == .failed(_) || state == .completed
    /// - Postcondition: state == .inProgress(_)
    /// - Throws: CalibrationError.alreadyInProgress if already calibrating
    func startCalibration() async throws

    /// キャリブレーションをキャンセルする
    ///
    /// - Precondition: state == .inProgress(_)
    /// - Postcondition: state == .failed(.cancelled)
    func cancelCalibration()

    /// キャリブレーションをリセットする（保存データも削除）
    ///
    /// - Postcondition: state == .notCalibrated
    /// - Postcondition: CalibrationStorage.referencePosture == nil
    func resetCalibration()

    /// 新しい姿勢フレームを処理する
    ///
    /// - Parameter pose: 検出された姿勢データ
    /// - Note: キャリブレーション中のみ有効。それ以外の状態では無視される。
    func processFrame(_ pose: BodyPose)
}
```

## CalibrationError

キャリブレーションエラーの列挙型。

```swift
enum CalibrationError: Error, LocalizedError {
    case alreadyInProgress
    case noPersonDetected
    case lowConfidence
    case insufficientFrames

    var errorDescription: String? {
        switch self {
        case .alreadyInProgress:
            return "キャリブレーションは既に実行中です"
        case .noPersonDetected:
            return "人物が検出されませんでした"
        case .lowConfidence:
            return "姿勢の検出精度が低い状態が続きました"
        case .insufficientFrames:
            return "十分なデータを収集できませんでした"
        }
    }
}
```

## CalibrationDelegate (Optional)

キャリブレーションイベントのデリゲート。Combine/async-awaitを使う場合は不要。

```swift
@MainActor
protocol CalibrationDelegate: AnyObject {
    /// キャリブレーション状態が変化した
    func calibrationService(_ service: CalibrationServiceProtocol, didChangeState state: CalibrationState)

    /// キャリブレーション進捗が更新された
    func calibrationService(_ service: CalibrationServiceProtocol, didUpdateProgress progress: Double)

    /// キャリブレーションが完了した
    func calibrationService(_ service: CalibrationServiceProtocol, didCompleteWith referencePosture: ReferencePosture)

    /// キャリブレーションが失敗した
    func calibrationService(_ service: CalibrationServiceProtocol, didFailWith failure: CalibrationFailure)
}
```
