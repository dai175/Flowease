<!--
  ============================================================================
  SYNC IMPACT REPORT
  ============================================================================
  Version change: 1.0.0 → 1.1.0 (MINOR - new principles added)

  Modified principles: N/A

  Added sections:
    - VII. Localization & Internationalization
    - VIII. Privacy by Design
    - IX. Accessibility First

  Removed sections: N/A

  Templates requiring updates:
    - .specify/templates/plan-template.md ✅ (Constitution Check section exists)
    - .specify/templates/spec-template.md ✅ (Compatible structure)
    - .specify/templates/tasks-template.md ✅ (Compatible structure)

  Follow-up TODOs: None
  ============================================================================
-->

# Flowease Constitution

## Core Principles

### I. SwiftUI-First Architecture

すべての UI コンポーネントは SwiftUI を使用して宣言的に構築する。

- View は状態から純粋に派生する: `View = f(State)`
- 副作用は `@Observable` または `@StateObject` 内に閉じ込める
- View の責務は描画のみ; ビジネスロジックは ViewModel または Service に分離
- `PreviewProvider` を活用し、すべての View に Preview を提供する
- 複雑な View は小さな再利用可能コンポーネントに分割する（最大 50 行目安）

**根拠**: 宣言的 UI は予測可能性とテスタビリティを向上させ、
macOS/iOS 間のコード共有を容易にする。

### II. Type Safety & Memory Safety

Swift の型システムを最大限に活用し、コンパイル時にエラーを検出する。

- Force unwrap (`!`) の使用禁止 - `guard let` または `if let` を使用する
- 暗黙的アンラップオプショナル (`String!`) の使用禁止
- `Result<Success, Failure>` または Swift Concurrency (`async throws`) でエラーを明示的に扱う
- `Sendable` 準拠を適切に適用し、データ競合を防止する
- 必須のプロパティには非オプショナル型を使用する

**根拠**: Swift の型安全性は実行時クラッシュを防ぎ、
コードの意図を明確にする。

### III. Test-Driven Development

テストファーストアプローチにより品質を担保する。

- 新機能実装前に XCTest でテストケースを記述する
- Red-Green-Refactor サイクルを遵守する
- ユニットテストはビジネスロジックとデータ変換に焦点を当てる
- UI テストは主要なユーザーフローをカバーする
- テストカバレッジ目標: ビジネスロジック 80% 以上

**根拠**: TDD は仕様の明確化とリグレッション防止を両立し、
自信を持ってリファクタリングできる基盤を提供する。

### IV. User Experience Excellence

macOS ネイティブの体験を提供し、ユーザーの期待に応える。

- Human Interface Guidelines (HIG) に準拠する
- キーボードショートカットとアクセシビリティを標準サポートする
- メニューバーアプリとして適切なライフサイクル管理を行う
- システム設定（ダークモード、アクセント色等）を尊重する
- レスポンシブな UI: ユーザー操作に 100ms 以内で視覚的フィードバック

**根拠**: ネイティブ体験はユーザーの信頼を獲得し、
アプリの長期的な採用に直結する。

### V. Observability & Debugging

プロダクション環境での問題診断を容易にする。

- `print()` ではなく `Logger` (OSLog) を使用する
- ログレベルを適切に使い分ける: debug, info, error, fault
- 構造化ログでコンテキスト情報を含める
- クラッシュレポートとエラートラッキングを計画する
- メモリと CPU 使用量のプロファイリングを定期実施する

**根拠**: 適切なログとモニタリングは問題の早期発見と
迅速な解決を可能にする。

### VI. Code Quality Gates

一貫したコード品質を自動的に維持する。

- SwiftLint: すべてのコードはリントエラーなしで通過する
- SwiftFormat: コードスタイルの自動統一
- pre-commit hooks: コミット前に lint と format を実行
- 行長: 120 文字（警告）、150 文字（エラー）
- 関数本体: 50 行以下（警告）

**根拠**: 自動化されたコード品質チェックはコードレビューの負担を減らし、
チーム全体で一貫したコードベースを維持する。

### VII. Localization & Internationalization

多言語対応を最初から考慮し、グローバルユーザーに対応する。

- すべての UI 文字列は String Catalog (`Localizable.xcstrings`) で管理する
- ハードコードされた文字列を UI に直接埋め込まない
- 基本言語: 英語 (en)、追加言語: 日本語 (ja)
- 日付・数値のフォーマットはシステムロケールに従う (`DateFormatter`)
- 新しい UI 文字列追加時は、すべての対応言語に翻訳を同時に追加する
- Logger メッセージは英語のみ（ローカライズ対象外）

**根拠**: 国際化を後付けで行うことは困難でコストが高い。
最初から多言語を考慮することで、より広いユーザー層にリーチできる。

### VIII. Privacy by Design

ユーザーのプライバシーを設計段階から保護する。

- カメラ映像はローカル処理のみ; 外部サーバーへの送信禁止
- 顔検出データはメモリ上でのみ処理; 永続化は最小限のキャリブレーションデータのみ
- 個人を特定できる情報（PII）は収集・保存しない
- 必要な権限のみを要求し、目的を明確に説明する
- UserDefaults に保存するデータは最小限に留める

**根拠**: プライバシーはユーザーの基本的権利であり、
信頼を構築するための前提条件である。macOS App Store ガイドラインにも準拠する。

### IX. Accessibility First

すべてのユーザーが等しくアプリを利用できるようにする。

- VoiceOver でのすべての操作をサポートする
- アクセシビリティラベルは意味のある説明を提供する（日英両対応）
- 色だけに依存しない情報伝達を行う（アイコン、テキスト併用）
- 適切なフォーカス管理とキーボードナビゲーションを実装する
- Dynamic Type（システムフォントサイズ）の変更を尊重する

**根拠**: アクセシビリティは後から追加する機能ではなく、
すべてのユーザーを尊重する設計哲学である。法的要件にも関わる重要な側面。

## Development Workflow

### ブランチ戦略

- `main`: 常にリリース可能な状態を維持
- `feature/*`: 機能開発用ブランチ
- `fix/*`: バグ修正用ブランチ

### コミット規約

- 意味のある単位でコミットする
- コミットメッセージは変更の「なぜ」を説明する
- 大きな変更は小さなコミットに分割する

### コードレビュー

- すべての変更は Pull Request を通じてマージする
- Constitution への準拠を確認する
- パフォーマンスとメモリ影響を考慮する

## Governance

### 最高規範

この Constitution はプロジェクトの最高規範であり、
他のすべてのガイドラインに優先する。

### 改訂プロセス

1. 改訂提案は文書化し、理由を明記する
2. 既存コードへの影響評価を実施する
3. チームレビューと承認を経て適用する
4. バージョン番号を適切に更新する:
   - MAJOR: 後方互換性のない原則の変更・削除
   - MINOR: 新原則の追加・既存原則の拡張
   - PATCH: 文言の明確化・誤字修正

### 準拠確認

- すべての PR で Constitution 準拠をチェックする
- 複雑さの追加は明確な正当化が必要
- 開発ガイダンスは CLAUDE.md を参照する

**Version**: 1.1.0 | **Ratified**: 2025-12-30 | **Last Amended**: 2026-01-17
