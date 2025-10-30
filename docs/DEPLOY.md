# Deployment Guide

## Prerequisites

- Git repository access
- GitHub Actions enabled
- Zsh shell (for CLS)

## Deployment Steps

### 1. Local Setup

```bash
# Clone repository
git clone git@github.com:Ic1558/02luka.git
cd 02luka

# Install dependencies (if any)
npm install

# Run tests
npm test
```

### 2. Enable CLS

```bash
# Hooks are auto-loaded from ~/.zshrc.d/
# Enable CLS learning
cls-on

# Verify
cls-status
```

### 3. Deploy to GitHub

```bash
# Commit changes
git add .
git commit -m "your changes"

# Push to main (triggers CI)
git push origin main
```

### 4. Monitor Deployment

```bash
# View workflow runs
gh run list

# Watch specific run
gh run watch

# View logs
gh run view --log
```

## Workflow Triggers

- **Push to main**: Triggers CI workflow
- **Pull Request**: Triggers validation
- **Daily (cron)**: Triggers daily-proof workflow
- **Manual**: Use `gh workflow run <workflow>`

## Troubleshooting

### CI Failures

1. Check workflow logs: `gh run view --log`
2. Verify dependencies: `npm test` locally
3. Check artifact usage: Should be `@v4`

### CLS Not Working

1. Check hooks loaded: `type _cls_precmd`
2. Verify enabled: `cls-status`
3. Check database: `wc -l ~/02luka/memory/cls/learning_db.jsonl`

## Rollback

```bash
# Revert to previous commit
git revert HEAD
git push origin main
```
