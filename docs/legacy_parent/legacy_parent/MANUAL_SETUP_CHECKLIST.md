# Manual Setup Checklist

## 🔔 Alerting Setup
- [ ] Add `SLACK_WEBHOOK_URL` secret in GitHub repository settings
- [ ] (Optional) Add `TEAMS_WEBHOOK_URL` secret for Teams alerts
- [ ] Test alerting by running Daily Proof workflow manually

## 🔒 Branch Protection
- [ ] Run: `./scripts/setup-branch-protection.sh`
- [ ] Verify protection rules in GitHub → Settings → Branches
- [ ] Test by trying to push directly to main (should be blocked)

## 📦 Artifact Retention
- [ ] Run: `./scripts/setup-artifact-retention.sh`
- [ ] Manually set retention to 30 days in GitHub → Settings → Actions → General
- [ ] Enable "Allow GitHub Actions to create and approve pull requests"

## 🧪 Testing
- [ ] Run Daily Proof workflow manually: Actions → Daily Proof (Option C) → Run workflow
- [ ] Verify `latest-proof` artifact is created
- [ ] Test branch protection by creating a PR
- [ ] Test alerting by intentionally failing a workflow

## ✅ Verification
- [ ] All secrets are configured
- [ ] Branch protection is active
- [ ] Artifact retention is set to 30 days
- [ ] Alerting works (test with failed workflow)
- [ ] Daily Proof workflow runs successfully

## 🚨 Emergency Procedures
- [ ] Document rollback procedure: `git checkout v2.0`
- [ ] Test rollback procedure
- [ ] Document breakglass procedure: `chmod -x .git/hooks/pre-commit`
- [ ] Create `docs/BREAKGLASS.md` with emergency procedures
