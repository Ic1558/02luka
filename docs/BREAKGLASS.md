# Breakglass Procedures

## 🚨 Emergency Access

### Temporarily Disable Pre-commit Hook
```bash
# Disable pre-commit hook temporarily
chmod -x .git/hooks/pre-commit

# Make your emergency changes
git add .
git commit -m "emergency: [describe the issue]"

# Re-enable pre-commit hook
chmod +x .git/hooks/pre-commit
```

### Rollback to Stable Version
```bash
# Rollback to v2.0 tag
git checkout v2.0

# Create emergency branch from stable version
git checkout -b emergency-fix

# Make emergency fixes
# ... make changes ...

# Commit and push
git add .
git commit -m "emergency: fix [issue description]"
git push origin emergency-fix

# Create PR to main
gh pr create --title "Emergency Fix: [issue]" --body "Emergency fix for [issue description]"
```

### Bypass CI Checks (Emergency Only)
```bash
# Create PR with bypass
gh pr create --title "Emergency Fix: [issue]" --body "Emergency fix for [issue description]" --head emergency-fix --base main

# Merge with bypass (requires admin access)
gh pr merge [PR_NUMBER] --merge --admin
```

## 🔧 Recovery Procedures

### Restore from Backup
```bash
# List available tags
git tag -l

# Checkout specific version
git checkout v2.0

# Create recovery branch
git checkout -b recovery-$(date +%Y%m%d)
```

### Reset to Clean State
```bash
# Reset to last known good commit
git reset --hard [COMMIT_HASH]

# Force push (dangerous - use with caution)
git push --force-with-lease origin [BRANCH_NAME]
```

## 📞 Emergency Contacts
- **Primary**: [Your contact info]
- **Secondary**: [Backup contact info]
- **Slack Channel**: #alerts
- **Teams Channel**: [Teams channel]

## 🚨 When to Use Breakglass
- Production system down
- Security incident
- Data corruption
- Critical bug affecting users
- **NOT for**: Regular development, minor issues, convenience

## 📋 Post-Emergency Checklist
- [ ] Document what happened
- [ ] Create incident report
- [ ] Update procedures if needed
- [ ] Notify team of resolution
- [ ] Schedule post-mortem if needed
