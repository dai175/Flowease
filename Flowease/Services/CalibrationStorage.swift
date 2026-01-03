// CalibrationStorage.swift
// Flowease
//
// キャリブレーションデータの永続化

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

    // MARK: - Face-Based Calibration (T027-T029, T032-T033)

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
}

// MARK: - CalibrationStorage

/// CalibrationStorageProtocolのUserDefaults実装
/// アプリケーションのキャリブレーションデータを永続化する
final class CalibrationStorage: CalibrationStorageProtocol, @unchecked Sendable {
    // MARK: - Private Properties

    /// UserDefaultsインスタンス
    private let userDefaults: UserDefaults

    /// ロガー
    private let logger = Logger(subsystem: "cc.focuswave.Flowease", category: "CalibrationStorage")

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

    func loadReferencePosture() -> ReferencePosture? {
        lock.lock()
        defer { lock.unlock() }

        guard let data = userDefaults.data(forKey: CalibrationStorageKeys.referencePosture) else {
            logger.debug("基準姿勢データが見つかりません")
            return nil
        }

        do {
            let decoder = makeDecoder()
            let referencePosture = try decoder.decode(ReferencePosture.self, from: data)
            logger.debug("基準姿勢データを読み込みました（フレーム数: \(referencePosture.frameCount)）")
            return referencePosture
        } catch {
            logger.error("基準姿勢データのデコードに失敗: \(error.localizedDescription)")
            return nil
        }
    }

    @discardableResult
    func saveReferencePosture(_ referencePosture: ReferencePosture) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        do {
            let encoder = makeEncoder()
            let data = try encoder.encode(referencePosture)
            userDefaults.set(data, forKey: CalibrationStorageKeys.referencePosture)
            logger.info("基準姿勢データを保存しました（フレーム数: \(referencePosture.frameCount)）")
            return true
        } catch {
            logger.error("基準姿勢データのエンコードに失敗: \(error.localizedDescription)")
            return false
        }
    }

    func deleteReferencePosture() {
        lock.lock()
        defer { lock.unlock() }

        userDefaults.removeObject(forKey: CalibrationStorageKeys.referencePosture)
        logger.info("基準姿勢データを削除しました")
    }

    var isCalibrated: Bool {
        loadFaceReferencePosture() != nil || loadReferencePosture() != nil
    }

    var lastCalibratedAt: Date? {
        loadFaceReferencePosture()?.calibratedAt ?? loadReferencePosture()?.calibratedAt
    }

    // MARK: - Face-Based Calibration (T027-T029)

    func loadFaceReferencePosture() -> FaceReferencePosture? {
        lock.lock()
        defer { lock.unlock() }

        guard let data = userDefaults.data(forKey: CalibrationStorageKeys.referencePosture) else {
            logger.debug("基準姿勢データが見つかりません")
            return nil
        }

        do {
            let decoder = makeDecoder()
            // 顔ベース形式でデコード試行
            let facePosture = try decoder.decode(FaceReferencePosture.self, from: data)
            logger.debug("顔ベース基準姿勢データを読み込みました（フレーム数: \(facePosture.frameCount)）")
            return facePosture
        } catch {
            // デコード失敗 = 旧形式または破損データ
            logger.debug("顔ベース形式でのデコード失敗: \(error.localizedDescription)")
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
            logger.info("顔ベース基準姿勢データを保存しました（フレーム数: \(posture.frameCount)）")
            return true
        } catch {
            logger.error("顔ベース基準姿勢データのエンコードに失敗: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - T032: Auto-Clean on Load

    func loadFaceReferencePostureWithAutoClean() -> FaceReferencePosture? {
        lock.lock()
        defer { lock.unlock() }

        guard let data = userDefaults.data(forKey: CalibrationStorageKeys.referencePosture) else {
            logger.debug("基準姿勢データが見つかりません")
            return nil
        }

        do {
            let decoder = makeDecoder()
            // 顔ベース形式でデコード試行
            let facePosture = try decoder.decode(FaceReferencePosture.self, from: data)
            logger.debug("顔ベース基準姿勢データを読み込みました（フレーム数: \(facePosture.frameCount)）")
            return facePosture
        } catch {
            // デコード失敗 = 旧形式または破損データ → クリア
            logger.info("キャリブレーションデータをクリア（形式不一致または破損）: \(error.localizedDescription)")
            userDefaults.removeObject(forKey: CalibrationStorageKeys.referencePosture)
            return nil
        }
    }
}
