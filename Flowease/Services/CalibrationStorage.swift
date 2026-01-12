// CalibrationStorage.swift
// Flowease
//
// キャリブレーションデータの永続化
//
// ## セキュリティ考慮事項
//
// このクラスは UserDefaults を使用してキャリブレーションデータを保存します。
// Keychain ではなく UserDefaults を選択した理由：
//
// 1. **データの機密性**: 保存されるデータは顔の相対位置情報（baselineY, baselineArea,
//    baselineRoll）であり、個人を特定できる生体認証データではありません。
//
// 2. **用途**: このデータは姿勢スコア計算の基準値として使用されるアプリケーション設定であり、
//    パスワードやトークンのような認証情報ではありません。
//
// 3. **リスク評価**: データが漏洩しても、攻撃者が得られるのは「ユーザーが良い姿勢と
//    設定した時の顔の相対位置」のみであり、セキュリティ上の実害は限定的です。
//
// 4. **Keychain の適切な用途**: Keychain はパスワード、暗号化キー、認証トークン、
//    証明書など、機密性の高いデータの保存に適しています。
//
// 将来、顔認証や生体認証機能を追加する場合は、Keychain への移行を検討してください。

import Foundation
import os.log

// MARK: - CalibrationStorageKeys

/// ストレージキーの定数
enum CalibrationStorageKeys {
    /// ReferencePostureのJSON保存用キー（唯一の永続化データ）
    static let referencePosture = "flowease.calibration.referencePosture"
}

// MARK: - CalibrationStorageProtocol

/// キャリブレーションデータの永続化インターフェース
/// UserDefaultsを使用して基準姿勢データを保存・読み込みする
/// テスト時にはモック実装に差し替え可能
protocol CalibrationStorageProtocol: Sendable {
    /// キャリブレーションが完了しているかどうか
    var isCalibrated: Bool { get }

    /// 最後にキャリブレーションが完了した日時
    var lastCalibratedAt: Date? { get }

    /// 保存された顔ベース基準姿勢を取得
    ///
    /// - Returns: 保存されているFaceReferencePosture、未保存の場合はnil
    func loadFaceReferencePosture() -> FaceReferencePosture?

    /// 保存された顔ベース基準姿勢を取得（自動クリーン付き）
    ///
    /// 顔ベース形式でのデコードに失敗した場合（旧形式または破損データ）、
    /// 自動的にデータをクリアする。
    ///
    /// - Returns: 保存されているFaceReferencePosture、未保存またはクリア済みの場合はnil
    func loadFaceReferencePostureWithAutoClean() -> FaceReferencePosture?

    /// 顔ベース基準姿勢を保存
    ///
    /// - Parameter posture: 保存する顔ベース基準姿勢
    /// - Returns: 保存に成功した場合true
    @discardableResult
    func saveFaceReferencePosture(_ posture: FaceReferencePosture) -> Bool

    /// 保存された顔ベース基準姿勢を削除
    func deleteFaceReferencePosture()
}

// MARK: - CalibrationStorage

/// CalibrationStorageProtocolのUserDefaults実装
/// アプリケーションのキャリブレーションデータを永続化する
///
/// `@unchecked Sendable` の安全性:
/// - `userDefaults`: UserDefaults は内部でスレッドセーフに実装されている
/// - `lock`: NSLock によりすべての読み書き操作が排他制御されている
/// - `logger`: Logger はスレッドセーフ
final class CalibrationStorage: CalibrationStorageProtocol, @unchecked Sendable {
    // MARK: - Private Properties

    /// UserDefaultsインスタンス
    private let userDefaults: UserDefaults

    /// ロガー
    private let logger = Logger.calibrationStorage

    /// スレッドセーフなアクセスのためのロック
    private let lock = NSLock()

    // MARK: - Initializer

    /// イニシャライザ
    /// - Parameter userDefaults: 使用するUserDefaultsインスタンス（テスト時の差し替え用）
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    // MARK: - Private Helpers

    /// ISO8601形式のJSONエンコーダーを作成
    private func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    /// ISO8601形式のJSONデコーダーを作成
    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    // MARK: - CalibrationStorageProtocol

    var isCalibrated: Bool {
        loadFaceReferencePosture() != nil
    }

    var lastCalibratedAt: Date? {
        loadFaceReferencePosture()?.calibratedAt
    }

    func loadFaceReferencePosture() -> FaceReferencePosture? {
        lock.lock()
        defer { lock.unlock() }

        guard let data = userDefaults.data(forKey: CalibrationStorageKeys.referencePosture) else {
            logger.debug("Reference posture data not found")
            return nil
        }

        do {
            let decoder = makeDecoder()
            // 顔ベース形式でデコード試行
            let facePosture = try decoder.decode(FaceReferencePosture.self, from: data)
            logger.debug("Face-based reference posture data loaded (frame count: \(facePosture.frameCount))")
            return facePosture
        } catch {
            // デコード失敗 = 旧形式または破損データ
            logger.debug("Failed to decode face-based format: \(error.localizedDescription)")
            return nil
        }
    }

    @discardableResult
    func saveFaceReferencePosture(_ posture: FaceReferencePosture) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        do {
            let encoder = makeEncoder()
            let data = try encoder.encode(posture)
            userDefaults.set(data, forKey: CalibrationStorageKeys.referencePosture)
            logger.info("Face-based reference posture data saved (frame count: \(posture.frameCount))")
            return true
        } catch {
            logger.error("Failed to encode face-based reference posture data: \(error.localizedDescription)")
            return false
        }
    }

    func deleteFaceReferencePosture() {
        lock.lock()
        defer { lock.unlock() }

        userDefaults.removeObject(forKey: CalibrationStorageKeys.referencePosture)
        logger.info("Reference posture data deleted")
    }

    // MARK: - Auto-Clean on Load

    func loadFaceReferencePostureWithAutoClean() -> FaceReferencePosture? {
        lock.lock()
        defer { lock.unlock() }

        guard let data = userDefaults.data(forKey: CalibrationStorageKeys.referencePosture) else {
            logger.debug("Reference posture data not found")
            return nil
        }

        do {
            let decoder = makeDecoder()
            // 顔ベース形式でデコード試行
            let facePosture = try decoder.decode(FaceReferencePosture.self, from: data)
            logger.debug("Face-based reference posture data loaded (frame count: \(facePosture.frameCount))")
            return facePosture
        } catch {
            // デコード失敗 = 旧形式または破損データ → クリア
            logger.info("Calibration data cleared (format mismatch or corrupted): \(error.localizedDescription)")
            userDefaults.removeObject(forKey: CalibrationStorageKeys.referencePosture)
            return nil
        }
    }
}
