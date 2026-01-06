# Data Model: 英語対応

**Feature**: 004-english-support
**Date**: 2026-01-06

## Overview

本機能は新しいデータエンティティを追加するものではなく、既存のユーザー向け文字列をローカライズ対象として整理する。以下に、ローカライズが必要なすべての文字列をソースファイル別に列挙する。

**Note**: 英語が Development Language（フォールバック言語）のため、コード内の文字列は英語に変更し、日本語は String Catalog で翻訳として追加する。

---

## Localization String Inventory

### Views

#### StatusMenuView.swift

| Key (English) | Japanese Translation | Context |
|---------------|----------------------|---------|
| Monitoring Posture | 姿勢モニタリング中 | 監視中状態の説明 |
| Calibration: | キャリブレーション: | ステータス行ラベル |
| Reset | リセット | ボタンラベル |
| Reconfigure | 再設定 | ボタンラベル（キャリブレーション済み時） |
| Configure | 設定 | ボタンラベル（未キャリブレーション時） |

#### CalibrationView.swift

| Key (English) | Japanese Translation | Context |
|---------------|----------------------|---------|
| Posture Calibration | 姿勢キャリブレーション | 画面タイトル |
| Please assume good posture | 良い姿勢を取ってください | 開始前の説明 |
| Face the camera and maintain a relaxed, good posture for 3 seconds. | 3秒間、カメラに向かって正面を向き、リラックスした良い姿勢を維持してください。 | 詳細説明 |
| Maintain your posture... | そのままの姿勢を維持... | 進行中メッセージ |
| Calibration Complete | キャリブレーション完了 | 完了タイトル |
| Your good posture has been recorded as the baseline. | あなたの良い姿勢が基準として記録されました。 | 完了説明 |
| Calibration Failed | キャリブレーション失敗 | 失敗タイトル |
| Cancel | キャンセル | ボタンラベル |
| Start | 開始 | ボタンラベル |
| Close | 閉じる | ボタンラベル |

#### CameraPermissionView.swift

| Key (English) | Japanese Translation | Context |
|---------------|----------------------|---------|
| Open System Settings | システム設定を開く | ボタンラベル |

### Models

#### DisableReason.swift

| Key (English) | Japanese Translation | Property |
|---------------|----------------------|----------|
| Camera access denied | カメラへのアクセスが拒否されています | description |
| Camera access restricted | カメラへのアクセスが制限されています | description |
| Camera not found | カメラが見つかりません | description |
| Go to System Settings > Privacy & Security > Camera to grant permission | システム設定 > プライバシーとセキュリティ > カメラ から許可してください | actionHint |
| Contact your system administrator to request camera access | システム管理者に連絡してカメラの使用許可を依頼してください | actionHint |
| Please connect an external camera | 外部カメラを接続してください | actionHint |

#### PauseReason.swift

| Key (English) | Japanese Translation | Property |
|---------------|----------------------|----------|
| Initializing camera... | カメラを準備中... | description |
| Face not detected | 顔が検出されません | description |
| Camera is being used by another app | カメラが他のアプリで使用中です | description |
| Detection quality is low | 検出精度が低下しています | description |

#### CalibrationFailure.swift

| Key (English) | Japanese Translation | Property |
|---------------|----------------------|----------|
| Please ensure your face is visible to the camera | カメラに顔が映るようにしてください | userMessage |
| Please adjust the lighting | 照明を調整してください | userMessage |
| Please try again | もう一度お試しください | userMessage |

### ViewModels

#### CalibrationViewModel.swift

| Key (English) | Japanese Translation | Property |
|---------------|----------------------|----------|
| Posture detection quality is low | 姿勢の検出精度が低下しています | qualityWarningMessage |
| Please ensure your face is visible to the camera | カメラに顔が映っていることを確認してください | qualityWarningMessage |
| Calibration not configured | キャリブレーション未設定 | statusText |
| Calibrating... %d seconds remaining | キャリブレーション中... 残り%d秒 | statusText (with interpolation) |
| Calibration Complete | キャリブレーション完了 | statusText |
| Configure calibration for more accurate posture assessment | キャリブレーションを設定すると、より正確な姿勢評価ができます | recommendationMessage |
| Complete | 完了 | statusSummary |
| Complete (%@) | 完了 (%@) | statusSummary (with date) |
| Not configured | 未設定 | statusSummary |
| An unexpected error occurred | 予期しないエラーが発生しました | errorMessage |

---

## String Catalog Structure

### File Location
`Flowease/Localizable.xcstrings`

### Languages
- **Development Language**: English (en) - フォールバック言語として機能
- **Supported Languages**: English (en), Japanese (ja)

### Total String Count
**約38個** のユニークな文字列

---

## State Transitions

本機能はデータモデルの状態遷移に変更を加えない。既存の `CalibrationState`, `MonitoringState` 等の状態遷移は維持される。

---

## Validation Rules

| Rule | Description |
|------|-------------|
| 全キー翻訳必須 | String Catalog 内のすべてのキーに日本語・英語の翻訳が存在すること |
| 空文字列禁止 | 翻訳値が空文字列でないこと（cancelled 状態の空メッセージを除く） |
| プレースホルダ一致 | 文字列補間を含むキーは、翻訳でも同じプレースホルダを維持すること |
