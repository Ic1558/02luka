# Secrets Setup Guide

## Required Secrets for Alerting

### 1. Slack Webhook (Recommended)
1. Go to your Slack workspace
2. Create a new app or use existing one
3. Go to "Incoming Webhooks" → "Add New Webhook to Workspace"
4. Choose channel (e.g., #alerts)
5. Copy the webhook URL
6. In GitHub: Settings → Secrets and variables → Actions → New repository secret
7. Name: `SLACK_WEBHOOK_URL`
8. Value: Your webhook URL

### 2. Microsoft Teams Webhook (Alternative)
1. Go to your Teams channel
2. Click "..." → "Connectors" → "Incoming Webhook"
3. Configure and create webhook
4. Copy the webhook URL
5. In GitHub: Settings → Secrets and variables → Actions → New repository secret
6. Name: `TEAMS_WEBHOOK_URL`
7. Value: Your webhook URL

## Testing Alerting
1. Go to Actions → Daily Proof (Option C)
2. Click "Run workflow"
3. If it fails, you should receive an alert
4. If it succeeds, no alert (as expected)

## Manual Setup Commands
```bash
# Setup branch protection
./scripts/setup-branch-protection.sh

# Setup artifact retention
./scripts/setup-artifact-retention.sh
```
