# Quickstart: 姿勢スコア表示機能

**Feature**: 001-posture-score
**Date**: 2025-12-30

## Prerequisites

- macOS 14.6+
- Xcode 16.0+ (Swift 6.0)
- 内蔵カメラまたは USB 接続の Web カメラ

## Setup

### 1. リポジトリのセットアップ

```bash
# リポジトリをクローン
git clone <repository-url>
cd Flowease

# feature ブランチに切り替え
git checkout 001-posture-score

# 開発環境のセットアップ
make setup
```

### 2. Xcode でプロジェクトを開く

```bash
open Flowease.xcodeproj
```

### 3. Info.plist の確認

以下のキーが設定されていることを確認:

```xml
<!-- カメラ権限の説明 -->
<key>NSCameraUsageDescription</key>
<string>姿勢をモニタリングするためにカメラを使用します</string>

<!-- Dock アイコンを非表示 -->
<key>LSUIElement</key>
<true/>
```

## Build & Run

### コマンドラインからビルド

```bash
make build
```

### Xcode からビルド

1. Scheme: `Flowease` を選択
2. Destination: `My Mac` を選択
3. `Cmd + R` で実行

## First Run

1. **アプリ起動**: メニューバーに姿勢アイコンが表示される
2. **カメラ許可**: 初回起動時にカメラアクセス許可ダイアログが表示される
   - 「許可」を選択 → 姿勢監視開始
   - 「拒否」を選択 → グレーアイコン + 設定誘導メッセージ
3. **姿勢確認**: カメラの前で姿勢を変えて、アイコン色の変化を確認
4. **終了**: メニューから「終了」を選択

## Testing

### ユニットテスト

```bash
make test
```

### 特定のテストを実行

```bash
xcodebuild test \
  -scheme Flowease \
  -destination 'platform=macOS' \
  -only-testing:FloweaseTests/ScoreCalculatorTests
```

## Code Quality

### リント & フォーマット

```bash
# フォーマット + リント
make fix

# リントのみ
make lint

# フォーマットのみ
make format
```

## Key Files

### アプリケーション

| ファイル | 説明 |
|---------|------|
| `Flowease/FloweaseApp.swift` | アプリエントリポイント、MenuBarExtra 設定 |
| `Flowease/ViewModels/PostureViewModel.swift` | 姿勢監視の状態管理 |
| `Flowease/Services/CameraService.swift` | AVFoundation カメラ制御 |
| `Flowease/Services/PostureAnalyzer.swift` | Vision 姿勢分析 |
| `Flowease/Services/ScoreCalculator.swift` | スコア算出ロジック |

### テスト

| ファイル | 説明 |
|---------|------|
| `FloweaseTests/ScoreCalculatorTests.swift` | スコア算出のユニットテスト |
| `FloweaseTests/MonitoringStateTests.swift` | 状態遷移のテスト |

## Debugging

### ログの確認

Console.app を開き、Flowease で検索:

```
subsystem:com.example.Flowease
```

### カメラが動作しない場合

1. システム設定 > プライバシーとセキュリティ > カメラ を確認
2. Flowease にチェックが入っているか確認
3. チェックがない場合は追加して、アプリを再起動

### 姿勢が検出されない場合

- カメラが正しい方向を向いているか確認
- 十分な照明があるか確認
- 上半身がカメラに映っているか確認 (頭〜肩が必須)

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                    FloweaseApp                          │
│  (MenuBarExtra - SwiftUI Scene)                         │
└───────────────────────┬─────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────┐
│               PostureViewModel (@Observable)            │
│  - monitoringState: MonitoringState                     │
│  - iconColor: IconColor                                 │
└───────────────────────┬─────────────────────────────────┘
                        │
        ┌───────────────┼───────────────┐
        ▼               ▼               ▼
┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│CameraService│  │PostureAnalyzer│ │ScoreCalculator│
│(AVFoundation)│  │  (Vision)    │  │  (Algorithm) │
└─────────────┘  └─────────────┘  └─────────────┘
        │               │               │
        │   CVPixelBuffer               │
        └───────────────┘               │
                │                       │
                ▼                       │
        ┌─────────────┐                │
        │  BodyPose   │────────────────┘
        └─────────────┘        │
                               ▼
                        ┌─────────────┐
                        │PostureScore │
                        └─────────────┘
```

## Next Steps

1. **tasks.md の確認**: `/speckit.tasks` で生成されたタスク一覧を確認
2. **TDD サイクル開始**: ScoreCalculator のテストから実装開始
3. **PR 作成**: 機能完成後に `main` ブランチへ PR を作成
