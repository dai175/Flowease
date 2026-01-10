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
- `Models/` - Data models (PostureScore, FacePosition, FaceReferencePosture, MonitoringState, etc.)
- `ViewModels/` - View models for state management
- `Views/` - SwiftUI views (StatusMenuView, CameraPermissionView, CalibrationView)
- `Services/` - Business logic (CameraService, PostureAnalyzer, FaceDetector, FaceScoreCalculator, CalibrationService)
- `Utilities/` - Helper functions (ColorGradient)

## Language

- Code: English
- Comments/Documentation: Japanese acceptable
- Respond in Japanese

## Technologies

- **UI**: Swift 6.0 + SwiftUI
- **Camera**: AVFoundation (video capture, CMSampleBuffer)
- **Face Detection**: Vision framework (VNDetectFaceRectanglesRequest, VNDetectFaceCaptureQualityRequest)
- **Persistence**: UserDefaults (calibration data)

## Features

- **姿勢スコア表示**: カメラ映像から顔の位置・大きさ・傾きをリアルタイムで分析し、0〜100のスコアで評価
- **姿勢キャリブレーション**: ユーザー個人の「良い姿勢」を基準として登録し、パーソナライズされた評価を提供
- **メニューバー常駐**: Dockに表示されず、メニューバーからのみアクセス可能
- **色グラデーション**: スコアに応じてアイコンの色が変化（緑=良好、赤=要改善）
- **エッジケース対応**: カメラ利用不可、顔未検出時はグレーアイコンで表示
- **カメラ選択**: 複数カメラから使用するカメラを選択、切断・再接続を自動処理

## Localization

- UI strings: Localized via String Catalog (`Localizable.xcstrings`)
- Supported languages: English (base), Japanese
- Logger messages: English only (not localized)
- Date formatting: System locale via `DateFormatter`
