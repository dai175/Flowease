# Implementation Plan: Flowease MVP機能

**Branch**: `001-mvp-features` | **Date**: 2025-12-28 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-mvp-features/spec.md`

## Summary

Flowease MVPは、macOSメニューバー常駐アプリとして、姿勢検知・休憩リマインダー・ストレッチガイドの3つのコア機能を提供する。Apple Vision Framework（Body Pose Detection）を使用してカメラ映像からリアルタイムで姿勢を検知し、悪い姿勢が続いた場合に通知を行う。全ての処理はローカルで完結し、プライバシーを最優先とする設計。

## Technical Context

**Language/Version**: Swift 5.0（Xcode デフォルト）
**Primary Dependencies**: SwiftUI, Vision Framework, AVFoundation, UserNotifications
**Storage**: UserDefaults（設定保存）
**Testing**: XCTest（Unit/UI Tests）
**Target Platform**: macOS 14.6+ (Sonoma)
**Project Type**: single（macOS デスクトップアプリ）
**Performance Goals**: 姿勢検知2秒間隔、CPU使用率5%以下、通知遅延5秒以内
**Constraints**: カメラ映像はローカル処理のみ、外部サーバー送信禁止
**Scale/Scope**: 個人開発用、単一ユーザー向け

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### I. Privacy First (プライバシー第一) ✅

| 要件 | 適合状況 |
|------|----------|
| カメラ映像はローカルでのみ処理 | ✅ Vision Frameworkでローカル処理 |
| 外部サーバーへの送信禁止 | ✅ ネットワーク通信なし |
| 姿勢検知結果はデバイス内保存 | ✅ UserDefaults使用 |
| Info.plistにカメラ使用理由を明記 | ✅ 実装時に追加予定 |

### II. Simplicity (シンプルさ) ✅

| 要件 | 適合状況 |
|------|----------|
| MVP 4機能を優先 | ✅ 姿勢検知、休憩リマインダー、ストレッチガイド、メニューバー常駐のみ |
| 先行実装の禁止 | ✅ Phase 3機能（省電力モード等）は対象外 |
| 設定項目は必要最小限 | ✅ カメラ選択、休憩間隔、姿勢感度のみ |

### III. User Experience & Quality (ユーザー体験と品質) ✅

| 要件 | 適合状況 |
|------|----------|
| メニューバー常駐型UI | ✅ NSStatusBar使用予定 |
| 適切な通知頻度 | ✅ 5秒間悪い姿勢継続で通知 |
| テスト駆動開発 | ✅ XCTestでRed-Green-Refactorサイクル |
| 姿勢検知ロジックとUI分離 | ✅ Service層で分離設計 |

**Gate Status**: ✅ PASSED（違反なし）

## Project Structure

### Documentation (this feature)

```text
specs/001-mvp-features/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
Flowease/
├── App/
│   ├── FloweaseApp.swift        # アプリエントリーポイント（MenuBarアプリとして再構成）
│   └── AppDelegate.swift        # NSApplicationDelegate（メニューバー制御）
├── Models/
│   ├── PostureState.swift       # 姿勢状態モデル
│   ├── BreakReminder.swift      # 休憩リマインダー設定モデル
│   ├── Stretch.swift            # ストレッチ情報モデル
│   └── UserSettings.swift       # ユーザー設定モデル
├── Services/
│   ├── PostureDetectionService.swift  # Vision Framework連携
│   ├── CameraService.swift            # AVFoundation連携
│   ├── NotificationService.swift      # UserNotifications連携
│   └── SettingsService.swift          # UserDefaults連携
├── Views/
│   ├── MenuBar/
│   │   ├── StatusBarView.swift        # メニューバーアイコン
│   │   └── PopoverView.swift          # ポップオーバーUI
│   ├── Settings/
│   │   └── SettingsView.swift         # 設定画面
│   └── Stretch/
│       ├── StretchGuideView.swift     # ストレッチガイドUI
│       └── StretchAnimationView.swift # ストレッチアニメーション
├── Resources/
│   ├── Assets.xcassets/
│   │   └── StatusBarIcon/             # メニューバーアイコン（緑/黄/赤）
│   ├── Animations/                    # ストレッチアニメーションデータ
│   └── Info.plist                     # カメラ使用理由記載
└── Utilities/
    └── Constants.swift                # 定数定義

FloweaseTests/
├── Services/
│   ├── PostureDetectionServiceTests.swift
│   └── NotificationServiceTests.swift
└── Models/
    ├── PostureStateTests.swift
    └── UserSettingsTests.swift

FloweaseUITests/
└── MenuBarUITests.swift
```

**Structure Decision**: macOS単一アプリケーション構造。既存のXcodeプロジェクト構造を維持しつつ、App/Models/Services/Views/Resourcesの階層で整理。テストはFloweaseTests（Unit）とFloweaseUITests（UI）に分離。

## Complexity Tracking

> Constitution Check に違反なし - このセクションは N/A

---

## Constitution Check (Post-Design Re-evaluation)

*設計完了後の再評価 - 2025-12-28*

### I. Privacy First (プライバシー第一) ✅ CONFIRMED

| 要件 | 設計での対応 | 確認状況 |
|------|-------------|----------|
| カメラ映像はローカルでのみ処理 | `PostureDetectionService` が `VNImageRequestHandler` でローカル処理 | ✅ 確認済み |
| 外部サーバーへの送信禁止 | サービス契約に外部通信メソッドなし、ネットワークフレームワーク不使用 | ✅ 確認済み |
| 姿勢検知結果はデバイス内保存 | `UserSettings` を `UserDefaults` に保存、クラウド同期なし | ✅ 確認済み |
| Info.plistにカメラ使用理由を明記 | `quickstart.md` に具体的な文言を記載済み | ✅ 確認済み |

### II. Simplicity (シンプルさ) ✅ CONFIRMED

| 要件 | 設計での対応 | 確認状況 |
|------|-------------|----------|
| MVP 4機能を優先 | データモデル・サービス契約ともにMVP機能のみ定義 | ✅ 確認済み |
| 先行実装の禁止 | 統計機能、クラウド同期、マルチユーザー機能は対象外 | ✅ 確認済み |
| 設定項目は必要最小限 | `UserSettings` に7項目のみ（全てMVP必須項目） | ✅ 確認済み |
| 外部依存の最小化 | Apple標準フレームワークのみ使用、サードパーティライブラリなし | ✅ 確認済み |

### III. User Experience & Quality (ユーザー体験と品質) ✅ CONFIRMED

| 要件 | 設計での対応 | 確認状況 |
|------|-------------|----------|
| メニューバー常駐型UI | `AppDelegate` で `NSStatusBar` を管理、ポップオーバーUI | ✅ 確認済み |
| 適切な通知頻度 | `badPostureAlertDelay` = 5秒、スヌーズ機能付き | ✅ 確認済み |
| テスト駆動開発 | テストファイル構造を定義、プロトコルベースで依存性注入可能 | ✅ 確認済み |
| 姿勢検知ロジックとUI分離 | `Services/` と `Views/` を完全分離、プロトコルでインターフェース定義 | ✅ 確認済み |

### 総合評価

**Gate Status**: ✅ **PASSED** - 全ての原則に適合

設計は Constitution の全原則を遵守しており、実装フェーズに進む準備が整っています。

---

## Generated Artifacts

| ファイル | 説明 | 生成日 |
|---------|------|--------|
| `plan.md` | 実装計画（本ファイル） | 2025-12-28 |
| `research.md` | 技術調査結果 | 2025-12-28 |
| `data-model.md` | データモデル定義 | 2025-12-28 |
| `contracts/service-interfaces.md` | サービスインターフェース契約 | 2025-12-28 |
| `quickstart.md` | 開発クイックスタートガイド | 2025-12-28 |

**Next Step**: `/speckit.tasks` を実行してタスク一覧を生成
