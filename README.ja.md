# n8n Cloud Run デプロイメントテンプレート

[n8n](https://n8n.io)ワークフロー自動化ツールをGoogle Cloud RunとSupabaseデータベースでデプロイするためのテンプレートです。

## 特徴

- 🚀 ワンコマンドでCloud Runにデプロイ
- 🔐 Basic認証がデフォルトで有効
- 🗄️ Supabase PostgreSQLとの統合
- 📦 最小限のDocker設定
- ⚡ 本番環境に最適化

## クイックスタート

```bash
# 1. このリポジトリをクローン
git clone https://github.com/zerebom/n8n-deploy-cloud-run.git
cd n8n-deploy-cloud-run

# 2. 環境変数をコピーして設定
cp .env.sample .env
# .envファイルを編集

# 3. Cloud Runにデプロイ
./deploy.sh
```

## 前提条件

- 課金が有効なGoogle Cloudアカウント
- [gcloud CLI](https://cloud.google.com/sdk/docs/install)のインストールと設定済み
- Dockerのインストール済み
- (オプション) データベース用の[Supabase](https://supabase.com)アカウント

## 環境変数

`.env.sample`から`.env`ファイルを作成し、以下を設定してください：

| 変数名 | 説明 | 例 |
|--------|------|-----|
| `PROJECT_ID` | Google CloudプロジェクトID | `my-project-123` |
| `SERVICE_NAME` | Cloud Runサービス名 | `n8n-app` |
| `REGION` | Google Cloudリージョン | `asia-northeast1` |
| `REPOSITORY` | Artifact Registryリポジトリ名 | `n8n-repo` |
| `N8N_ENCRYPTION_KEY` | n8n認証情報の暗号化キー | `openssl rand -hex 32`で生成 |
| `N8N_BASIC_AUTH_PASSWORD` | Basic認証のパスワード | 強力なパスワード |
| `DB_TYPE` | データベースタイプ | `postgresdb` |
| `DB_POSTGRESDB_HOST` | Supabaseデータベースホスト | `your-project.supabase.co` |
| `DB_POSTGRESDB_PORT` | データベースポート | `5432` |
| `DB_POSTGRESDB_DATABASE` | データベース名 | `postgres` |
| `DB_POSTGRESDB_USER` | データベースユーザー | `postgres` |
| `DB_POSTGRESDB_PASSWORD` | データベースパスワード | Supabaseのパスワード |
| `DB_POSTGRESDB_SCHEMA` | データベーススキーマ | `public` |

## 初期設定

### 1. Google Cloud設定

```bash
# Google Cloudプロジェクトを設定
gcloud config set project YOUR_PROJECT_ID
gcloud config set compute/region asia-northeast1

# 必要なAPIを有効化
gcloud services enable run.googleapis.com
gcloud services enable cloudbuild.googleapis.com
gcloud services enable artifactregistry.googleapis.com

# Artifact Registryリポジトリを作成
gcloud artifacts repositories create n8n-repo \
  --repository-format=docker \
  --location=asia-northeast1 \
  --description="n8n Docker images"
```

### 2. データベース設定（Supabase）

Supabaseをデータベースとして使用する場合：

1. [Supabase](https://supabase.com)で新しいプロジェクトを作成
2. 設定 → データベースに移動
3. 接続詳細を`.env`ファイルにコピー
4. Vector Store機能を使用する場合は、`sample/supabase_init.sql`でデータベースを初期化

## デプロイ

デプロイスクリプトを実行：

```bash
./deploy.sh
```

スクリプトは以下を実行します：

1. Dockerイメージのビルド（x86_64向けに最適化）
2. Google Artifact Registryへのプッシュ
3. 指定された設定でCloud Runにデプロイ

## デプロイ後

デプロイが成功すると、以下が表示されます：

- サービスURL
- デフォルトユーザー名: `admin`
- パスワード: `.env`で設定したもの

### n8nへのアクセス

1. 表示されたCloud RunのURLを開く
2. Basic認証でログイン
3. n8nのセットアップウィザードを完了

## 設定

### リソース制限

`deploy.sh`を編集して調整：

- メモリ: `--memory=2Gi` (デフォルト: 2GB)
- CPU: `--cpu=1` (デフォルト: 1 vCPU)
- 最大インスタンス数: `--max-instances=10`
- 最小インスタンス数: `--min-instances=0` (ゼロスケール)

### セキュリティ

⚠️ **本番環境での重要事項**：

- 強力な暗号化キーを生成: `openssl rand -hex 32`
- Basic認証に安全なパスワードを使用
- Basic認証の代わりにGoogle Cloud IAMの使用を検討
- 機密情報はGoogle Secret Managerに保存

#### Supabaseのセキュリティ考慮事項

- **ネットワークセキュリティ**: SupabaseダッシュボードでIPアローリストを設定
- **コネクションプーリング**: 特に無料プランでは接続数制限を監視
- **シークレット管理**: データベース認証情報にGoogle Secret Managerの使用を検討
- **SSL/TLS**: 常にSSL接続を使用（Supabaseはデフォルトで強制）

## アーキテクチャ

```text
┌─────────────┐     ┌─────────────────┐     ┌──────────────┐
│  クライアント │────▶│  Cloud Run      │────▶│   Supabase   │
│  (ブラウザ)  │     │  (n8nコンテナ)   │     │  (PostgreSQL)│
└─────────────┘     └─────────────────┘     └──────────────┘
```

## トラブルシューティング

### よくある問題

1. **デプロイ後の「Cannot GET /」エラー**
   - 初回起動時（データベースマイグレーション中）は正常です
   - 1-2分待ってリフレッシュしてください

2. **Supabaseの認証エラー**
   - `.env`のデータベース認証情報を確認
   - Supabase設定でIPが許可されているか確認

3. **Apple Silicon Macでビルドが失敗**
   - スクリプトには`--platform linux/amd64`フラグが含まれています
   - Docker Desktopでマルチプラットフォームサポートが有効か確認

## FAQ

**Q: なぜ8080ではなくポート5678を使用するのですか？**  
A: n8nのデフォルトポートは5678です。Cloud Runは`--port`フラグで指定された任意のポートを処理できます。

**Q: SupabaseではなくCloud SQLを使用できますか？**  
A: はい、データベース環境変数を適切に更新するだけです。

**Q: HTTPSを有効にする方法は？**  
A: Cloud Runは自動的にHTTPSを提供します。追加設定は不要です。

## コントリビューション

プルリクエストを歓迎します！お気軽にPRを送信してください。

## ライセンス

MIT

## リソース

- [n8n ドキュメント](https://docs.n8n.io/)
- [Cloud Run ドキュメント](https://cloud.google.com/run/docs)
- [Supabase ドキュメント](https://supabase.com/docs)