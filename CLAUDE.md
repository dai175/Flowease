# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Flowease is a macOS menu bar application built with SwiftUI. Target: macOS 14.6+, Swift 6.0.

## Development Commands

```bash
make build          # Build the project
make test           # Run all tests
make lint           # Run SwiftLint
make format         # Run SwiftFormat
make fix            # Format + lint
make setup          # Install pre-commit hooks
```

## Code Style Rules

- Use `Logger` or `os_log` instead of `print()` (enforced by SwiftLint)
- Avoid force unwrapping (`!`) - use optional binding or guard
- Avoid implicitly unwrapped optionals (`String!`)
- Line length: 120 (warning), 150 (error)
- Function body: max 50 lines (warning)

## Architecture

SwiftUI App with MVVM architecture for macOS menu bar:
- `Models/` - Data models (PostureScore, BodyPose, MonitoringState, etc.)
- `ViewModels/` - View models for state management
- `Views/` - SwiftUI views (StatusMenuView, CameraPermissionView)
- `Services/` - Business logic (CameraService, PostureAnalyzer, ScoreCalculator)
- `Utilities/` - Helper functions (ColorGradient)

## Language

- Code: English
- Comments/Documentation: Japanese acceptable
- Respond in Japanese

## Technologies

- **UI**: Swift 6.0 + SwiftUI
- **Camera**: AVFoundation (video capture, CMSampleBuffer)
- **Pose Detection**: Vision framework (VNDetectHumanBodyPoseRequest)
- **Persistence**: UserDefaults (calibration data)

## Features

- **姿勢スコア表示**: カメラ映像からリアルタイムで姿勢を分析し、0〜100のスコアで評価
- **姿勢キャリブレーション**: ユーザー個人の「良い姿勢」を基準として登録し、パーソナライズされた評価を提供
- **メニューバー常駐**: Dockに表示されず、メニューバーからのみアクセス可能
- **色グラデーション**: スコアに応じてアイコンの色が変化（緑=良好、赤=要改善）
- **エッジケース対応**: カメラ利用不可、人物未検出時はグレーアイコンで表示

## Active Technologies
- Swift 6.0 + Vision Framework (VNDetectFaceRectanglesRequest, VNDetectFaceCaptureQualityRequest), AVFoundation, SwiftUI (003-face-detection)
- UserDefaults (既存のCalibrationStorage経由) (003-face-detection)

## Recent Changes
- 003-face-detection: Added Swift 6.0 + Vision Framework (VNDetectFaceRectanglesRequest, VNDetectFaceCaptureQualityRequest), AVFoundation, SwiftUI
