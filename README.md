# Flowease

macOS メニューバー常駐アプリケーション

## 必要条件

- macOS 14.6+
- Xcode 16.0+
- Homebrew

## 開発環境セットアップ

### 1. 依存ツールのインストール

```bash
brew install swiftlint swiftformat pre-commit
```

### 2. Git Hooks のセットアップ

```bash
make setup
```

または手動で:

```bash
pre-commit install
```

### 3. Xcode Build Phase の設定（推奨）

Xcode で SwiftLint をビルド時に自動実行するには:

1. Xcode でプロジェクトを開く
2. **Flowease** ターゲットを選択
3. **Build Settings** → 検索で「sandbox」→ **User Script Sandboxing** を **No** に変更
4. **Build Phases** タブを開く
5. **+** ボタンをクリック → **New Run Script Phase**
6. 以下のスクリプトを追加:

```bash
cd "${SRCROOT}"
if which swiftlint > /dev/null; then
  swiftlint
else
  echo "warning: SwiftLint not installed"
fi
```

7. スクリプトフェーズを **Compile Sources** の前にドラッグ
8. **Based on dependency analysis** のチェックを外す

## 開発コマンド

| コマンド | 説明 |
|---------|------|
| `make help` | 利用可能なコマンド一覧 |
| `make build` | プロジェクトをビルド |
| `make test` | テストを実行 |
| `make lint` | SwiftLint でコードをチェック |
| `make format` | SwiftFormat でコードをフォーマット |
| `make fix` | format + lint を実行 |
| `make hooks-run` | 全ファイルに対して pre-commit hooks を実行 |
| `make clean` | ビルド成果物を削除 |

## ツール設定ファイル

| ファイル | 説明 |
|---------|------|
| `.swiftlint.yml` | SwiftLint ルール設定 |
| `.swiftformat` | SwiftFormat フォーマット設定 |
| `.pre-commit-config.yaml` | Git pre-commit hooks 設定 |

## プロジェクト構成

```
Flowease/
├── Flowease/              # メインアプリケーション
│   ├── FloweaseApp.swift  # アプリエントリーポイント
│   ├── ContentView.swift  # メインビュー
│   └── Assets.xcassets/   # アセット
├── FloweaseTests/         # ユニットテスト
├── FloweaseUITests/       # UI テスト
├── .swiftlint.yml         # SwiftLint 設定
├── .swiftformat           # SwiftFormat 設定
├── .pre-commit-config.yaml # pre-commit 設定
├── .gitignore             # Git 除外設定
├── Makefile               # 開発コマンド
└── README.md              # このファイル
```
