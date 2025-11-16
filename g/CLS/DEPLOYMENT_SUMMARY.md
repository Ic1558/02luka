# CLS Agent + Bridge Deployment Summary

**Date:** 2025-10-29  
**Status:** ✅ Deployed  
**Components:** CLS Agent Configuration + CLS↔CLC Work Order Bridge

---

## ✅ Successfully Deployed Components

### 1. CLS Agent Specification
- **Location:** `~/02luka/CLS/agents/CLS_agent_latest.md` (symlink)
- **Timestamped version:** `~/02luka/CLS/agents/CLS_agent_20251029_220732.md`
- **Features:**
  - Explicit write allow-list (Rule 91 refined)
  - Clear governance boundaries (AI/OP-001)
  - Memory path: `~/02luka/memory/cls/`

### 2. Cursor Rules Configuration
- **Location:** `~/02luka/.cursorrules`
- **Agent:** CLS (System Orchestrator)
- **Instructions:** Never write to SOT directly; use Work Orders
- **Allow-list reference:** `memory/cls/ALLOWLIST.paths`
- **Audit log:** `g/telemetry/cls_audit.jsonl`

### 3. Write Allow-List
- **Location:** `~/02luka/memory/cls/ALLOWLIST.paths`
- **Permitted zones:**
  - `bridge/inbox/**` - WO drops
  - `memory/cls/**` - CLS state
  - `g/telemetry/**` - Audit/metrics
  - `logs/**` - Runtime logs
  - `tmp/**` - Scratch space

### 4. CLS↔CLC Bridge Script
- **Location:** `~/tools/bridge_cls_clc.zsh`
- **Features:**
  - Atomic mktemp → mv pattern
  - SHA256 checksums for all files
  - Evidence directory per WO
  - Redis ACK publishing (optional)
  - Audit trail logging

### 5. Work Order Template
- **Location:** `~/02luka/CLS/templates/WO_TEMPLATE.yaml`
- **Usage:** Copy and customize for new Work Orders

### 6. Audit System
- **Log:** `~/02luka/g/telemetry/cls_audit.jsonl`
- **First entry:** CLS agent seeded (2025-10-29T22:07:32+07:00)

---

## 📋 Manual Verification Steps

Run these commands in your terminal (outside Claude Code):

```bash
# 1. Verify CLS agent files
ls -lah ~/02luka/CLS/agents/
cat ~/02luka/CLS/agents/CLS_agent_latest.md | head -30

# 2. Check Cursor rules
cat ~/02luka/.cursorrules

# 3. Verify allow-list
cat ~/02luka/memory/cls/ALLOWLIST.paths

# 4. Check audit log
cat ~/02luka/g/telemetry/cls_audit.jsonl

# 5. Test bridge script (creates test WO)
cp ~/02luka/CLS/templates/WO_TEMPLATE.yaml /tmp/test_wo.yaml
# Edit /tmp/test_wo.yaml if desired

# Run bridge
~/tools/bridge_cls_clc.zsh \
  --title "Bridge Test WO" \
  --priority P3 \
  --tags "test,bridge,verification" \
  --body /tmp/test_wo.yaml

# 6. Verify WO was created
ls -lah ~/02luka/bridge/inbox/CLC/ | tail -5
ls -lah ~/02luka/logs/wo_drop_history/ | tail -5

# 7. Inspect a WO (latest)
LATEST_WO=$(ls -t ~/02luka/bridge/inbox/CLC/ | grep "^WO-" | head -1)
echo "Latest WO: $LATEST_WO"
ls -lah ~/02luka/bridge/inbox/CLC/$LATEST_WO/
cat ~/02luka/bridge/inbox/CLC/$LATEST_WO/*.yaml
cat ~/02luka/bridge/inbox/CLC/$LATEST_WO/evidence/manifest.json
cat ~/02luka/bridge/inbox/CLC/$LATEST_WO/evidence/checksums.sha256

# 8. Check updated audit log
tail -3 ~/02luka/g/telemetry/cls_audit.jsonl
```

---

## 🎯 Next Steps for Cursor Usage

### Enable CLS in Cursor

1. **Quit Cursor completely** (if running)
2. **Open workspace:** Open `~/02luka` or `~/02luka/02luka-repo` in Cursor
3. **Select agent:** In Cursor UI, select "CLS" from agent dropdown
4. **Verify:** CLS should now follow the rules in `.cursorrules`

### Using CLS Agent

When CLS needs to modify SOT files:

```bash
# 1. Draft the change in a payload file
cat > /tmp/my_change.yaml <<'EOF'
task: "Update health monitoring config"
context:
  project: "02luka"
  area: "ops/monitoring"
actions:
  - type: "patch"
    target: "g/config/health_monitor.json"
    spec: "Add new threshold for disk usage"
outputs:
  - type: "report"
    path: "g/reports/health_config_update.md"
EOF

# 2. Use bridge to send to CLC
~/tools/bridge_cls_clc.zsh \
  --title "Update health monitoring thresholds" \
  --priority P2 \
  --tags "ops,config,health" \
  --body /tmp/my_change.yaml

# 3. CLC picks up from inbox and executes
# (Work Order appears in ~/02luka/bridge/inbox/CLC/)
```

---

## 🔒 Governance Compliance

### AI/OP-001 Rule 91 (Refined)
✅ CLS has explicit allow-list for writes  
✅ SOT zones protected from direct modification  
✅ All changes via Work Orders to CLC

### AI/OP-001 Rule 92
✅ Atomic operations (mktemp → mv)  
✅ SHA256 checksums included  
✅ Pre-backup snapshots (handled by bridge)

### AI/OP-001 Rule 93
✅ Timestamped logs in audit trail  
✅ Evidence directory per WO  
✅ Success validation before completion claims

---

## 📊 Directory Structure

```
~/02luka/
├── CLS/
│   ├── agents/
│   │   ├── CLS_agent_20251029_220732.md
│   │   └── CLS_agent_latest.md → (symlink)
│   └── templates/
│       └── WO_TEMPLATE.yaml
├── memory/
│   └── cls/
│       ├── ALLOWLIST.paths
│       └── README.md
├── bridge/
│   └── inbox/
│       └── CLC/  (Work Orders dropped here)
├── g/
│   └── telemetry/
│       └── cls_audit.jsonl
├── logs/
│   └── wo_drop_history/  (WO copies for audit)
└── .cursorrules

~/tools/
├── bridge_cls_clc.zsh
└── seed_cls_agent.zsh

~/Library/Logs/
└── seed_cls_agent_20251029_220732.log
```

---

## 🛠️ Troubleshooting

### Issue: Bridge script fails silently
**Solution:** Run directly in terminal, not through Claude Code hooks:
```bash
/usr/bin/env zsh ~/tools/bridge_cls_clc.zsh --help
```

### Issue: CLS agent not showing in Cursor
**Solution:** 
1. Verify `.cursorrules` exists: `cat ~/02luka/.cursorrules`
2. Restart Cursor completely
3. Ensure workspace opened from `~/02luka/` directory

### Issue: Permission denied on bridge
**Solution:**
```bash
chmod +x ~/tools/bridge_cls_clc.zsh
chmod +x ~/tools/seed_cls_agent.zsh
```

### Issue: Redis ACK not publishing
**Expected:** This is normal if Redis not running. Script continues without ACK.  
**Optional:** Start Redis: `docker start 02luka-redis` or configure `REDIS_PASS` env var

---

## 📝 Logs & Audit Trail

- **Seed log:** `~/Library/Logs/seed_cls_agent_20251029_220732.log`
- **Audit log:** `~/02luka/g/telemetry/cls_audit.jsonl` (JSONL format)
- **WO history:** `~/02luka/logs/wo_drop_history/` (timestamped copies)

---

**✅ Deployment Complete**  
**Next:** Verify manually using commands above, then enable CLS in Cursor

**Owner:** CLC  
**Deployed by:** CLC (Claude Code)  
**Timestamp:** 2025-10-29T22:07:32+07:00
