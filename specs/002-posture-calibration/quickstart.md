# Quickstart: 姿勢キャリブレーション機能

**Feature**: 002-posture-calibration
**Date**: 2026-01-01

## 概要

この機能は、ユーザー個人の「良い姿勢」を基準として記録し、その基準からの逸脱度に基づいて姿勢スコアを算出するキャリブレーション機能を追加します。

## 前提条件

- macOS 14.6+
- Xcode 15.0+
- Swift 6.0

## 実装順序

### Phase 1: Models（データモデル）

```
1. ReferenceJointPosition.swift     - 基準関節位置（Codable）
2. BaselineMetrics.swift    - 基準評価項目値（Codable）
3. ReferencePosture.swift   - 基準姿勢（Codable）
4. CalibrationState.swift   - キャリブレーション状態（Enum）
5. CalibrationProgress.swift - 進行状況
6. CalibrationFailure.swift  - 失敗理由
```

### Phase 2: Services（ビジネスロジック）

```
1. CalibrationStorage.swift  - UserDefaults永続化
2. CalibrationService.swift  - キャリブレーション制御
3. ScoreCalculator.swift     - 既存クラスの拡張（基準姿勢対応）
```

### Phase 3: ViewModels

```
1. CalibrationViewModel.swift - キャリブレーション画面のVM
2. PostureMonitorViewModel.swift - 既存VMの拡張（状態連携）
```

### Phase 4: Views（UI）

```
1. CalibrationProgressView.swift - プログレス表示コンポーネント
2. CalibrationView.swift         - キャリブレーション画面
3. StatusMenuView.swift          - 既存メニューにキャリブレーション項目追加
```

## 主要なコード例

### ReferencePosture の作成

```swift
// FrameAccumulatorでフレームを収集
let accumulator = FrameAccumulator(targetDuration: 3.0)

// 各フレームを追加
accumulator.addFrame(bodyPose)

// 基準姿勢を生成
if let referencePosture = accumulator.createReferencePosture() {
    storage.saveReferencePosture(referencePosture)
}
```

### キャリブレーション済みスコア計算

```swift
let calculator = ScoreCalculator()

// 基準姿勢を設定
if let referencePosture = storage.loadReferencePosture() {
    calculator.setReferencePosture(referencePosture)
}

// スコア計算（自動的に基準姿勢からの逸脱で評価）
if let score = calculator.calculate(from: currentPose) {
    print("Score: \(score.value)")
}
```

### キャリブレーション状態の監視

```swift
@Observable
class CalibrationViewModel {
    private let service: CalibrationServiceProtocol

    var state: CalibrationState { service.state }
    var progress: Double { ... }
    var isInProgress: Bool { ... }

    func startCalibration() async {
        do {
            try await service.startCalibration()
        } catch {
            // エラーハンドリング
        }
    }
}
```

## テスト実行

```bash
# 全テスト実行
make test

# キャリブレーション関連のみ
xcodebuild test -scheme Flowease -only-testing:FloweaseTests/CalibrationServiceTests
xcodebuild test -scheme Flowease -only-testing:FloweaseTests/CalibrationStorageTests
xcodebuild test -scheme Flowease -only-testing:FloweaseTests/ReferencePostureTests
```

## 重要な閾値

| 項目 | 値 | 説明 |
|------|-----|------|
| キャリブレーション時間 | 3秒 | フレーム収集期間 |
| 想定フレーム数 | 約90 | 30fps × 3秒 |
| 最小フレーム数 | 30 | 成功に必要な最低フレーム数（約1秒分） |
| 信頼度しきい値 | 0.7 | これ以上の信頼度が必要 |
| 失敗判定 | 1秒連続 | 低信頼度（0.7未満）が30フレーム続いた場合 |

## トラブルシューティング

### キャリブレーションが失敗する

1. **人物が検出されない**: カメラに正面を向いて座る
2. **信頼度が低い**: 照明を調整（逆光を避ける）
3. **フレーム不足**: 静止した状態を維持

### スコアが不安定

1. キャリブレーションをリセットして再実行
2. 快適で持続可能な姿勢でキャリブレーション
3. カメラ位置を固定

## 関連ファイル

- [仕様書](./spec.md)
- [実装計画](./plan.md)
- [リサーチ](./research.md)
- [データモデル](./data-model.md)
- [コントラクト](./contracts/)
