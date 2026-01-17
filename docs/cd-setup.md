# CD セットアップガイド

このガイドでは、GitHub Actions による自動リリース (CD) を有効にするための手動セットアップ手順を説明します。

## 概要

タグ (`v*`) をプッシュすると、以下が自動実行されます：

1. fastlane match で署名証明書を取得
2. アプリをビルド
3. App Store Connect (TestFlight) にアップロード
4. GitHub Releases を作成

## 前提条件

- Apple Developer Program に登録済み
- App Store Connect でアプリが作成済み (Bundle ID: `cc.focuswave.Flowease`)
- GitHub リポジトリの管理者権限

## セットアップ手順

### 1. 証明書リポジトリの作成

fastlane match は署名証明書とプロビジョニングプロファイルを Git リポジトリで管理します。

1. GitHub で**プライベート**リポジトリを作成
   - 例: `github.com/<username>/flowease-certs`
   - README や .gitignore は不要（空のリポジトリ）

2. リポジトリの SSH URL をメモ
   - 例: `git@github.com:<username>/flowease-certs.git`

### 2. App Store Connect API キーの作成

1. [App Store Connect](https://appstoreconnect.apple.com/) にアクセス

2. **ユーザーとアクセス** → **統合** → **App Store Connect API** → **キー**

3. **+** ボタンでキーを生成
   - 名前: `Flowease CI` (任意)
   - アクセス: **Admin**

4. 以下の情報をメモ:
   - **Issuer ID** (ページ上部に表示)
   - **キー ID** (生成したキーの ID)

5. **.p8 ファイルをダウンロード**
   - ⚠️ ダウンロードは1回のみ。安全な場所に保管してください。

### 3. GitHub Secrets の設定

1. GitHub リポジトリの **Settings** → **Secrets and variables** → **Actions**

2. 以下の Secrets を追加:

| Secret 名 | 値 |
|-----------|-----|
| `MATCH_GIT_URL` | 証明書リポジトリの SSH URL<br>例: `git@github.com:<username>/flowease-certs.git` |
| `MATCH_PASSWORD` | match の暗号化パスワード（任意の強力なパスワード）<br>⚠️ このパスワードは後で必要になるので記録してください |
| `APP_STORE_CONNECT_API_KEY_ID` | API キー ID |
| `APP_STORE_CONNECT_API_KEY_ISSUER_ID` | Issuer ID |
| `APP_STORE_CONNECT_API_KEY_CONTENT` | .p8 ファイルを base64 エンコードした内容（下記参照） |

**.p8 ファイルの base64 エンコード:**

```bash
# macOS / Linux
base64 -i AuthKey_XXXXXXXXXX.p8 | tr -d '\n'
```

出力された文字列全体を `APP_STORE_CONNECT_API_KEY_CONTENT` に設定します。

### 4. Ruby 環境の準備（初回のみ）

macOSのシステムRubyでは権限エラーが発生するため、rbenvを使用してRubyをインストールします。

```bash
brew install rbenv
echo 'eval "$(rbenv init -)"' >> ~/.zshrc
source ~/.zshrc

# 最新の安定版をインストール（バージョンは `rbenv install -l` で確認）
rbenv install 3.4.8
rbenv global 3.4.8
```

### 5. fastlane match の初期化

ローカル環境で証明書を作成し、リポジトリにプッシュします。

```bash
# プロジェクトルートで実行
cd /path/to/Flowease

# Ruby 依存関係をインストール
bundle install

# match を初期化（すでに Matchfile があるのでスキップ可）
# bundle exec fastlane match init

# 環境変数を設定
export MATCH_GIT_URL="git@github.com:<username>/flowease-certs.git"
export MATCH_PASSWORD="<GitHub Secrets に設定したパスワード>"

# App Store 用の証明書を作成
bundle exec fastlane match appstore
```

**初回実行時の動作:**
- Apple Developer Portal で証明書とプロファイルを作成
- 暗号化して証明書リポジトリにプッシュ

**既存の証明書がある場合:**
```bash
# 既存の証明書をインポートする場合
bundle exec fastlane match import
```

### 6. 動作確認

タグをプッシュして、ワークフローが正常に動作するか確認します。

```bash
git tag v0.0.1
git push origin v0.0.1
```

GitHub の **Actions** タブでワークフローの実行状況を確認してください。

**成功した場合:**
- App Store Connect の TestFlight にビルドが表示される
- GitHub Releases にリリースが作成される

## トラブルシューティング

### match が証明書リポジトリにアクセスできない

**症状:** `Could not read from remote repository`

**解決策:**
1. GitHub Actions に SSH キーを設定するか
2. HTTPS URL + Personal Access Token を使用

```yaml
# release.yml で HTTPS を使う場合
env:
  MATCH_GIT_URL: https://${{ secrets.GH_PAT }}@github.com/<username>/flowease-certs.git
```

### 証明書が見つからない

**症状:** `Could not find a matching code signing identity`

**解決策:**
```bash
# 証明書を再作成
bundle exec fastlane match appstore --force
```

### App Store Connect へのアップロード失敗

**症状:** `Unable to upload archive`

**確認事項:**
- API キーの権限が Admin になっているか
- Bundle ID が正しいか
- バージョン番号が既存のビルドと重複していないか

## 参考リンク

- [fastlane match ドキュメント](https://docs.fastlane.tools/actions/match/)
- [App Store Connect API キー](https://developer.apple.com/documentation/appstoreconnectapi/creating_api_keys_for_app_store_connect_api)
- [GitHub Actions Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
