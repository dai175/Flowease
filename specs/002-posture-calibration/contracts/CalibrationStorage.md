# Contract: CalibrationStorage

**Feature**: 002-posture-calibration

キャリブレーションデータの永続化インターフェース定義。

## CalibrationStorageProtocol

UserDefaultsを使用して基準姿勢データを保存・読み込みする。テスト時にはモック実装に差し替え可能。

```swift
protocol CalibrationStorageProtocol {
    /// 保存された基準姿勢を取得
    ///
    /// - Returns: 保存されている基準姿勢、未保存の場合はnil
    func loadReferencePosture() -> ReferencePosture?

    /// 基準姿勢を保存
    ///
    /// - Parameter referencePosture: 保存する基準姿勢
    /// - Returns: 保存に成功した場合true
    @discardableResult
    func saveReferencePosture(_ referencePosture: ReferencePosture) -> Bool

    /// 保存された基準姿勢を削除
    func deleteReferencePosture()

    /// キャリブレーションが完了しているかどうか
    /// （referencePostureの有無から導出）
    var isCalibrated: Bool { get }

    /// 最後にキャリブレーションが完了した日時
    /// （referencePosture?.calibratedAtから導出）
    var lastCalibratedAt: Date? { get }
}
```

## Storage Keys

ストレージキーの定数。

```swift
enum CalibrationStorageKeys {
    /// ReferencePostureのJSON保存用キー（唯一の永続化データ）
    static let referencePosture = "flowease.calibration.referencePosture"
}
```

## State Derivation

CalibrationStateは永続化せず、`referencePosture` の有無から導出する:

- `isCalibrated`: `loadReferencePosture() != nil`
- `lastCalibratedAt`: `loadReferencePosture()?.calibratedAt`

`inProgress` / `failed` は一時的な状態であり、アプリ再起動後は自動的に `notCalibrated` または `completed` に復帰する。
