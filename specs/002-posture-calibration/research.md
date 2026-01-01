# Research: 姿勢キャリブレーション機能

**Feature**: 002-posture-calibration
**Date**: 2026-01-01

## 1. 既存実装の分析

### 1.1 現在のスコア算出ロジック (ScoreCalculator.swift)

**Decision**: 既存の4項目評価ロジックをキャリブレーション対応に拡張する

**Rationale**:
- 既存ロジックは十分にテストされており、姿勢の重要な側面を網羅
- 固定しきい値を基準姿勢からの逸脱に置き換えることで、最小限の変更で対応可能
- 4項目の重み付け（頭傾き30%、肩バランス25%、前傾30%、対称性15%）は維持

**Alternatives considered**:
- 全く新しいスコアリングアルゴリズム → 既存テストが無効化されるため却下
- 角度ベースのみの評価 → 4項目の多角的評価の方が精度が高い

### 1.2 データモデル (BodyPose, JointPosition)

**Decision**: 基準姿勢データにはBodyPoseと同等の構造を使用し、Codableで永続化する

**Rationale**:
- BodyPoseは既に7つの関節位置（nose, neck, leftShoulder, rightShoulder, leftEar, rightEar, root）を保持
- JointPositionは正規化座標(0.0-1.0)と信頼度を持つ
- 基準姿勢の保存には同じ構造が最適

**Alternatives considered**:
- 計算済みの比率のみ保存 → 将来の評価ロジック変更に対応できない
- 画像データの保存 → ストレージサイズが大きすぎる

### 1.3 しきい値の設計

現在の固定しきい値:
| 項目 | 許容偏差 | 最大偏差 |
|------|----------|----------|
| 頭傾き | 0.02 | 0.15 |
| 肩バランス | 0.02 | 0.15 |
| 前傾 | 0.03 | 0.15 |
| 対称性 | 0.02 | 0.15 |

**Decision**: キャリブレーション後は基準姿勢の各値を「ゼロ点」として扱い、相対的な偏差を計算する

**Rationale**:
- 基準姿勢を取得時、各項目の値を記録
- リアルタイム評価時は「現在値 - 基準値」の絶対値を偏差として使用
- しきい値は維持（どれだけずれたらスコアが下がるかは固定）

## 2. 技術的決定事項

### 2.1 複数フレーム平均化

**Decision**: 3秒間のフレームを収集し、各関節の座標を平均化する

**Rationale**:
- カメラフレームレートは約30fps → 約90フレームを収集
- 外れ値除去：信頼度0.7未満のフレームは除外
- 各関節の(x, y)座標を算術平均

**Implementation approach**:
```swift
struct FrameAccumulator {
    var frames: [BodyPose] = []
    let targetDuration: TimeInterval = 3.0
    let minimumConfidence: Double = 0.7

    func averagedPose() -> ReferencePosture? {
        let validFrames = frames.filter { $0.averageConfidence >= minimumConfidence }
        guard validFrames.count >= 30 else { return nil }  // 最低1秒分
        // 各関節の平均座標を計算
    }
}
```

### 2.2 永続化戦略

**Decision**: UserDefaultsにCodable形式で保存

**Rationale**:
- 単一ユーザー向けの少量データ（数KB未満）
- アプリ再起動時に確実に復元
- CoreDataやファイルシステムは過剰

**Storage keys**:
- `flowease.calibration.referencePosture`: ReferencePosture (Codable)

**Note**: CalibrationStateは永続化しない。`referencePosture` の有無から状態を導出する（nil → notCalibrated, 存在 → completed）。`calibratedAt` は `ReferencePosture` 内に含まれる。

### 2.3 キャリブレーション失敗条件

**Decision**: 信頼度0.7未満が連続1秒（約30フレーム）続いたら失敗

**Rationale**:
- 一瞬の検出失敗は無視（ノイズ対策）
- 1秒以上続く場合は環境に問題がある可能性が高い
- 失敗時はプログレスをリセットし、再試行を促す

### 2.4 スコア計算の修正方針

**Decision**: ScoreCalculatorにReferencePostureを注入し、基準からの逸脱を計算

**Current flow**:
```
BodyPose → ScoreCalculator → PostureScore
          (固定しきい値で評価)
```

**New flow**:
```
BodyPose + ReferencePosture → ScoreCalculator → PostureScore
                             (基準姿勢からの逸脱で評価)
```

**Implementation approach**:
- ScoreCalculatorに`referencePosture: ReferencePosture?`プロパティを追加
- `nil`の場合は既存の固定しきい値で評価（フォールバック）
- 設定時は各項目の「基準値」を計算し、それを基準に偏差を算出

## 3. UI/UX設計

### 3.1 キャリブレーション画面

**Decision**: モーダルポップオーバー形式で表示

**Rationale**:
- メニューバーアプリなのでフルウィンドウは不適切
- ポップオーバーなら既存のStatusMenuViewから呼び出し可能
- サイズ: 約300x200pt

**Components**:
1. 状態説明テキスト（「良い姿勢を取ってください」）
2. プログレスバー（3秒のカウントダウン）
3. 開始/キャンセルボタン
4. 結果表示（成功/失敗メッセージ）

### 3.2 プログレス表示

**Decision**: 円形プログレス + 秒数カウントダウン

**Rationale**:
- 3秒という短時間なので円形が視覚的にわかりやすい
- 「3...2...1」のカウントダウンで残り時間を明示

### 3.3 キャリブレーション状態表示

**Decision**: メニュー内にステータスラベルを追加

**Rationale**:
- メニューバーアイコンは既にスコア表示に使用
- メニュー内で「キャリブレーション: 完了 ✓」または「キャリブレーション: 未設定」を表示
- 未設定時は「キャリブレーション」メニュー項目をハイライト

## 4. テスト戦略

### 4.1 ユニットテスト

| テスト対象 | テスト内容 |
|-----------|----------|
| ReferencePosture | 平均化計算、Codableエンコード/デコード |
| CalibrationService | 状態遷移、フレーム収集、成功/失敗判定 |
| CalibrationStorage | 保存/読み込み/削除 |
| ScoreCalculator | 基準姿勢ありなしでのスコア計算 |

### 4.2 統合テスト

- キャリブレーション→永続化→再起動→スコア評価の一連フロー
- 信頼度低下時の失敗シナリオ

## 5. リスクと軽減策

| リスク | 影響 | 軽減策 |
|-------|------|--------|
| カメラ位置変更時の基準ずれ | スコアが不正確になる | キャリブレーションリセット機能で対応 |
| 極端な姿勢でキャリブレーション | 正常姿勢で低スコア | 事前説明で「快適で持続可能な姿勢」を促す |
| UserDefaultsの破損 | キャリブレーション消失 | フォールバックで固定しきい値に戻る |
