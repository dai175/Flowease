# Flowease

macOS メニューバー常駐の姿勢モニタリングアプリケーション

## 概要

Flowease は、カメラを使用してリアルタイムで姿勢を分析し、メニューバーアイコンの色でフィードバックを提供するmacOSアプリです。デスクワーク中の姿勢改善をサポートします。

## 主な機能

- **リアルタイム姿勢分析**: Vision フレームワークを使用して顔の位置・大きさ・傾きを検出
- **姿勢スコア**: 0〜100 のスコアで姿勢の良さを評価
- **姿勢キャリブレーション**: ユーザー個人の「良い姿勢」を基準として登録し、パーソナライズされた評価を提供
- **視覚的フィードバック**: スコアに応じたグラデーション色でアイコン表示（緑=良好、赤=要改善）
- **プライバシー重視**: カメラ映像はローカル処理のみ、保存・送信なし
- **エッジケース対応**: カメラ利用不可、顔未検出時は適切に処理
- **カメラ選択**: 複数カメラから使用するカメラを選択可能、選択は永続化
- **姿勢アラート通知**: 悪い姿勢が続いた場合にmacOS通知でお知らせ（閾値・間隔カスタマイズ可）
- **多言語対応**: 日本語・英語 UI（システム言語に自動追従）

## 必要条件

- macOS 14.6+
- Xcode 16.0+
- Homebrew

## 開発環境セットアップ

### 1. 依存ツールのインストール

```bash
brew install swiftlint swiftformat pre-commit xcbeautify
```

### 2. Git Hooks のセットアップ

```bash
make setup
```

または手動で:

```bash
pre-commit install
```

### 3. Xcode Build Phase の設定（推奨）

Xcode で SwiftLint をビルド時に自動実行するには:

1. Xcode でプロジェクトを開く
2. **Flowease** ターゲットを選択
3. **Build Settings** → 検索で「sandbox」→ **User Script Sandboxing** を **No** に変更
4. **Build Phases** タブを開く
5. **+** ボタンをクリック → **New Run Script Phase**
6. 以下のスクリプトを追加:

```bash
cd "${SRCROOT}"
if which swiftlint > /dev/null; then
  swiftlint
else
  echo "warning: SwiftLint not installed"
fi
```

7. スクリプトフェーズを **Compile Sources** の前にドラッグ
8. **Based on dependency analysis** のチェックを外す

## 開発コマンド

| コマンド | 説明 |
|---------|------|
| `make help` | 利用可能なコマンド一覧 |
| `make build` | プロジェクトをビルド |
| `make test` | テストを実行 |
| `make lint` | SwiftLint でコードをチェック |
| `make format` | SwiftFormat でコードをフォーマット |
| `make fix` | format + lint を実行 |
| `make hooks-run` | 全ファイルに対して pre-commit hooks を実行 |
| `make clean` | ビルド成果物を削除 |

## ツール設定ファイル

| ファイル | 説明 |
|---------|------|
| `.swiftlint.yml` | SwiftLint ルール設定 |
| `.swiftformat` | SwiftFormat フォーマット設定 |
| `.pre-commit-config.yaml` | Git pre-commit hooks 設定 |

## プロジェクト構成

```
Flowease/
├── Flowease/                      # メインアプリケーション
│   ├── FloweaseApp.swift          # アプリエントリーポイント
│   ├── AppState.swift             # アプリ状態管理
│   ├── Info.plist                 # アプリ設定
│   ├── Models/                    # データモデル
│   │   ├── AlertSettings.swift        # アラート設定
│   │   ├── AlertState.swift           # アラート状態
│   │   ├── CalibrationFailure.swift   # キャリブレーション失敗理由
│   │   ├── CalibrationProgress.swift  # キャリブレーション進捗
│   │   ├── CalibrationState.swift     # キャリブレーション状態
│   │   ├── CameraDevice.swift         # カメラデバイスモデル
│   │   ├── DisableReason.swift        # 無効化理由
│   │   ├── FaceBaselineMetrics.swift  # 顔ベース基準値
│   │   ├── FacePosition.swift         # 顔位置データ
│   │   ├── FaceReferencePosture.swift # 顔ベースキャリブレーションデータ
│   │   ├── MonitoringState.swift      # 監視状態
│   │   ├── PauseReason.swift          # 一時停止理由
│   │   ├── PostureScore.swift         # 姿勢スコア
│   │   ├── ScoreBreakdown.swift       # スコア内訳
│   │   ├── ScoreRecord.swift          # スコア記録
│   │   └── ScoreStatus.swift          # スコアステータス
│   ├── ViewModels/
│   │   ├── CalibrationViewModel.swift # キャリブレーションビューモデル
│   │   └── PostureViewModel.swift     # 姿勢監視ビューモデル
│   ├── Views/
│   │   ├── AlertSettingsView.swift      # アラート設定UI
│   │   ├── CalibrationCardView.swift    # キャリブレーションカード
│   │   ├── CalibrationProgressView.swift # キャリブレーション進捗表示
│   │   ├── CalibrationStateViews.swift  # キャリブレーション状態別ビュー
│   │   ├── CalibrationView.swift        # キャリブレーション画面
│   │   ├── CalibrationWindowView.swift  # キャリブレーションウィンドウ
│   │   ├── CameraPermissionView.swift   # カメラ許可リクエストUI
│   │   ├── CameraSelectionView.swift    # カメラ選択UI
│   │   ├── RealtimeScoreGauge.swift     # リアルタイムスコアゲージ
│   │   └── StatusMenuView.swift         # メニューバードロップダウン
│   ├── Services/
│   │   ├── AccumulatedFacePositions.swift  # 顔位置累積
│   │   ├── AlertSettingsStorage.swift      # アラート設定永続化
│   │   ├── CalibrationService.swift        # キャリブレーション制御
│   │   ├── CalibrationStorage.swift        # キャリブレーションデータ永続化
│   │   ├── CameraDeviceManager.swift       # カメラデバイス監視
│   │   ├── CameraService.swift             # カメラキャプチャ
│   │   ├── CameraService+Capture.swift     # カメラキャプチャ拡張
│   │   ├── CameraService+ErrorHandling.swift # カメラエラー処理
│   │   ├── CameraServiceProtocol.swift     # カメラサービスプロトコル
│   │   ├── FaceDetector.swift              # 顔検出サービス
│   │   ├── FaceScoreCalculator.swift       # 顔ベーススコア計算
│   │   ├── NotificationManager.swift       # 通知管理
│   │   ├── PostureAlertService.swift       # 姿勢アラートサービス
│   │   ├── PostureAnalyzer.swift           # 姿勢分析（Vision）
│   │   └── ScoreHistory.swift              # スコア履歴管理
│   ├── Utilities/
│   │   ├── ColorGradient.swift         # 色グラデーション
│   │   ├── Logger+Flowease.swift       # ロガー拡張
│   │   ├── MenuBarIcon.swift           # メニューバーアイコン
│   │   └── NSLock+Extensions.swift     # NSLock拡張
│   └── Assets.xcassets/           # アセット
├── FloweaseTests/                 # ユニットテスト
├── FloweaseUITests/               # UI テスト
├── specs/                         # 仕様書
│   ├── 001-posture-score/         # 姿勢スコア機能仕様
│   ├── 002-posture-calibration/   # 姿勢キャリブレーション機能仕様
│   ├── 003-face-detection/        # 顔検出ベース姿勢検知仕様
│   ├── 004-english-support/       # 英語対応仕様
│   ├── 005-camera-selection/      # カメラ選択機能仕様
│   └── 006-posture-alert/         # 姿勢アラート通知機能仕様
├── .swiftlint.yml                 # SwiftLint 設定
├── .swiftformat                   # SwiftFormat 設定
├── .pre-commit-config.yaml        # pre-commit 設定
├── .gitignore                     # Git 除外設定
├── Makefile                       # 開発コマンド
├── CLAUDE.md                      # Claude Code 設定
└── README.md                      # このファイル
```

## 使用技術

- **Swift 6.0 + SwiftUI**: UI フレームワーク
- **AVFoundation**: カメラキャプチャ
- **Vision**: 顔検出（VNDetectFaceRectanglesRequest, VNDetectFaceCaptureQualityRequest）
