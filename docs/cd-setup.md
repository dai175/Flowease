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

### 3. 証明書リポジトリへのアクセス設定

GitHub Actions からプライベートリポジトリ（`flowease-certs`）にアクセスするためのDeploy Keyを設定します。

1. SSHキーペアを生成:

```bash
ssh-keygen -t ed25519 -C "flowease-cd" -f ~/.ssh/flowease_deploy_key -N ""
```

2. **公開鍵**を証明書リポジトリに追加:
   - `flowease-certs` リポジトリ → **Settings** → **Deploy keys** → **Add deploy key**
   - Title: `GitHub Actions`
   - Key: `~/.ssh/flowease_deploy_key.pub` の内容をコピー
   - **Allow write access** はチェック不要（読み取りのみ）

3. **秘密鍵**は次のステップで GitHub Secrets に追加します

### 4. GitHub Secrets の設定

1. Flowease 本体リポジトリの **Settings** → **Secrets and variables** → **Actions**

2. 以下の Secrets を追加:

| Secret 名 | 値 |
|-----------|-----|
| `MATCH_GIT_URL` | 証明書リポジトリの SSH URL<br>例: `git@github.com:<username>/flowease-certs.git` |
| `MATCH_PASSWORD` | match の暗号化パスワード（**英数字のみ**の強力なパスワード）<br>⚠️ `$` などの特殊文字はCI環境で問題を起こすため避けてください<br>⚠️ このパスワードは後で必要になるので記録してください |
| `MATCH_DEPLOY_KEY` | 秘密鍵の内容（`~/.ssh/flowease_deploy_key`） |
| `APP_STORE_CONNECT_API_KEY_ID` | API キー ID |
| `APP_STORE_CONNECT_API_KEY_ISSUER_ID` | Issuer ID |
| `APP_STORE_CONNECT_API_KEY_CONTENT` | .p8 ファイルを base64 エンコードした内容（下記参照） |

**秘密鍵の取得:**

```bash
cat ~/.ssh/flowease_deploy_key
```

出力全体（`-----BEGIN OPENSSH PRIVATE KEY-----` から `-----END OPENSSH PRIVATE KEY-----` まで）をコピーします。

**.p8 ファイルの base64 エンコード:**

```bash
# macOS / Linux
base64 -i AuthKey_XXXXXXXXXX.p8 | tr -d '\n'
```

出力された文字列全体を `APP_STORE_CONNECT_API_KEY_CONTENT` に設定します。

### 5. Ruby 環境の準備（初回のみ）

macOSのシステムRubyでは権限エラーが発生するため、rbenvを使用してRubyをインストールします。

```bash
brew install rbenv
echo 'eval "$(rbenv init -)"' >> ~/.zshrc
source ~/.zshrc

# 最新の安定版をインストール（バージョンは `rbenv install -l` で確認）
rbenv install 3.4.8
rbenv global 3.4.8
```

### 6. fastlane match の初期化

ローカル環境で証明書を作成し、リポジトリにプッシュします。

macOS App Store 配布には2種類の証明書が必要です：
- **Mac App Distribution** - アプリ本体の署名用
- **Mac Installer Distribution** - pkg インストーラーの署名用

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

# App Store 用の証明書を作成（両方の証明書タイプを含む）
bundle exec fastlane match appstore --additional_cert_types mac_installer_distribution
```

**初回実行時の動作:**
- Apple Developer Portal で証明書とプロファイルを作成
- 暗号化して証明書リポジトリにプッシュ

**既存の証明書がある場合:**
```bash
# 既存の証明書をインポートする場合
bundle exec fastlane match import
```

**証明書を再作成する場合:**
```bash
# 強制的に再作成（既存の証明書を上書き）
bundle exec fastlane match appstore --additional_cert_types mac_installer_distribution --force
```

### 7. 動作確認

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

**症状:** `Could not read from remote repository` または `Permission denied (publickey)`

**解決策:**
1. 「3. 証明書リポジトリへのアクセス設定」の手順を確認
2. Deploy Key が証明書リポジトリに正しく追加されているか確認
3. `MATCH_DEPLOY_KEY` Secret に秘密鍵が正しく設定されているか確認

### 証明書が見つからない

**症状:** `Could not find a matching code signing identity`

**解決策:**
```bash
# 証明書を再作成
bundle exec fastlane match appstore --additional_cert_types mac_installer_distribution --force
```

### Mac Installer Distribution 証明書がない

**症状:** `No signing certificate "Mac Installer Distribution" found`

**解決策:**
pkg ファイルの署名に必要なインストーラー証明書がありません：
```bash
bundle exec fastlane match appstore --additional_cert_types mac_installer_distribution
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
