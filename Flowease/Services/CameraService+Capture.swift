// CameraService+Capture.swift
// Flowease
//
// CameraService のフレームキャプチャ関連の extension

@preconcurrency import AVFoundation
import OSLog

// MARK: - SendableSampleBuffer

/// CMSampleBuffer を Sendable としてラップするヘルパー
///
/// CMSampleBuffer は Core Foundation 型でスレッドセーフではないが、
/// カメラキャプチャからメインスレッドへの受け渡しは即時処理されるため安全。
/// nonisolated により非同期コンテキストからもアクセス可能。
nonisolated struct SendableSampleBuffer: @unchecked Sendable {
    let buffer: CMSampleBuffer
}

// MARK: - CameraService + AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from _: AVCaptureConnection
    ) {
        // フレームスキップ（パフォーマンス最適化）
        let shouldProcess = frameCounter.withLock { counter -> Bool in
            counter += 1
            return counter % frameProcessingInterval == 0
        }
        guard shouldProcess else {
            return
        }

        // Sendable ラッパーでメインスレッドに送信
        let sendableBuffer = SendableSampleBuffer(buffer: sampleBuffer)

        // メインスレッドでデリゲートに通知
        Task { @MainActor [weak self] in
            guard let self, isCapturing else { return }
            frameDelegate?.cameraService(self, didCaptureFrame: sendableBuffer.buffer)
        }
    }

    nonisolated func captureOutput(
        _: AVCaptureOutput,
        didDrop _: CMSampleBuffer,
        from _: AVCaptureConnection
    ) {
        // フレームがドロップされた場合は警告ログ（過剰にならないよう制限）
        Task { @MainActor [weak self] in
            self?.logger.debug("Frame dropped")
        }
    }
}
