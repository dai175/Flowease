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

    /// キャプチャセッションの設定
    var session: AVCaptureSession? {
        didSet {
            guard session !== oldValue else { return }
            previewLayer.session = session
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

    override func layout() {
        super.layout()
        previewLayer.frame = bounds

        // レイアウト時にミラーリング設定を確認（セッション接続後に connection が利用可能になるため）
        if let connection = previewLayer.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }
    }
}
