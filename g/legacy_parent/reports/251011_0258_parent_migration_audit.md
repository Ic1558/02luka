---
project: system-stabilization
tags: [ops,migration,audit]
---

# Parent→Repo Shallow Audit (251011_0258)

## Summary
- Metadata-only (no content copy) audit completed.
- Manifests: `g/reports/proof/251011_0258_parent_manifest.tsv` vs `251011_0258_repo_manifest.tsv`
- Reference scans: LaunchAgents `251011_0258_launchagents_refs.txt`, runtime `251011_0258_runtime_refs.txt`

## File Counts
- Parent: 4983 files (boss/ + g/ + docs/)
- Repo: 793 files (boss/ + g/ + docs/)
- Difference: 4190 files in parent not in repo

## References to Parent Paths
- LaunchAgents: 14 references
- Runtime scripts: 0 references

## Next (Phase B — Cutover)
1. Review references in:
   - `g/reports/proof/251011_0258_launchagents_refs.txt`
   - `g/reports/proof/251011_0258_runtime_refs.txt`
2. Update LaunchAgents & runtime scripts to use **02luka-repo/** paths only
3. Test each agent after updating:
   ```bash
   launchctl bootout gui/$UID ~/Library/LaunchAgents/com.02luka.NAME.plist
   launchctl bootstrap gui/$UID ~/Library/LaunchAgents/com.02luka.NAME.plist
   ```
4. When zero references remain → `make boss && make proof`
5. Final step: Convert parent folders to symlinks pointing to repo

## Artifacts
- Parent manifest: `g/reports/proof/251011_0258_parent_manifest.tsv`
- Repo manifest: `g/reports/proof/251011_0258_repo_manifest.tsv`
- LaunchAgent refs: `g/reports/proof/251011_0258_launchagents_refs.txt`
- Runtime refs: `g/reports/proof/251011_0258_runtime_refs.txt`

## Analysis

### Top 10 Parent Files Not in Repo
```
boss/README.md
boss/deliverables/report_20250930_201823_41858_8ce67986.md
boss/dropbox/.processing/ambiguous.test.md
boss/dropbox/.processing/selftest_20250930_172041_dangerous;rm-rf.txt
boss/dropbox/.processing/test_ambiguous.md
boss/dropbox/selftest_20250930_235928_dangerous;rm-rf.txt
boss/dropbox/selftest_20251001_001154_dangerous;rm-rf.txt
boss/dropbox/selftest_20251001_002222_dangerous;rm-rf.txt
boss/dropbox/selftest_20251001_003032_dangerous;rm-rf.txt
boss/dropbox/selftest_20251001_003343_dangerous;rm-rf.txt
```

### LaunchAgent References (sample)
```
/Users/icmini/Library/LaunchAgents/.disabled/com.02luka.dashboard.update.plist:7:    <string>/Users/icmini/My Drive/02luka/g/tools/update_dashboard.sh</string>
/Users/icmini/Library/LaunchAgents/.disabled/com.02luka.catalog_sync_probe.plist:9:        <string>/Users/icmini/My Drive/02luka/g/tools/lib/catalog_sync_probe.sh</string>
/Users/icmini/Library/LaunchAgents/com.02luka.localworker.bg.plist:8:		<string>/Users/icmini/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My Drive/02luka/google_drive</string>
/Users/icmini/Library/LaunchAgents/com.02luka.gci.topic.reports.plist:8:    <string>LUKA_ROOT="$HOME/My Drive/02luka" "$HOME/My Drive/02luka/g/tools/routines/gci_topic_report.sh" && for t in system governance clc gci core general; do LUKA_ROOT="$HOME/My Drive/02luka" "$HOME/My Drive/02luka/g/tools/routines/gci_topic_reason_summarize.sh" "$t" || true; done</string>
/Users/icmini/Library/LaunchAgents/com.02luka.clc.dispatcher.plist.new:10:        <string>/Users/icmini/My Drive/02luka/g/scripts/clc_dispatcher.py</string>
/Users/icmini/Library/LaunchAgents/com.02luka.mcp.server.fs_local.plist:17:	<string>/Users/icmini/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My Drive/02luka/g/logs/mcp_fs_local.err</string>
/Users/icmini/Library/LaunchAgents/com.02luka.mcp.server.fs_local.plist:19:	<string>/Users/icmini/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My Drive/02luka/g/logs/mcp_fs_local.out</string>
/Users/icmini/Library/LaunchAgents/.backup_20251004_155010/com.02luka.agent.lisa.plist:21:		<string>/Users/icmini/My Drive/02luka/g/scripts/lisa_agent.py</string>
/Users/icmini/Library/LaunchAgents/com.02luka.disk_monitor.plist:12:        <string>chmod +x "/Users/icmini/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My Drive/02luka/g/tools/disk_monitor.sh" && "/Users/icmini/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My Drive/02luka/g/tools/disk_monitor.sh"</string>
/Users/icmini/Library/LaunchAgents/com.docker.autohealing.plist:10:        <string>/Users/icmini/My Drive/02luka/g/tools/docker_autohealing.sh</string>
```

### Runtime References (sample)
```

```
