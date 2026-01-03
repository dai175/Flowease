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

    func deleteFaceReferencePosture() {
        lock.lock()
        defer { lock.unlock() }

        userDefaults.removeObject(forKey: CalibrationStorageKeys.referencePosture)
        logger.info("基準姿勢データを削除しました")
    }

    // MARK: - Auto-Clean on Load

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
