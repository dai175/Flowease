// Logger+Flowease.swift
// Flowease
//
// アプリ共通の Logger 設定

import OSLog

extension Logger {
    /// アプリのバンドル識別子（subsystem）
    private static let subsystem = "cc.focuswave.Flowease"

    // MARK: - Services

    /// CameraService 用ロガー
    static let cameraService = Logger(subsystem: subsystem, category: "CameraService")

    /// CalibrationService 用ロガー
    static let calibrationService = Logger(subsystem: subsystem, category: "CalibrationService")

    /// CalibrationStorage 用ロガー
    static let calibrationStorage = Logger(subsystem: subsystem, category: "CalibrationStorage")

    /// PostureAnalyzer 用ロガー
    static let postureAnalyzer = Logger(subsystem: subsystem, category: "PostureAnalyzer")

    /// FaceDetector 用ロガー
    static let faceDetector = Logger(subsystem: subsystem, category: "FaceDetector")

    /// FaceScoreCalculator 用ロガー
    static let faceScoreCalculator = Logger(subsystem: subsystem, category: "FaceScoreCalculator")

    /// ScoreHistory 用ロガー
    static let scoreHistory = Logger(subsystem: subsystem, category: "ScoreHistory")

    /// PostureAlertService 用ロガー
    static let postureAlertService = Logger(subsystem: subsystem, category: "PostureAlertService")

    /// AlertSettingsStorage 用ロガー
    static let alertSettingsStorage = Logger(subsystem: subsystem, category: "AlertSettingsStorage")

    /// CameraDeviceManager 用ロガー
    static let cameraDeviceManager = Logger(subsystem: subsystem, category: "CameraDeviceManager")

    /// NotificationManager 用ロガー
    static let notificationManager = Logger(subsystem: subsystem, category: "NotificationManager")

    // MARK: - ViewModels

    /// PostureViewModel 用ロガー
    static let postureViewModel = Logger(subsystem: subsystem, category: "PostureViewModel")

    /// CalibrationViewModel 用ロガー
    static let calibrationViewModel = Logger(subsystem: subsystem, category: "CalibrationViewModel")
}
