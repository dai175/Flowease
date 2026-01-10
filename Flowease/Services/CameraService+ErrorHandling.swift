// CameraService+ErrorHandling.swift
// Flowease
//
// CameraService のエラーハンドリング関連の extension

@preconcurrency import AVFoundation
import OSLog

// MARK: - CameraService + Error Handling

extension CameraService {
    /// セッションでランタイムエラーが発生した時に呼ばれる
    ///
    /// カメラが他のアプリで使用中の場合や、デバイスエラーが発生した場合に発火する。
    /// macOS では wasInterruptedNotification が利用できないため、この通知でエラーを検出する。
    /// 選択されたカメラが失敗した場合は、システムデフォルトカメラへのフォールバックを試みる。
    @objc func sessionRuntimeError(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let error = userInfo[AVCaptureSessionErrorKey] as? AVError else {
            return
        }

        Task { @MainActor [weak self] in
            guard let self else { return }

            // エラーの内容をログ出力
            logger.warning("Camera session error: code=\(error.code.rawValue), \(error.localizedDescription)")

            // エラーコードに基づいて適切な CameraServiceError を決定
            let cameraError: CameraServiceError = switch error.code {
            case .deviceInUseByAnotherApplication:
                // 他のアプリがカメラを使用中
                .cameraInUse
            default:
                // その他のエラー（セッション設定エラーとして扱う）
                .sessionConfigurationFailed
            }

            // フォールバック判定用に現在のカメラIDを保存（クリーンアップ前に）
            let failedCameraID = currentCameraID

            // セッションをクリーンアップ
            cleanupSessionAfterError()

            // フォールバック試行: 選択されたカメラが失敗し、まだフォールバックを試みていない場合
            let defaultCamera = AVCaptureDevice.default(for: .video)
            let canFallback = !isAttemptingFallback
                && selectedCameraID != nil
                && failedCameraID == selectedCameraID
                && defaultCamera != nil
                && defaultCamera?.uniqueID != selectedCameraID

            if canFallback {
                logger.info("Selected camera failed, attempting fallback to system default")
                isAttemptingFallback = true

                // フォールバック: システムデフォルトカメラで再試行
                // selectedCameraID はそのまま維持（ユーザーの設定を保持）
                // 一時的に nil を使って開始し、デフォルトカメラを使用
                let savedSelectedID = selectedCameraID
                UserDefaults.standard.removeObject(forKey: Self.selectedCameraKey)

                startCapturing()

                isAttemptingFallback = false

                // フォールバックが成功したかチェック
                if isCapturing {
                    logger.info("Fallback to system default camera succeeded")
                    // selectedCameraID を nil に更新（UIに正しいカメラが表示される）
                    selectedCameraID = nil
                    // フォールバック成功を通知
                    frameDelegate?.cameraService(self, didEncounterError: CameraServiceError.selectedCameraFailed)
                    return
                } else {
                    // フォールバックも失敗した場合、元の設定を復元
                    if let savedSelectedID {
                        UserDefaults.standard.set(savedSelectedID, forKey: Self.selectedCameraKey)
                    }
                    logger.error("Fallback to system default camera also failed")
                }
            }

            // フォールバックできない、またはフォールバックも失敗した場合
            frameDelegate?.cameraService(self, didEncounterError: cameraError)
        }
    }

    /// エラー発生後のセッションクリーンアップ
    func cleanupSessionAfterError() {
        guard let session = captureSession else { return }

        isCapturing = false
        captureSession = nil
        videoOutput = nil
        captureInput = nil
        currentCameraID = nil
        frameCounter.withLock { $0 = 0 }

        NotificationCenter.default.removeObserver(
            self,
            name: AVCaptureSession.runtimeErrorNotification,
            object: session
        )

        // バックグラウンドでセッションを停止
        captureQueue.async {
            session.stopRunning()
        }

        logger.info("Session cleaned up after error")
    }
}
