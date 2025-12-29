//
//  PostureDetectionService.swift
//  Flowease
//
//  Created by Daisuke Ooba on 2025/12/29.
//

import AVFoundation
import Combine
import CoreVideo
import Foundation
import Vision

/// 姿勢検知サービスの実装
/// Vision Framework を使用してカメラフレームから姿勢を検知する
public final class PostureDetectionService: PostureDetectionServiceProtocol, PostureDetectionServiceTestable {
    // MARK: - Properties

    /// 姿勢状態の変更を購読するPublisher
    public var posturePublisher: AnyPublisher<PostureState?, Never> {
        postureSubject.eraseToAnyPublisher()
    }

    /// 現在の姿勢状態（同期アクセス用）
    public private(set) var currentPosture: PostureState?

    /// 検知が実行中か
    public private(set) var isDetecting = false

    // MARK: - Private Properties

    /// 姿勢状態の送信用Subject
    private let postureSubject = CurrentValueSubject<PostureState?, Never>(nil)

    /// カメラサービス
    private let cameraService: CameraServiceProtocol

    /// キャンセラブルの保持用
    private var cancellables = Set<AnyCancellable>()

    /// 最後に検知を実行した時刻
    private var lastDetectionTime: Date?

    /// 検知間隔（秒）
    private let detectionInterval: TimeInterval

    /// 前かがみ閾値（度）
    private var forwardLeanThreshold: Double

    /// 首傾き閾値（度）
    private var neckTiltThreshold: Double

    /// 悪い姿勢が続いている開始時刻
    private var badPostureStartTime: Date?

    /// 処理用のキュー
    private let processingQueue = DispatchQueue(
        label: "cc.focuswave.Flowease.PostureDetectionService.processing"
    )

    // MARK: - Initialization

    /// 初期化
    /// - Parameter cameraService: カメラサービス
    public init(cameraService: CameraServiceProtocol) {
        self.cameraService = cameraService
        detectionInterval = Constants.PostureDetection.detectionInterval
        forwardLeanThreshold = Constants.PostureDetection.defaultForwardLeanThreshold
        neckTiltThreshold = Constants.PostureDetection.defaultNeckTiltThreshold
    }

    // MARK: - PostureDetectionServiceProtocol

    /// 姿勢検知を開始
    /// - Parameter cameraDeviceID: 使用するカメラのデバイスID（nilの場合は自動選択）
    /// - Throws: カメラアクセスエラー、Vision Frameworkエラー
    public func startDetection(cameraDeviceID: String?) async throws {
        // 既に実行中の場合はエラー
        if isDetecting {
            throw PostureDetectionError.alreadyRunning
        }

        // カメラの権限確認
        let authStatus = await cameraService.checkAuthorization()
        guard authStatus == .authorized || authStatus == .notDetermined else {
            throw PostureDetectionError.cameraAccessDenied
        }

        // カメラを開始
        do {
            try await cameraService.startCamera(deviceID: cameraDeviceID)
        } catch let error as CameraError {
            switch error {
            case .accessDenied:
                throw PostureDetectionError.cameraAccessDenied
            case let .deviceNotFound(deviceID):
                throw PostureDetectionError.cameraNotFound
            default:
                throw PostureDetectionError.visionFrameworkError(error)
            }
        }

        // フレームの購読を開始
        subscribeToFrames()

        isDetecting = true
    }

    /// 姿勢検知を停止
    public func stopDetection() {
        cancellables.removeAll()
        cameraService.stopCamera()
        isDetecting = false
        lastDetectionTime = nil
        badPostureStartTime = nil
    }

    /// 姿勢判定の閾値を更新
    /// - Parameters:
    ///   - forwardLeanThreshold: 前かがみ閾値（度）
    ///   - neckTiltThreshold: 首傾き閾値（度）
    public func updateThresholds(forwardLeanThreshold: Double, neckTiltThreshold: Double) {
        self.forwardLeanThreshold = forwardLeanThreshold
        self.neckTiltThreshold = neckTiltThreshold
    }

    // MARK: - PostureDetectionServiceTestable

    /// 単一フレームから姿勢を検知（テスト用）
    /// - Parameter pixelBuffer: カメラからのフレーム
    /// - Returns: 検知結果
    public func detectPosture(from pixelBuffer: CVPixelBuffer) async throws -> PostureState {
        try await withCheckedThrowingContinuation { continuation in
            processingQueue.async { [weak self] in
                guard let self else {
                    continuation.resume(returning: PostureState.notDetected)
                    return
                }

                do {
                    let state = try self.performPoseDetection(on: pixelBuffer)
                    continuation.resume(returning: state)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Private Methods

    /// フレームの購読を開始
    private func subscribeToFrames() {
        cameraService.framePublisher
            .receive(on: processingQueue)
            .sink { [weak self] pixelBuffer in
                self?.processFrame(pixelBuffer)
            }
            .store(in: &cancellables)
    }

    /// フレームを処理
    private func processFrame(_ pixelBuffer: CVPixelBuffer) {
        // 検知間隔をチェック
        guard shouldPerformDetection() else {
            return
        }

        lastDetectionTime = Date()

        do {
            let state = try performPoseDetection(on: pixelBuffer)
            updatePostureState(state)
        } catch {
            // エラー時は未検出状態を送信
            updatePostureState(PostureState.notDetected)
        }
    }

    /// 検知を実行すべきかチェック
    private func shouldPerformDetection() -> Bool {
        guard let lastTime = lastDetectionTime else {
            return true
        }

        let elapsed = Date().timeIntervalSince(lastTime)
        return elapsed >= detectionInterval
    }

    /// Vision Framework を使用して姿勢を検知
    private func performPoseDetection(on pixelBuffer: CVPixelBuffer) throws -> PostureState {
        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])

        try handler.perform([request])

        guard let observation = request.results?.first else {
            return PostureState.notDetected
        }

        return calculatePostureState(from: observation)
    }

    /// ポーズ観測結果から姿勢状態を計算
    private func calculatePostureState(from observation: VNHumanBodyPoseObservation) -> PostureState {
        // 必要なジョイントポイントを取得
        guard let nosePoint = getJointPoint(observation, joint: .nose),
              let neckPoint = getJointPoint(observation, joint: .neck),
              let rootPoint = getJointPoint(observation, joint: .root)
        else {
            return PostureState.notDetected
        }

        // 前かがみ角度を計算
        let forwardLeanAngle = calculateForwardLeanAngle(
            neck: neckPoint,
            root: rootPoint
        )

        // 首の傾き角度を計算
        let neckTiltAngle = calculateNeckTiltAngle(
            nose: nosePoint,
            neck: neckPoint
        )

        // スコアを計算
        let score = calculatePostureScore(
            forwardLeanAngle: forwardLeanAngle,
            neckTiltAngle: neckTiltAngle
        )

        // 悪い姿勢の継続時間を計算
        let badPostureDuration = calculateBadPostureDuration(score: score)

        return PostureState(
            score: score,
            forwardLeanAngle: forwardLeanAngle,
            neckTiltAngle: neckTiltAngle,
            badPostureDuration: badPostureDuration,
            isFaceDetected: true
        )
    }

    /// ジョイントポイントを取得
    private func getJointPoint(
        _ observation: VNHumanBodyPoseObservation,
        joint: VNHumanBodyPoseObservation.JointName
    ) -> CGPoint? {
        guard let recognizedPoint = try? observation.recognizedPoint(joint) else {
            return nil
        }

        // 信頼度チェック
        guard recognizedPoint.confidence > Constants.PostureDetection.confidenceThreshold else {
            return nil
        }

        return CGPoint(x: recognizedPoint.location.x, y: recognizedPoint.location.y)
    }

    /// 前かがみ角度を計算
    private func calculateForwardLeanAngle(neck: CGPoint, root: CGPoint) -> Double {
        // 首から腰までのベクトル
        let spineVector = CGPoint(x: root.x - neck.x, y: root.y - neck.y)

        // 垂直ベクトルとの角度を計算
        let angle = atan2(spineVector.x, spineVector.y) * 180 / .pi

        return abs(angle)
    }

    /// 首の傾き角度を計算
    private func calculateNeckTiltAngle(nose: CGPoint, neck: CGPoint) -> Double {
        // 首から鼻までのベクトル
        let headVector = CGPoint(x: nose.x - neck.x, y: nose.y - neck.y)

        // 垂直ベクトルとの角度を計算
        let angle = atan2(headVector.x, headVector.y) * 180 / .pi

        return abs(angle)
    }

    /// 姿勢スコアを計算
    private func calculatePostureScore(forwardLeanAngle: Double, neckTiltAngle: Double) -> Double {
        // 閾値に対する超過率を計算
        let forwardLeanRatio = forwardLeanAngle / forwardLeanThreshold
        let neckTiltRatio = neckTiltAngle / neckTiltThreshold

        // スコアを計算（1.0が最良）
        let forwardScore = max(0.0, 1.0 - forwardLeanRatio * 0.5)
        let neckScore = max(0.0, 1.0 - neckTiltRatio * 0.5)

        // 平均スコア
        return (forwardScore + neckScore) / 2.0
    }

    /// 悪い姿勢の継続時間を計算
    private func calculateBadPostureDuration(score: Double) -> TimeInterval {
        let isBadPosture = score < Constants.PostureDetection.ScoreThreshold.warning

        if isBadPosture {
            let startTime = badPostureStartTime ?? Date()
            if badPostureStartTime == nil {
                badPostureStartTime = startTime
            }
            return Date().timeIntervalSince(startTime)
        } else {
            badPostureStartTime = nil
            return 0
        }
    }

    /// 姿勢状態を更新
    private func updatePostureState(_ state: PostureState) {
        currentPosture = state
        DispatchQueue.main.async { [weak self] in
            self?.postureSubject.send(state)
        }
    }
}
