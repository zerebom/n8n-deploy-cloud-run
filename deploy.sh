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