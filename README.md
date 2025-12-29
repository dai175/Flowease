# Flowease

## 開発環境セットアップ

### 前提条件

```bash
brew install swiftlint swiftformat
```

### Git Hooks のセットアップ

リポジトリをcloneした後、以下を実行してください：

```bash
cp scripts/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

これにより、コミット時に自動でSwiftFormat（自動修正）とSwiftLint（チェック）が実行されます。
