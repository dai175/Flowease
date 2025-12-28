<!--
Sync Impact Report
==================
- Version change: 0.0.0 → 1.0.0 (initial creation)
- Modified principles: N/A (new document)
- Added sections:
  - I. Privacy First (プライバシー第一)
  - II. Simplicity (シンプルさ)
  - III. User Experience & Quality (ユーザー体験と品質)
  - Development Workflow
  - Technical Constraints
  - Governance
- Removed sections: N/A
- Templates requiring updates:
  - .specify/templates/plan-template.md: ✅ Compatible (Constitution Check section ready)
  - .specify/templates/spec-template.md: ✅ Compatible (requirements section can reference principles)
  - .specify/templates/tasks-template.md: ✅ Compatible (TDD approach already documented)
  - .specify/templates/checklist-template.md: ✅ Compatible (general template)
  - .specify/templates/agent-file-template.md: ✅ Compatible (general template)
- Follow-up TODOs: None
-->

# Flowease Constitution

## Core Principles

### I. Privacy First (プライバシー第一)

カメラ映像とユーザーデータのプライバシー保護は最優先事項である。

- カメラ映像はローカルでのみ処理し、外部サーバーへの送信を禁止する
- 姿勢検知の結果（スコア、警告履歴など）はデバイス内に保存する
- ユーザーデータの収集・送信機能を実装する場合は、明示的な同意を必須とする
- Info.plistにカメラ使用理由を明確に記載する

**理由**: デスクワーク中の姿勢データは個人の健康情報であり、ユーザーの信頼を得るためにプライバシー保護は非妥協的な原則である。

### II. Simplicity (シンプルさ)

最小限の機能で最大の価値を提供する。YAGNI（You Aren't Gonna Need It）原則を遵守する。

- MVPの4機能（姿勢検知、休憩リマインダー、ストレッチガイド、メニューバー常駐）を優先する
- 「将来使うかもしれない」機能の先行実装を禁止する
- 新機能追加時は既存機能との統合コストを評価し、複雑さの増加を最小限に抑える
- 設定項目は必要最小限に留め、適切なデフォルト値を提供する

**理由**: 個人開発プロジェクトであり、限られたリソースで実用的な価値を素早く提供するためにはシンプルさが不可欠である。

### III. User Experience & Quality (ユーザー体験と品質)

邪魔にならないUIと高品質なコードを両立する。

**ユーザー体験**:
- 作業の妨げにならないメニューバー常駐型UIを維持する
- 通知は適切な頻度とタイミングで行い、ユーザーが無視しない仕組みを設計する
- 姿勢状態を色で直感的に表示し、詳細情報は必要時のみ表示する
- ストレッチ完了時にポジティブなフィードバックを提供する

**品質保証（テスト駆動）**:
- 新機能の実装前にテストを作成し、テストが失敗することを確認する
- Red-Green-Refactorサイクルを遵守する
- 姿勢検知ロジックとUI表示は独立してテスト可能な設計にする

**理由**: アプリの目的は「デスクワーカーの体調管理パートナー」であり、ユーザーの作業を邪魔せず、信頼できる品質を提供することが成功の鍵である。

## Technical Constraints

本プロジェクトにおける技術的な制約と方針。

- **言語・フレームワーク**: Swift 5.x + SwiftUI + Vision Framework
- **最小対応OS**: macOS 14 (Sonoma) 以降
- **カメラアクセス**: AVFoundation経由、常時監視（MVPフェーズ）
- **パフォーマンス**:
  - バックグラウンド動作時のCPU使用率を監視する
  - 省電力モードは Phase 3 以降で対応
- **配布**: 初期は開発者個人用、将来的にMac App Store検討

## Development Workflow

開発プロセスにおける品質ゲート。

### コードレビュー
- PRマージ前にセルフレビューを実施する
- Privacy First原則の遵守を確認（カメラデータの外部送信がないこと）
- 複雑さの増加が正当化されることを確認

### テスト
- **自動テスト**: XCTestを使用し、ビルド時に自動実行
- **手動テスト**: UI/UXの確認、姿勢検知の精度検証
- テストカバレッジの目標は設定しないが、コア機能（姿勢検知ロジック）は必ずテストする

### ブランチ戦略
- `main`: 安定版
- `feature/*`: 機能開発ブランチ

## Governance

本Constitutionはプロジェクトの最上位ガイドラインである。

**優先順位**: Constitution > 技術ドキュメント > 個別実装判断

**改訂手順**:
1. 改訂提案を文書化する
2. 既存コードへの影響を評価する
3. 必要に応じて移行計画を作成する
4. バージョンを更新し、変更履歴を記録する

**バージョニング**:
- MAJOR: 原則の削除・根本的変更
- MINOR: 原則の追加・大幅な拡張
- PATCH: 表現の明確化・誤字修正

**コンプライアンス確認**:
- 新機能の設計時にConstitution Checkを実施する
- 原則違反の場合は、正当な理由を文書化する

**Version**: 1.0.0 | **Ratified**: 2025-12-28 | **Last Amended**: 2025-12-28
