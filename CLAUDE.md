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

SwiftUI App with standard macOS structure:
- `FloweaseApp.swift` - App entry point (`@main`)
- `ContentView.swift` - Main view

## Language

- Code: English
- Comments/Documentation: Japanese acceptable
- Respond in Japanese

## Active Technologies
- Swift 6.0 + SwiftUI, AVFoundation (カメラキャプチャ), Vision (姿勢検出/ボディポーズ推定) (001-posture-score)
- N/A（永続化不要、インメモリ状態管理のみ） (001-posture-score)

## Recent Changes
- 001-posture-score: Added Swift 6.0 + SwiftUI, AVFoundation (カメラキャプチャ), Vision (姿勢検出/ボディポーズ推定)
