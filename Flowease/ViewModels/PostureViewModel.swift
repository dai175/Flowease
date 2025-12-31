//
//  PostureViewModel.swift
//  Flowease
//
//  姿勢監視状態を管理する ViewModel
//

import Foundation
import Observation
import OSLog

// MARK: - PostureViewModel

/// 姿勢監視の状態を管理する ViewModel
///
/// カメラ権限の確認・要求と監視状態の更新を担当する。
/// SwiftUI ビューは `monitoringState` を監視して UI を更新する。
@MainActor
@Observable
final class PostureViewModel {
    // MARK: - Published State

    /// 現在の監視状態
    private(set) var monitoringState: MonitoringState = .paused(.cameraInitializing)

    /// スコア履歴 (スムージング用、最大10件)
    private(set) var scoreHistory: [PostureScore] = []

    // MARK: - Dependencies

    private let cameraService: CameraServiceProtocol
    private let logger = Logger(subsystem: "cc.focuswave.Flowease", category: "PostureViewModel")

    // MARK: - Constants

    /// スコア履歴の最大保持件数
    private let maxScoreHistoryCount = 10

    // MARK: - Computed Properties

    /// 平滑化されたスコア
    ///
    /// スコア履歴の移動平均を返す。履歴が空の場合は 0 を返す。
    var smoothedScore: Int {
        guard !scoreHistory.isEmpty else { return 0 }
        let sum = scoreHistory.reduce(0) { $0 + $1.value }
        return sum / scoreHistory.count
    }

    // MARK: - Initialization

    /// イニシャライザ
    ///
    /// - Parameter cameraService: カメラサービス（依存注入によりテスト可能）
    init(cameraService: CameraServiceProtocol) {
        self.cameraService = cameraService
        logger.debug("PostureViewModel 初期化完了")
    }

    /// 本番用イニシャライザ
    ///
    /// デフォルトの `CameraService` を使用する。
    convenience init() {
        self.init(cameraService: CameraService())
    }

    // MARK: - Public Methods

    /// 初期化処理
    ///
    /// アプリ起動時に呼び出し、カメラ権限を確認して監視状態を更新する。
    /// 権限が未決定の場合は自動的にリクエストする。
    func initialize() async {
        logger.info("PostureViewModel 初期化開始")

        // カメラデバイス・権限チェック
        updateMonitoringState()

        // 権限が未決定の場合はリクエスト
        if cameraService.authorizationStatus == .notDetermined {
            logger.info("カメラ権限をリクエスト中...")
            _ = await cameraService.requestAuthorization()
            updateMonitoringState()
        }

        logger.info("PostureViewModel 初期化完了: \(String(describing: monitoringState))")
    }

    /// 監視状態を更新
    ///
    /// カメラサービスの現在の状態に基づいて `monitoringState` を更新する。
    /// active 状態の場合は維持される（スコアが追加されたら active になり、
    /// 明示的に変更されない限り維持）。
    func updateMonitoringState() {
        // active 状態の場合は維持
        if case .active = monitoringState {
            return
        }

        let newState = cameraService.toMonitoringState()

        // 状態が変化した場合のみログ出力
        if monitoringState != newState {
            logger.debug("監視状態更新: \(String(describing: monitoringState)) → \(String(describing: newState))")
        }

        monitoringState = newState
    }

    /// スコアを追加
    ///
    /// 新しいスコアを履歴に追加し、監視状態を `active` に更新する。
    /// 履歴が最大件数を超えた場合は古いものから削除する。
    ///
    /// - Parameter score: 追加する姿勢スコア
    func addScore(_ score: PostureScore) {
        scoreHistory.append(score)

        // 最大件数を超えた場合は古いものから削除
        if scoreHistory.count > maxScoreHistoryCount {
            scoreHistory.removeFirst()
        }

        // 状態を active に更新
        monitoringState = .active(score)
        logger.debug("スコア追加: \(score.value), 平滑化スコア: \(smoothedScore)")
    }

    /// スコア履歴をクリア
    ///
    /// 監視が中断された場合などに呼び出す。
    func clearScoreHistory() {
        scoreHistory.removeAll()
        logger.debug("スコア履歴をクリア")
    }
}
