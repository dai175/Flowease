# Research: 姿勢スコア表示機能

**Feature**: 001-posture-score
**Date**: 2025-12-30
**Status**: Complete

## Overview

macOSメニューバーアプリで姿勢をリアルタイム分析するために必要な技術調査結果をまとめる。

---

## 1. 姿勢検出技術 (Vision Framework)

### Decision: Apple Vision Framework (VNDetectHumanBodyPoseRequest)

### Rationale

- **ネイティブサポート**: macOS 11.0+ で標準搭載、追加ライブラリ不要
- **プライバシー**: 完全にオンデバイス処理、データ送信なし (FR-010準拠)
- **最適化**: Apple Silicon の Neural Engine で高速処理
- **上半身対応**: `upperBodyOnly` プロパティで上半身検出に特化可能

### Alternatives Considered

| 選択肢 | 評価 | 不採用理由 |
|--------|------|------------|
| MediaPipe (Google) | 高精度だがクロスプラットフォーム | 外部依存、ライセンス考慮、macOSでの最適化不足 |
| OpenPose | オープンソース、研究用途で実績 | 重い、macOS向け最適化なし、セットアップ複雑 |
| Core ML カスタムモデル | 柔軟性高い | 開発コスト大、Vision で十分な精度 |

### 利用可能な上半身関節ポイント

姿勢スコア算出に使用する関節:

| 関節名 | JointName | 用途 |
|--------|-----------|------|
| 鼻 | `.nose` | 頭部位置の基準点 |
| 首 | `.neck` | 頭部傾斜・前傾検出 |
| 左肩 | `.leftShoulder` | 肩の水平バランス |
| 右肩 | `.rightShoulder` | 肩の水平バランス |
| 左耳 | `.leftEar` | 頭部回転検出 |
| 右耳 | `.rightEar` | 頭部回転検出 |
| 体の中心 | `.root` | 背骨の垂直アライメント |

### パフォーマンス特性

- **CPU使用率**: 5-15% (最適化時)、15-30% (通常連続検出)
- **メモリ使用量**: ベース50-100MB、処理中+20-50MB
- **処理速度**: M1/M2で30-60 FPS (720p)、Intel Macで15-30 FPS
- **推奨解像度**: 640x480 または 1280x720 (高解像度は不要)
- **推奨フレームレート**: 10-15 FPS (姿勢変化は緩やかなため)

---

## 2. メニューバーアプリ実装 (SwiftUI)

### Decision: SwiftUI MenuBarExtra

### Rationale

- **モダン API**: macOS 13+ で導入、SwiftUI ネイティブ
- **Constitution 準拠**: SwiftUI-First Architecture (原則 I) に合致
- **簡潔な実装**: 数行でメニューバー常駐を実現
- **状態管理**: `@Observable` / `@StateObject` との統合が容易

### 実装パターン

```swift
@main
struct FloweaseApp: App {
    var body: some Scene {
        MenuBarExtra {
            MenuContentView()
        } label: {
            Image(systemName: "figure.stand")
                .foregroundStyle(iconColor) // 動的色変更
        }
    }
}
```

### Dockアイコン非表示

**Decision**: Info.plist で `LSUIElement = true` を設定

**Rationale**:
- シンプルで確実
- アプリ起動時から適用
- プログラマティック設定より安定

### 動的アイコン色変更

**Decision**: SF Symbols + `foregroundStyle()` でスコアに応じた色を表示

**Implementation**:
- `@Observable` クラスで `postureScore` を監視
- スコアに応じて Color を計算 (0-100 → 赤-黄-緑グラデーション)
- `isTemplate = false` で色付きアイコンを表示

### Alternatives Considered

| 選択肢 | 評価 | 不採用理由 |
|--------|------|------------|
| NSStatusItem 直接操作 | より細かい制御可能 | SwiftUI との統合が複雑、Constitution 原則 I に反する |
| AppKit ベース実装 | 従来の安定した方法 | SwiftUI-First に反する、コード量増加 |

---

## 3. カメラアクセス (AVFoundation)

### Decision: AVCaptureSession + AVCaptureVideoDataOutput

### Rationale

- **標準 API**: macOS/iOS 共通、安定した動作
- **リアルタイム処理**: フレームごとのコールバックで Vision と連携
- **権限管理**: システム標準の権限ダイアログを使用

### 権限フロー

1. **Info.plist 設定** (必須):
   ```xml
   <key>NSCameraUsageDescription</key>
   <string>姿勢をモニタリングするためにカメラを使用します</string>
   ```

2. **権限チェック**: `AVCaptureDevice.authorizationStatus(for: .video)`
3. **権限要求**: `AVCaptureDevice.requestAccess(for: .video)`
4. **拒否時**: システム設定への誘導 (`x-apple.systempreferences:...`)

### 処理フロー

```
AVCaptureSession
  → AVCaptureDeviceInput (ウェブカメラ)
  → AVCaptureVideoDataOutput
     → CMSampleBuffer (デリゲートコールバック)
        → CVPixelBuffer
           → VNImageRequestHandler
              → VNDetectHumanBodyPoseRequest
                 → VNHumanBodyPoseObservation
```

### パフォーマンス最適化

- **フレームスキップ**: 全フレーム処理せず、2-3フレームに1回
- **専用キュー**: カメラ出力用の DispatchQueue を使用
- **バッファ管理**: AutoreleasepoolPoolで適切にメモリ解放

---

## 4. 姿勢スコア算出アルゴリズム

### Decision: 関節角度ベースのスコアリング

### スコア構成要素

| 要素 | 重み | 計算方法 |
|------|------|----------|
| 頭部傾斜 | 30% | 首-鼻の垂直からの角度偏差 |
| 肩の水平バランス | 25% | 左右肩のY座標差 |
| 前傾姿勢 | 30% | 鼻のX座標と首/rootの前後関係 |
| 左右対称性 | 15% | 左右耳・肩の対称性 |

### スコア計算ロジック (概要)

```
baseScore = 100

// 頭部傾斜ペナルティ
headTiltAngle = angle(neck, nose) - 90°
if headTiltAngle > threshold:
    baseScore -= headTiltPenalty * (headTiltAngle / maxAngle)

// 肩バランスペナルティ
shoulderDiff = abs(leftShoulder.y - rightShoulder.y)
if shoulderDiff > threshold:
    baseScore -= shoulderPenalty * (shoulderDiff / maxDiff)

// 前傾ペナルティ
forwardLean = nose.x - neck.x (正規化座標)
if forwardLean > threshold:
    baseScore -= leanPenalty * (forwardLean / maxLean)

finalScore = clamp(baseScore, 0, 100)
```

### 閾値設定 (初期値、テストで調整)

- **頭部傾斜閾値**: 10° (軽度)、20° (中度)、30° (重度)
- **肩水平閾値**: 0.02 (軽度)、0.05 (中度)、0.08 (重度) ※正規化座標
- **前傾閾値**: 0.03 (軽度)、0.06 (中度)、0.10 (重度) ※正規化座標

### スムージング

- **時間平均**: 過去5サンプル (約1秒) の移動平均
- **外れ値除去**: confidence < 0.5 のサンプルを除外
- **急激な変化抑制**: 前回スコアとの差を最大10ポイントに制限

---

## 5. アイコン色グラデーション

### Decision: HSB カラースペースでスコアから色を算出

### Rationale

- **直感的**: スコア100=緑(Hue=120°)、スコア0=赤(Hue=0°)
- **滑らかなグラデーション**: 中間色が自然に黄色系になる
- **実装が簡単**: 線形補間で計算可能

### カラーマッピング

```
hue = (score / 100) * 120  // 0° (赤) → 120° (緑)
saturation = 0.8
brightness = 0.9
color = Color(hue: hue/360, saturation: saturation, brightness: brightness)
```

| スコア範囲 | Hue | 色 |
|-----------|-----|-----|
| 90-100 | 108-120° | 緑 |
| 70-89 | 84-107° | 黄緑 |
| 50-69 | 60-83° | 黄 |
| 30-49 | 36-59° | オレンジ |
| 0-29 | 0-35° | 赤 |

### グレー状態 (カメラ利用不可時)

- 人物未検出、カメラアクセス拒否、他アプリ使用中
- `Color.gray` または `systemGray` を使用

---

## 6. アプリライフサイクル

### Decision: Timer + RunLoop でバックグラウンド動作

### 実装要点

1. **常駐**: `LSUIElement = true` でメニューバーのみに常駐
2. **バックグラウンド処理**: Timer を RunLoop.common モードに追加
3. **リソース管理**: 使用していない時はカメラセッションを停止
4. **終了処理**: `NSApplication.shared.terminate(nil)` で適切に終了

### 電源管理

- カメラ使用中はシステムスリープを一時的に防止 (IOPMAssertion)
- ユーザーが離席 (人物未検出) したら検出頻度を下げる

### ログイン時自動起動 (将来実装)

- `SMAppService.mainApp.register()` (macOS 13+)
- 初期リリースでは手動起動のみ

---

## 7. テスト戦略

### ユニットテスト対象

| コンポーネント | テスト内容 |
|---------------|------------|
| ScoreCalculator | 関節座標→スコア変換の正確性 |
| ColorGradient | スコア→色変換の正確性 |
| MonitoringState | 状態遷移の正確性 |

### モック戦略

- **CameraService**: プロトコルで抽象化、モックフレームを注入
- **PostureAnalyzer**: 固定の VNHumanBodyPoseObservation を返すモック
- **時間依存処理**: Clock プロトコルでテスト時間を制御

### UI テスト対象

- メニューバーアイコンの表示
- メニューの表示と終了機能
- 権限ダイアログフロー (限定的)

---

## Summary

全ての技術選択が Constitution に準拠し、FR/SC の要件を満たすことを確認:

- **FR-001〜FR-010**: Vision + AVFoundation + SwiftUI で実現可能
- **SC-001 (2秒以内更新)**: 10-15 FPS 処理で十分達成可能
- **SC-004 (5秒以内起動)**: MenuBarExtra + AVCaptureSession で達成可能
- **SC-005 (リソース安定)**: フレームスキップ + 適切なメモリ管理で達成可能

Phase 1 (Design & Contracts) への移行準備完了。
