# Quickstart: 英語対応

**Feature**: 004-english-support
**Date**: 2026-01-06

## Prerequisites

- Xcode 15.0+ （String Catalog サポート）
- macOS 14.6+ ターゲット
- 既存の Flowease プロジェクトがビルド可能な状態

---

## Implementation Steps

### Step 1: String Catalog を作成

1. Xcode で `Flowease` グループを右クリック
2. **New File...** → **String Catalog** を選択
3. ファイル名: `Localizable` （.xcstrings 拡張子は自動付与）
4. ターゲット **Flowease** にチェックを入れて作成

### Step 2: Development Language を英語に設定

1. プロジェクトナビゲーターで **Flowease** プロジェクトを選択
2. **Info** タブ → **Localizations** セクション
3. Development Language が **English** であることを確認（フォールバック言語として機能）
4. **+** ボタンで **Japanese** を追加

**重要**: Development Language が英語でないと、サポート外言語のユーザーに日本語が表示されてしまう（仕様違反）

### Step 3: View の文字列を英語に変更

SwiftUI View 内の文字列リテラルを日本語から英語に変更する。英語文字列が String Catalog のキーとなる。

```swift
// Before
Text("姿勢モニタリング中")
Button("キャンセル") { ... }

// After - 英語をキーとして使用
Text("Monitoring Posture")
Button("Cancel") { ... }
```

### Step 4: Model/ViewModel の文字列を英語に変更

`String` を返すプロパティは `String(localized:)` を使用し、英語文字列をキーとして指定:

```swift
// Before
var description: String {
    switch self {
    case .cameraPermissionDenied:
        "カメラへのアクセスが拒否されています"
    ...
    }
}

// After - 英語をキーとして使用
var description: String {
    switch self {
    case .cameraPermissionDenied:
        String(localized: "Camera access denied")
    ...
    }
}
```

### Step 5: DateFormatter のロケール設定を修正

```swift
// Before (CalibrationViewModel.swift)
formatter.locale = Locale(identifier: "ja_JP")

// After - システム設定に従う
// formatter.locale はデフォルトで .current なので削除するか:
formatter.locale = .current
```

### Step 6: String Catalog に日本語翻訳を追加

1. `Localizable.xcstrings` を開く
2. ビルド後、英語文字列がキーとして自動抽出される
3. 各キーに対して **Japanese** 翻訳を入力
4. ステータスが "NEW" → "TRANSLATED" に変わることを確認

**Note**: 英語はコード内の文字列がそのまま表示されるため、String Catalog への入力は不要

### Step 7: テストを追加

```swift
// FloweaseTests/LocalizationTests.swift
import XCTest
@testable import Flowease

final class LocalizationTests: XCTestCase {
    func testDisableReasonDescriptionsExist() {
        // 各 DisableReason の description が空でないことを確認
        XCTAssertFalse(DisableReason.cameraPermissionDenied.description.isEmpty)
        XCTAssertFalse(DisableReason.cameraPermissionRestricted.description.isEmpty)
        XCTAssertFalse(DisableReason.noCameraAvailable.description.isEmpty)
    }

    func testPauseReasonDescriptionsExist() {
        XCTAssertFalse(PauseReason.cameraInitializing.description.isEmpty)
        XCTAssertFalse(PauseReason.noFaceDetected.description.isEmpty)
        XCTAssertFalse(PauseReason.cameraInUse.description.isEmpty)
        XCTAssertFalse(PauseReason.lowDetectionQuality.description.isEmpty)
    }
}
```

---

## Verification

### ビルド確認
```bash
make build
```

### テスト実行
```bash
make test
```

### 手動テスト

1. **英語環境でテスト**:
   - システム設定 → 言語と地域 → 言語を English に変更
   - アプリを再起動
   - すべてのテキストが英語で表示されることを確認

2. **日本語環境でテスト**:
   - システム設定 → 言語と地域 → 言語を日本語に変更
   - アプリを再起動
   - すべてのテキストが日本語で表示されることを確認

3. **フォールバック言語テスト（FR-003, SC-004）**:
   - システム設定 → 言語と地域 → 言語をサポート外（例：フランス語）に変更
   - アプリを再起動
   - すべてのテキストが**英語**で表示されることを確認（日本語でないこと）

---

## Common Issues

### 文字列が String Catalog に抽出されない

- **原因**: `String` 変数を渡している（リテラルでない）
- **解決**: `String(localized:)` を使用するか、`LocalizedStringKey` でラップ

### 翻訳が反映されない

- **原因**: ビルドキャッシュ
- **解決**: Product → Clean Build Folder (Cmd+Shift+K) を実行

### 日付フォーマットが変わらない

- **原因**: `Locale` がハードコードされている
- **解決**: `formatter.locale = .current` に変更または削除
