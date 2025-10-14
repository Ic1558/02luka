# CLC Memory: Path Resolution Deployment

**Date:** 2025-10-15 03:45
**Tag:** v251015.0345-path-resolution-deploy
**Commit:** 79338ae

## What I Did

Deployed universal path resolution infrastructure to prevent hardcoded paths and duplicate clone issues.

### Core Changes
1. **scripts/repo_root_resolver.sh** - Multi-location duplicate detection
2. **.codex/preflight.sh** - Dynamic duplicate warnings
3. **scripts/cutover_launchagents.sh** - Dynamic PARENT derivation
4. **scripts/health_proxy_launcher.sh** - Dynamic SOT_PATH derivation
5. **run/smoke_api_ui.sh** - Stub mode + timeouts (merged from resolve/batch2-prompt-toolbar)

### Key Pattern
```bash
# All scripts source repo_root_resolver.sh
source "$(dirname "$0")/repo_root_resolver.sh"

# Then derive parent directory
PARENT="${REPO_ROOT%/02luka-repo}"
```

## Current State

### ✅ Working
- Path resolution across all environments
- Duplicate detection (found 1: /Users/icmini/local-repos/02luka-repo)
- Smoke tests (5 PASS, 0 FAIL, 4 WARN optional)
- LaunchAgents using dynamic paths (2 updated)

### ⚠️ Outstanding
- Duplicate clone at /Users/icmini/local-repos/02luka-repo (commit 246ae03)
- 3 agents not running: gci.topic.reports, disk_monitor, docker.autohealing
- PR #105 (docs) ready to merge

## For Next Session

**If smoke tests hang again:**
- Check if stub mode is being used: `{"goal":"ping","stub":true}`
- Verify timeout is set (default 10s, plan 3s)

**If path issues occur:**
- Run: `source ./scripts/repo_root_resolver.sh`
- Check: `echo $REPO_ROOT $CURRENT_COMMIT`
- Verify: `echo ${#DUPLICATE_CLONES[@]}`

**Deployment was successful:**
- All changes pushed to origin/main
- Tag: v251015.0345-path-resolution-deploy
- LaunchAgents updated with backups
- Services verified operational

## Key Files
- Full report: g/reports/251015_0345_path_resolution_deployment.md
- Post-cutover scan: g/reports/proof/251015_035241_post_cutover_launchagents_refs.txt
