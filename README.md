# n8nをGoogle Cloud Runにデプロイする完全ガイド

## 概要
このブログでは、ワークフロー自動化ツール「n8n」をGoogle Cloud Runにデプロイし、SupabaseをVector Storeとして設定する方法を詳しく解説します。

## 前提条件
- Google Cloudアカウント
- Supabaseアカウントとプロジェクト（オプション）
- Docker環境
- gcloud CLIの設定済み

## セットアップ

### 環境変数の設定
1. `.env.sample`をコピーして`.env`ファイルを作成：
   ```bash
   cp .env.sample .env
   ```

2. `.env`ファイルを編集して実際の値を設定：
   ```bash
   # Google Cloud設定
   PROJECT_ID=your-google-cloud-project-id
   SERVICE_NAME=n8n-app
   REGION=asia-northeast1
   REPOSITORY=n8n-repo

   # n8n設定
   N8N_ENCRYPTION_KEY=your-secure-encryption-key
   N8N_BASIC_AUTH_PASSWORD=your-basic-auth-password

   # Supabaseデータベース設定
   DB_TYPE=postgresdb
   DB_POSTGRESDB_HOST=your-supabase-host.supabase.co
   DB_POSTGRESDB_PORT=5432
   DB_POSTGRESDB_DATABASE=postgres
   DB_POSTGRESDB_USER=postgres
   DB_POSTGRESDB_PASSWORD=your-supabase-password
   DB_POSTGRESDB_SCHEMA=public
   ```

3. **重要**: `.env`ファイルはGitにコミットしないでください（.gitignoreに含まれています）

## 1. プロジェクト初期設定

### 1.1 Google Cloud設定
```bash
# アカウント切り替え
gcloud config set account your-email@gmail.com
gcloud config set project your-project-id
gcloud config set compute/region asia-northeast1

# 必要なAPIを有効化
gcloud services enable run.googleapis.com cloudbuild.googleapis.com containerregistry.googleapis.com artifactregistry.googleapis.com
```

### 1.2 Artifact Registry作成
```bash
# Dockerリポジトリ作成
gcloud artifacts repositories create n8n-repo --repository-format=docker --location=asia-northeast1 --description="n8n Docker repository"
```

## 2. ファイル構成

### 2.1 Dockerfile（最終版）
```dockerfile
FROM docker.n8n.io/n8nio/n8n
```

**重要ポイント**：
- 公式推奨イメージ `docker.n8n.io/n8nio/n8n` を使用
- 余計な設定は一切追加しない
- デフォルトのポート5678をそのまま使用

### 2.2 デプロイスクリプト（deploy.sh）
```bash
#!/bin/bash

set -e

# .envファイルから環境変数を読み込み
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
else
    echo "⚠️  .envファイルが見つかりません。.env.sampleをコピーして設定してください。"
    exit 1
fi

# 設定
IMAGE_NAME="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPOSITORY}/${SERVICE_NAME}"

echo "🚀 n8nをCloud Runにデプロイします..."

# 1. Artifact Registryの認証設定
echo "🔐 Artifact Registryの認証設定..."
gcloud auth configure-docker ${REGION}-docker.pkg.dev

# 2. Dockerイメージをビルド (x86_64アーキテクチャ用)
echo "📦 Dockerイメージをビルド中 (x86_64)..."
docker build --platform linux/amd64 -t ${IMAGE_NAME} .

# 3. Artifact Registryにプッシュ
echo "⬆️  イメージをArtifact Registryにプッシュ中..."
docker push ${IMAGE_NAME}

# 4. Cloud Runにデプロイ
echo "🌐 Cloud Runにデプロイ中..."
gcloud run deploy ${SERVICE_NAME} \
  --image=${IMAGE_NAME} \
  --platform=managed \
  --region=${REGION} \
  --allow-unauthenticated \
  --port=5678 \
  --memory=2Gi \
  --cpu=1 \
  --max-instances=10 \
  --timeout=900 \
  --min-instances=0 \
  --set-env-vars="N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY},DB_TYPE=${DB_TYPE},DB_POSTGRESDB_HOST=${DB_POSTGRESDB_HOST},DB_POSTGRESDB_PORT=${DB_POSTGRESDB_PORT},DB_POSTGRESDB_DATABASE=${DB_POSTGRESDB_DATABASE},DB_POSTGRESDB_USER=${DB_POSTGRESDB_USER},DB_POSTGRESDB_PASSWORD=${DB_POSTGRESDB_PASSWORD},DB_POSTGRESDB_SCHEMA=${DB_POSTGRESDB_SCHEMA},N8N_BASIC_AUTH_ACTIVE=true,N8N_BASIC_AUTH_USER=admin,N8N_BASIC_AUTH_PASSWORD=${N8N_BASIC_AUTH_PASSWORD}"

# 5. デプロイ完了メッセージ
echo "✅ デプロイ完了！"
echo "🔗 URL: $(gcloud run services describe ${SERVICE_NAME} --region=${REGION} --format='value(status.url)')"
echo "👤 ユーザー名: admin"
echo "🔑 パスワード: ${N8N_BASIC_AUTH_PASSWORD}"
echo ""
echo "⚠️  重要: 本番環境では必ずパスワードと暗号化キーを変更してください！"
```

## 3. ハマったポイントと解決策

### 3.1 アーキテクチャ問題
**問題**: MacのApple Silicon（ARM）で作成したイメージがCloud Run（x86_64）で動かない
```bash
# エラー例
terminated: Application failed to start: failed to load /sbin/tini: exec format error
```

**解決策**: `--platform linux/amd64` フラグでクロスコンパイル
```bash
docker build --platform linux/amd64 -t ${IMAGE_NAME} .
```

### 3.2 ポート設定の混乱
**試行錯誤の経緯**：
1. 最初：Cloud Run標準の8080ポートを使用 → 失敗
2. 中間：環境変数でポート変更を試行 → 失敗
3. 最終：n8nデフォルトの5678ポートをそのまま使用 → 成功

**重要な学び**：
- Cloud Runは `--port` フラグで任意のポートを指定可能
- n8nの公式設定をそのまま使うのがベスト

### 3.3 Container Registry vs Artifact Registry
**問題**: 古いGoogle Container Registry（GCR）を使用していた
```bash
# 廃止予定のGCR
IMAGE_NAME="gcr.io/${PROJECT_ID}/${SERVICE_NAME}"
```

**解決策**: Artifact Registryに移行
```bash
# 推奨のArtifact Registry
IMAGE_NAME="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPOSITORY}/${SERVICE_NAME}"
```

### 3.4 環境変数の過剰設定
**失敗例**：
```bash
# 過剰な環境変数設定
--set-env-vars="N8N_PORT=8080,N8N_HOST=0.0.0.0,N8N_PROTOCOL=https,NODE_ENV=production,N8N_LOG_LEVEL=info,N8N_BASIC_AUTH_ACTIVE=true,..."
```

**成功例**：
```bash
# 最小限の設定
--set-env-vars="N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}"
```

## 4. 起動プロセスの理解

### 4.1 正常な起動フロー
1. `n8n is starting up. Please wait` （起動中）
2. `Cannot GET /` （マイグレーション実行中、約1分）
3. HTMLページ表示（WebUI起動完了）

### 4.2 デバッグ手順
```bash
# ログ確認
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=n8n-app" --limit=20

# サービス状態確認
gcloud run services describe n8n-app --region=asia-northeast1

# 動作確認
curl -I https://your-service-url.a.run.app/
```

## 5. Supabase Vector Store設定

### 5.1 データベース初期化
```sql
-- 既存テーブル削除（必要に応じて）
DROP TABLE IF EXISTS documents CASCADE;
DROP FUNCTION IF EXISTS match_documents;

-- pgvector拡張有効化
CREATE EXTENSION IF NOT EXISTS vector;

-- documentsテーブル作成
CREATE TABLE documents (
  id BIGSERIAL PRIMARY KEY,
  content TEXT,
  metadata JSONB,
  embedding VECTOR(1536)
);

-- インデックス作成
CREATE INDEX ON documents USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

-- n8n用関数作成
CREATE OR REPLACE FUNCTION match_documents (
  query_embedding VECTOR(1536),
  match_count INT DEFAULT NULL,
  filter JSONB DEFAULT '{}'
) RETURNS TABLE (
  id BIGINT,
  content TEXT,
  metadata JSONB,
  similarity FLOAT
)
LANGUAGE plpgsql
AS $$
#variable_conflict use_column
BEGIN
  RETURN QUERY
  SELECT
    id,
    content,
    metadata,
    1 - (documents.embedding <=> query_embedding) AS similarity
  FROM documents
  WHERE metadata @> filter
  ORDER BY documents.embedding <=> query_embedding
  LIMIT match_count;
END;
$$;
```

### 5.2 n8nでの認証設定
- **Host**: `https://your-project.supabase.co`
- **Service Role Secret**: Supabaseダッシュボード > Settings > API > service_role key

## 6. 重要な学び

### 6.1 公式ドキュメントの重要性
- n8n公式では `docker.n8n.io/n8nio/n8n` イメージを推奨
- デフォルト設定をそのまま使うのが最も安全

### 6.2 デバッグのアプローチ
1. **ローカルテスト**: 問題の切り分け
2. **ログ確認**: Cloud Runのログを詳細に確認
3. **段階的アプローチ**: 最小構成から始めて徐々に機能追加

### 6.3 Cloud Runの特性理解
- `PORT` 環境変数の自動設定
- `--port` フラグでカスタムポート指定可能
- ステートレス特性（外部DBが必要）

## 7. まとめ

n8nのCloud Runデプロイは以下のポイントを押さえれば成功します：

1. **公式イメージをそのまま使用**
2. **最小限の環境変数設定**
3. **適切なポート設定（5678）**
4. **Artifact Registryの使用**
5. **アーキテクチャの考慮（x86_64）**

最終的に非常にシンプルな構成で動作し、SupabaseとVector Storeとしても連携できました。

## 8. 実際のファイル構成

```
n8n-deploy-cloud-run/
├── Dockerfile              # シンプルなDockerfile
├── deploy.sh               # デプロイスクリプト
├── .env.sample            # 環境変数テンプレート
└── README.md              # このドキュメント
```

このガイドが同様の課題を抱える方の参考になれば幸いです。
