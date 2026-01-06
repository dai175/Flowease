# Feature Specification: 英語対応

**Feature Branch**: `004-english-support`
**Created**: 2026-01-06
**Status**: Draft
**Input**: User description: "英語対応"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - デバイス言語に応じた自動言語切り替え (Priority: P1)

英語設定のmacOSを使用しているユーザーとして、アプリを起動したときに、自動的に英語のUIが表示されることで、言語の壁なくアプリを使用できる。

**Why this priority**: グローバルユーザーにとって最も基本的な要件。英語環境のユーザーがアプリを使用できるようになる最小限の機能。

**Independent Test**: 英語設定のmacOS上でアプリを起動し、すべてのUI要素が英語で表示されることを確認できる。

**Acceptance Scenarios**:

1. **Given** macOSの言語設定が英語、**When** Floweaseアプリを起動、**Then** メニューバーのポップオーバー内のすべてのテキストが英語で表示される
2. **Given** macOSの言語設定が日本語、**When** Floweaseアプリを起動、**Then** メニューバーのポップオーバー内のすべてのテキストが日本語で表示される
3. **Given** macOSの言語設定がサポート外の言語（例：フランス語）、**When** Floweaseアプリを起動、**Then** フォールバック言語（英語）でUIが表示される

---

### User Story 2 - キャリブレーション画面の英語表示 (Priority: P2)

英語環境のユーザーとして、キャリブレーション機能を使用するときに、説明文やボタンが英語で表示されることで、適切な姿勢の基準を正しく設定できる。

**Why this priority**: キャリブレーション機能はアプリの主要機能であり、ユーザーが正しく操作するためには適切な言語での説明が必要。

**Independent Test**: 英語設定でキャリブレーション画面を開き、すべての説明・ボタン・状態メッセージが英語で表示されることを確認。

**Acceptance Scenarios**:

1. **Given** macOSの言語設定が英語、**When** キャリブレーション画面を開く、**Then** 画面タイトル「Posture Calibration」が表示される
2. **Given** macOSの言語設定が英語かつキャリブレーション未設定、**When** キャリブレーション画面を開く、**Then** 「Start」「Cancel」ボタンが表示される
3. **Given** macOSの言語設定が英語かつキャリブレーション実行中、**When** 画面を確認、**Then** 「Maintain your posture...」などの進捗メッセージが英語で表示される
4. **Given** macOSの言語設定が英語かつキャリブレーション完了、**When** 画面を確認、**Then** 「Calibration Complete」メッセージが英語で表示される

---

### User Story 3 - エラーメッセージの英語表示 (Priority: P2)

英語環境のユーザーとして、カメラ権限エラーや顔検出失敗などの問題が発生したときに、英語でエラーメッセージと対処法が表示されることで、問題を理解し解決できる。

**Why this priority**: エラー状況での適切なコミュニケーションはユーザー体験に直結し、サポートコストの削減にもつながる。

**Independent Test**: 英語設定でカメラ権限を拒否した状態でアプリを起動し、エラーメッセージと対処法が英語で表示されることを確認。

**Acceptance Scenarios**:

1. **Given** macOSの言語設定が英語かつカメラ権限が拒否、**When** アプリを起動、**Then** 「Camera access denied」メッセージと「Open System Settings」ボタンが表示される
2. **Given** macOSの言語設定が英語かつカメラが使用中、**When** アプリを起動、**Then** 「Camera is being used by another app」メッセージが表示される
3. **Given** macOSの言語設定が英語かつ顔が検出されない、**When** 姿勢モニタリング中、**Then** 「Face not detected」メッセージが表示される

---

### User Story 4 - 日付・時刻の地域フォーマット対応 (Priority: P3)

各地域のユーザーとして、キャリブレーション完了日時などの日付・時刻が、自分の地域のフォーマットで表示されることで、直感的に情報を理解できる。

**Why this priority**: 日付フォーマットはユーザー体験の細部であり、基本的な翻訳対応が完了した後の改善項目。

**Independent Test**: 英語設定でキャリブレーションを完了し、完了日時が英語圏のフォーマット（例：1/6/26, 10:30 AM）で表示されることを確認。

**Acceptance Scenarios**:

1. **Given** macOSの地域設定がUS英語かつキャリブレーション完了済み、**When** キャリブレーション状態を表示、**Then** 完了日時が「1/6/26, 10:30 AM」形式で表示される
2. **Given** macOSの地域設定が日本かつキャリブレーション完了済み、**When** キャリブレーション状態を表示、**Then** 完了日時が「2026/01/06 10:30」形式で表示される

---

### Edge Cases

- デバイスの言語設定が途中で変更された場合 → アプリ再起動後に新しい言語が適用される
- 翻訳が欠落している文字列がある場合 → 英語（フォールバック）が表示される
- 極端に長い翻訳文字列がある場合 → UIレイアウトが崩れない（テキストは適切に切り詰めまたは折り返しされる）

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST display all user-facing text in the user's preferred language (English or Japanese)
- **FR-002**: System MUST automatically detect the device's language setting and apply the appropriate localization
- **FR-003**: System MUST use English as the fallback language for unsupported locales
- **FR-004**: System MUST localize the following UI elements:
  - メニューバーポップオーバーのテキスト（「姿勢モニタリング中」等）
  - キャリブレーション画面のすべてのテキスト
  - カメラ権限エラーメッセージと対処法
  - 一時停止理由メッセージ
  - ボタンラベル（「設定」「リセット」「開始」「キャンセル」等）
- **FR-005**: System MUST format dates and times according to the user's locale settings
- **FR-006**: System MUST maintain consistent terminology across all translated text

### Key Entities

- **LocalizedString**: ユーザーに表示されるすべてのテキスト。キー、言語別の翻訳値を持つ
- **Locale**: ユーザーのデバイス設定から取得される言語・地域情報。言語コード、地域コードを含む

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 英語設定のmacOSでアプリを起動した際、すべてのUI文字列が英語で表示される（100%カバレッジ）
- **SC-002**: 日本語設定のmacOSでアプリを起動した際、既存の日本語UIが維持される（リグレッションなし）
- **SC-003**: 英語翻訳のすべての文字列がUIレイアウトに収まり、切り詰めや折り返しが適切に行われる
- **SC-004**: サポート外の言語設定でアプリを起動した際、英語がフォールバックとして表示される
- **SC-005**: 日付・時刻がユーザーのロケール設定に応じたフォーマットで表示される

## Assumptions

- macOS標準のローカライゼーション機構（String Catalog / Localizable.strings）を使用する
- 対応言語は日本語（ja）と英語（en）の2言語のみ
- アプリ内で言語を手動で切り替える機能は提供しない（OSの言語設定に従う）
- 翻訳は開発チーム内で行い、外部翻訳サービスは使用しない
