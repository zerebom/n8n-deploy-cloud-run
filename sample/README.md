# Sample n8n Workflows

This directory contains example n8n workflows that demonstrate various use cases.

## blog_curation.json

An AI-powered blog curation workflow that:
- Reads RSS feeds from tech news sources
- Stores articles in Supabase Vector Store
- Generates weekly summaries using Google Gemini
- Sends summaries to Discord

### Setup Instructions

Before importing this workflow:

1. Replace the Discord webhook ID with your own:
   - `YOUR_DISCORD_WEBHOOK_ID` - Your Discord webhook ID

2. Configure the required credentials in n8n:
   - Google Gemini API credentials
   - Supabase API credentials
   - Discord webhook

3. Ensure your Supabase database has the `documents` table with vector support (see main README for setup)

### Security Note

The workflow file has been sanitized to remove sensitive information. Always review workflow files before importing to ensure no credentials are exposed.