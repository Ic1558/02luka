# CLC Agent Inbox

Work Orders (WO) for CLC agent automation.

## Structure

```
bridge/inbox/CLC/
├── README.md                           # This file
├── WO-DEPLOY-DASHBOARD.yml.example     # Dashboard deployment template
└── *.yml                               # Active work orders (processed by CLC)
```

## Usage

### 1. Create Work Order from Template

```bash
# Copy template
cp WO-DEPLOY-DASHBOARD.yml.example WO-DEPLOY-DASHBOARD.yml

# Trigger deployment
# (CLC agent watches for *.yml files in this directory)
```

### 2. Manual Execution

```bash
# Set environment
set -a; source .env.local; set +a

# Run deployment directly
bash scripts/deploy_dashboard.sh
```

### 3. GitHub Actions (Automated)

Push to main branch or manually trigger via GitHub UI:
- https://github.com/Ic1558/02luka/actions/workflows/deploy_dashboard.yml

## Work Order Lifecycle

1. **Created**: Copy `.example` template to `.yml`
2. **Queued**: CLC agent detects new work order
3. **Processing**: Agent executes steps sequentially
4. **Completed**: Report generated in `g/reports/deploy/`
5. **Archived**: Work order moved to `bridge/archive/`

## Environment Setup

```bash
# 1. Create local env file
cp .env.local.example .env.local

# 2. Edit with your credentials
nano .env.local

# 3. Load before execution
set -a; source .env.local; set +a
```

## Monitoring

- **Health**: https://dashboard.theedges.work/healthz
- **Dashboard**: https://dashboard.theedges.work
- **Reports**: `g/reports/deploy/`
- **Logs**: `$HOME/Library/Logs/02luka/com.02luka.clc.out`

## Rollback

```bash
# List recent deployment tags
git tag -l "v*_dashboard_prod" | tail -3

# Checkout previous version
git checkout v241011_1234_dashboard_prod

# Redeploy
set -a; source .env.local; set +a
bash scripts/deploy_dashboard.sh
```

## Security

- ⚠️ Never commit `.env.local` (contains secrets)
- ⚠️ Never commit API tokens in work orders
- ✅ Use GitHub Secrets for CI/CD
- ✅ Rotate tokens regularly

## Support

- Workflow docs: `memory/clc/deploy_dashboard_workflow.md`
- Deploy script: `scripts/deploy_dashboard.sh`
- GitHub workflow: `.github/workflows/deploy_dashboard.yml`
