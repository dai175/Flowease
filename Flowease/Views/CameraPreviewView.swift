//
//  CameraPreviewView.swift
//  Flowease
//
//  カメラプレビューを表示する NSViewRepresentable ラッパー
//

@preconcurrency import AVFoundation
import SwiftUI

// MARK: - CameraPreviewView

/// カメラのライブプレビューを表示するビュー
///
/// `AVCaptureVideoPreviewLayer` を `NSViewRepresentable` でラップし、
/// ミラーリング表示とアスペクトフィルでプレビューを表示する。
struct CameraPreviewView: NSViewRepresentable {
    /// キャプチャセッション
    let session: AVCaptureSession?

    func makeNSView(context _: Context) -> CameraPreviewNSView {
        let view = CameraPreviewNSView()
        view.session = session
        return view
    }

    func updateNSView(_ nsView: CameraPreviewNSView, context _: Context) {
        nsView.session = session
    }
}

// MARK: - CameraPreviewNSView

/// AVCaptureVideoPreviewLayer をホストする NSView
final class CameraPreviewNSView: NSView {
    /// プレビューレイヤー
    private let previewLayer = AVCaptureVideoPreviewLayer()

    /// connection 監視用 KVO
    private var connectionObservation: NSKeyValueObservation?

    /// observation の世代管理（セッション再切替時の競合防止）
    private var observationGeneration: Int = 0

    /// キャプチャセッションの設定
    var session: AVCaptureSession? {
        didSet {
            guard session !== oldValue else { return }
            previewLayer.session = session
            observeConnection()
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupLayer()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayer() {
        wantsLayer = true
        previewLayer.videoGravity = .resizeAspect
        layer = previewLayer
    }

    deinit {
        connectionObservation?.invalidate()
    }

    override func layout() {
        super.layout()
        previewLayer.frame = bounds

        // フォールバック: layout 時にもミラーリングを確認
        if let connection = previewLayer.connection {
            configureMirroring(for: connection)
        }
    }

    /// connection の確立を監視し、ミラーリングを設定する
    private func observeConnection() {
        connectionObservation?.invalidate()
        connectionObservation = nil

        // すでに connection がある場合は即座に設定
        if let connection = previewLayer.connection {
            configureMirroring(for: connection)
            return
        }

        // connection が未確立の場合は KVO で監視
        observationGeneration += 1
        let generation = observationGeneration
        connectionObservation = previewLayer.observe(\.connection, options: [.new]) { [weak self] layer, _ in
            Task { @MainActor in
                guard let self, let connection = layer.connection else { return }
                self.configureMirroring(for: connection)
                // セッション再切替で世代が変わっていない場合のみ解除
                if self.observationGeneration == generation {
                    self.connectionObservation?.invalidate()
                    self.connectionObservation = nil
                }
            }
        }
    }

    /// ミラーリングを設定する
    private func configureMirroring(for connection: AVCaptureConnection) {
        guard connection.isVideoMirroringSupported else { return }
        connection.automaticallyAdjustsVideoMirroring = false
        connection.isVideoMirrored = true
    }
}
