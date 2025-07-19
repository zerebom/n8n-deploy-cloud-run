# n8n Cloud Run Deployment Template

A ready-to-use template for deploying [n8n](https://n8n.io) workflow automation tool on Google Cloud Run with Supabase as the database backend.

## Features

- 🚀 One-command deployment to Google Cloud Run
- 🔐 Basic authentication enabled by default
- 🗄️ Supabase PostgreSQL integration
- 📦 Minimal Docker configuration
- ⚡ Optimized for production use

## Quick Start

```bash
# 1. Clone this repository
git clone https://github.com/zerebom/n8n-deploy-cloud-run.git
cd n8n-deploy-cloud-run

# 2. Copy and configure environment variables
cp .env.sample .env
# Edit .env with your values

# 3. Deploy to Cloud Run
./deploy.sh
```

## Prerequisites

- Google Cloud account with billing enabled
- [gcloud CLI](https://cloud.google.com/sdk/docs/install) installed and configured
- Docker installed
- (Optional) [Supabase](https://supabase.com) account for database

## Environment Variables

Create a `.env` file from `.env.sample` and configure the following:

| Variable | Description | Example |
|----------|-------------|---------|
| `PROJECT_ID` | Your Google Cloud project ID | `my-project-123` |
| `SERVICE_NAME` | Cloud Run service name | `n8n-app` |
| `REGION` | Google Cloud region | `asia-northeast1` |
| `REPOSITORY` | Artifact Registry repository name | `n8n-repo` |
| `N8N_ENCRYPTION_KEY` | Encryption key for n8n credentials | Generate with `openssl rand -hex 32` |
| `N8N_BASIC_AUTH_PASSWORD` | Password for basic authentication | Strong password |
| `DB_TYPE` | Database type | `postgresdb` |
| `DB_POSTGRESDB_HOST` | Supabase database host | `your-project.supabase.co` |
| `DB_POSTGRESDB_PORT` | Database port | `5432` |
| `DB_POSTGRESDB_DATABASE` | Database name | `postgres` |
| `DB_POSTGRESDB_USER` | Database user | `postgres` |
| `DB_POSTGRESDB_PASSWORD` | Database password | Your Supabase password |
| `DB_POSTGRESDB_SCHEMA` | Database schema | `public` |

## Initial Setup

### 1. Google Cloud Configuration

```bash
# Set up your Google Cloud project
gcloud config set project YOUR_PROJECT_ID
gcloud config set compute/region asia-northeast1

# Enable required APIs
gcloud services enable run.googleapis.com
gcloud services enable cloudbuild.googleapis.com
gcloud services enable artifactregistry.googleapis.com

# Create Artifact Registry repository
gcloud artifacts repositories create n8n-repo \
  --repository-format=docker \
  --location=asia-northeast1 \
  --description="n8n Docker images"
```

### 2. Database Setup (Supabase)

If using Supabase as your database:

1. Create a new project at [Supabase](https://supabase.com)
2. Go to Settings → Database
3. Copy the connection details to your `.env` file
4. Initialize the database with the SQL script in `sample/supabase_init.sql` (if using vector store features)

## Deployment

Run the deployment script:

```bash
./deploy.sh
```

The script will:

1. Build a Docker image (optimized for x86_64)
2. Push it to Google Artifact Registry
3. Deploy to Cloud Run with the specified configuration

## Post-Deployment

After successful deployment, you'll see:

- Service URL
- Default username: `admin`
- Password: The one you set in `.env`

### Accessing n8n

1. Open the provided Cloud Run URL
2. Log in with basic authentication
3. Complete n8n setup wizard

## Configuration

### Resource Limits

Edit `deploy.sh` to adjust:

- Memory: `--memory=2Gi` (default: 2GB)
- CPU: `--cpu=1` (default: 1 vCPU)
- Max instances: `--max-instances=10`
- Min instances: `--min-instances=0` (scales to zero)

### Security

⚠️ **Important for Production**:

- Generate a strong encryption key: `openssl rand -hex 32`
- Use a secure password for basic authentication
- Consider using Google Cloud IAM for authentication instead of basic auth
- Store sensitive values in Google Secret Manager

#### Supabase Security Considerations

- **Network Security**: Configure IP allowlist in Supabase dashboard
- **Connection Pooling**: Monitor connection limits, especially on free tier
- **Secrets Management**: Consider using Google Secret Manager for database credentials
- **SSL/TLS**: Always use SSL connections (Supabase enforces this by default)

## Architecture

```text
┌─────────────┐     ┌─────────────────┐     ┌──────────────┐
│   Client    │────▶│  Cloud Run      │────▶│   Supabase   │
│  (Browser)  │     │  (n8n container)│     │  (PostgreSQL)│
└─────────────┘     └─────────────────┘     └──────────────┘
```

## Troubleshooting

### Common Issues

1. **"Cannot GET /" error after deployment**
   - This is normal during initial startup (database migrations)
   - Wait 1-2 minutes and refresh

2. **Authentication errors with Supabase**
   - Verify database credentials in `.env`
   - Check if your IP is allowed in Supabase settings

3. **Build fails on Apple Silicon Macs**
   - The script includes `--platform linux/amd64` flag
   - Ensure Docker Desktop has multi-platform support enabled

## FAQ

**Q: Why use port 5678 instead of 8080?**  
A: n8n defaults to port 5678. Cloud Run can handle any port specified with `--port` flag.

**Q: Can I use Cloud SQL instead of Supabase?**  
A: Yes, just update the database environment variables accordingly.

**Q: How do I enable HTTPS?**  
A: Cloud Run automatically provides HTTPS. No additional configuration needed.

## Contributing

Pull requests are welcome! Please feel free to submit a PR.

## License

MIT

## Resources

- [n8n Documentation](https://docs.n8n.io/)
- [Cloud Run Documentation](https://cloud.google.com/run/docs)
- [Supabase Documentation](https://supabase.com/docs)
