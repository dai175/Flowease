# Research: 英語対応

**Feature**: 004-english-support
**Date**: 2026-01-06

## Research Summary

本機能の実装にあたり、macOS/SwiftUI のローカライゼーション手法について調査を行った。

---

## Decision 1: ローカライゼーション手法

### Decision
**String Catalog（Localizable.xcstrings）** を使用する

### Rationale
- Xcode 15+ で導入された最新のローカライゼーション形式
- ビルド時に従来の .strings/.stringsdict に変換されるため、macOS 14.6+ で完全互換
- Xcode エディタで視覚的に翻訳状態を管理可能（NEW, TRANSLATED, STALE 等）
- SwiftUI の `Text`, `Button` 等は文字列リテラルを自動的に `LocalizedStringKey` として解釈

### Alternatives Considered
1. **Localizable.strings（従来形式）**: 手動での文字列管理が必要。自動抽出なし
2. **NSLocalizedString**: Foundation ベース。SwiftUI では `String(localized:)` が推奨

---

## Decision 2: コード内の文字列参照方法

### Decision
**SwiftUI View**: 文字列リテラルをそのまま使用（自動的に `LocalizedStringKey` として解釈）
**非View コード**: `String(localized:)` イニシャライザを使用

### Rationale
- SwiftUI の `Text("文字列")` は自動的にローカライズ対象となる
- Model の `description` プロパティ等、View 外で文字列を返す場合は `String(localized:)` を使用
- `NSLocalizedString` より Swift らしい構文

### Example

```swift
// View 内（自動ローカライズ）
Text("Posture Monitoring")  // → LocalizedStringKey として解釈

// Model/ViewModel 内
var description: String {
    String(localized: "Camera access denied")
}
```

### Alternatives Considered
1. **LocalizedStringKey を明示的に使用**: 冗長。SwiftUI では不要
2. **NSLocalizedString**: 動作するが、`String(localized:)` がより Swift 的

---

## Decision 3: String Catalog のファイル構成

### Decision
**単一の `Localizable.xcstrings`** を `Flowease/` ディレクトリに配置

### Rationale
- アプリの規模（30-40文字列）に対して適切
- 複数テーブルへの分割は将来的な拡張時に検討
- デフォルトのテーブル名 "Localizable" を使用することで、追加のコード変更が不要

### Alternatives Considered
1. **機能別の複数 String Catalog**: 小規模アプリには過剰。管理コスト増
2. **InfoPlist.xcstrings を別途作成**: アプリ名等のローカライズが必要になった場合に検討

---

## Decision 4: 開発言語（Development Language）

### Decision
**英語（en）** を開発言語として設定し、日本語（ja）を追加言語として設定

### Rationale
- macOS/Xcode では **Development Language がフォールバック言語**として機能する
- 仕様 FR-003 で「英語をフォールバック言語として使用」と定義されている
- サポート外言語（例：フランス語）のユーザーには英語が表示される必要がある
- 言語リストの順序だけではフォールバック動作は変わらない

### Implementation
- Xcode プロジェクト設定で Development Language を `English` に変更
- `Japanese` を Localizations に追加
- コード内の日本語文字列を英語に変更（キーとして使用）
- String Catalog で英語（キー/Development）と日本語（翻訳）のペアを定義

### Trade-offs
- 既存コードの日本語文字列をすべて英語に変更する必要がある
- 変更対象: Views（約11文字列）、Models（約13文字列）、ViewModels（約14文字列）
- 仕様要件（英語フォールバック）を満たすために必要なコスト

### Alternatives Considered
1. **日本語を開発言語として維持**: コード変更は最小だが、フォールバックが日本語になり仕様違反
2. **抽象キーを使用（例: "calibration.title"）**: クリーンだが、既存コードの全面書き換えが必要かつ可読性低下

---

## Decision 5: 日付フォーマットのローカライゼーション

### Decision
**DateFormatter に `.locale = .current` を設定**（または明示的な指定を削除）

### Rationale
- 現在のコードは `Locale(identifier: "ja_JP")` をハードコードしている
- `.locale = .current` を使用することで、システム設定に従う
- DateFormatter は自動的にユーザーのロケールに基づいたフォーマットを適用

### Current Code (CalibrationViewModel.swift)
```swift
formatter.locale = Locale(identifier: "ja_JP")  // 削除または変更
```

### Updated Code
```swift
// formatter.locale はデフォルトで .current なので、明示的な設定は不要
// または明示的に:
formatter.locale = .current
```

---

## Decision 6: テスト戦略

### Decision
**ローカライゼーションキーの存在確認テスト** を追加

### Rationale
- String Catalog で未翻訳のキーがないことを検証
- 日本語・英語両方で文字列が存在することを確認
- ビルド時に検出されないローカライゼーションエラーを防止

### Test Approach
```swift
func testAllLocalizationKeysExist() {
    let bundle = Bundle.main
    let jaBundle = Bundle(path: bundle.path(forResource: "ja", ofType: "lproj")!)!
    let enBundle = Bundle(path: bundle.path(forResource: "en", ofType: "lproj")!)!

    // 各キーが両方の言語で存在することを確認
}
```

---

## Impacted Files Summary

### Views（文字列リテラルを LocalizedStringKey として使用）
- `StatusMenuView.swift`
- `CalibrationView.swift`
- `CameraPermissionView.swift`

### Models（String(localized:) を使用）
- `DisableReason.swift` - description, actionHint プロパティ
- `PauseReason.swift` - description プロパティ
- `CalibrationFailure.swift` - userMessage プロパティ

### ViewModels（String(localized:) を使用）
- `CalibrationViewModel.swift` - qualityWarningMessage, statusText, recommendationMessage 等

### New Files
- `Flowease/Localizable.xcstrings` - String Catalog
- `FloweaseTests/LocalizationTests.swift` - テストファイル

---

## References

- [Apple Developer - Localizing and varying text with a string catalog](https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog)
- [Jacob Bartlett - Localization in Xcode 15](https://blog.jacobstechtavern.com/p/localisation-in-xcode-15)
- [SwiftyPlace - Localize iOS Apps with String Catalogs](https://www.swiftyplace.com/blog/localization-ios-app-xcode-15)
- [Belief Driven Design - Xcode String Catalogs 101](https://belief-driven-design.com/xcode-string-catalogs-101-672f5/)
- [Daniel Saidi - Localizing Swift Packages with String Catalogs](https://danielsaidi.com/blog/2025/12/02/a-better-way-to-localize-swift-packages-with-xcode-string-catalogs)
