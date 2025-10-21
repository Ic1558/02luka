#!/usr/bin/env bash
set -euo pipefail

# CLS Runbook Generator
# Creates comprehensive operations handover documentation

echo "🧠 CLS Runbook Generator"
echo "======================="

# Function to generate runbook
generate_runbook() {
    echo "1) Generating CLS Runbook..."
    
    RUNBOOK_FILE="g/reports/CLS_RUNBOOK_$(date +%Y%m%d).md"
    mkdir -p "$(dirname "$RUNBOOK_FILE")"
    
    cat > "$RUNBOOK_FILE" << 'EOF'
# CLS Workflow Automation Runbook

**Generated:** 2025-10-21  
**Version:** 1.0  
**Status:** Production Ready  

---

## 🎯 **System Overview**

CLS (Cognitive Local System) provides comprehensive workflow automation with conflict detection, resolution assistance, and staging integration. The system operates autonomously with daily verification and workflow scanning.

## 🚀 **Core Components**

### **1. LaunchAgent Automation**
- **Service:** `com.02luka.cls.verification` (09:00 daily)
- **Service:** `com.02luka.cls.workflow` (10:00 daily)
- **Purpose:** Automated CLS capability testing and conflict scanning
- **Logs:** `/Volumes/lukadata/CLS/logs/`

### **2. Git Hooks Integration**
- **Hook:** `.git/hooks/pre-commit`
- **Purpose:** Auto-resolve conflicts before commits
- **Behavior:** Blocks dirty merges, attempts auto-resolve

### **3. Staging Integration**
- **Script:** `scripts/staging_integration.sh`
- **Purpose:** Auto-push successful patches to staging branch
- **Safety:** Only pushes after clean working tree

## 📋 **Daily Operations**

### **Morning Routine (09:00)**
```bash
# Check LaunchAgent status
launchctl print gui/$UID/com.02luka.cls.verification | grep LastExitStatus

# Check logs
tail -n 20 /Volumes/lukadata/CLS/logs/cls_verification.log

# Verify reports
ls -la /Volumes/lukadata/CLS/reports/ | tail -n 5
```

### **Workflow Scan (10:00)**
```bash
# Check workflow LaunchAgent
launchctl print gui/$UID/com.02luka.cls.workflow | grep LastExitStatus

# Check workflow logs
tail -n 20 /Volumes/lukadata/CLS/logs/cls_workflow.log

# Review telemetry
tail -n 10 g/telemetry/codex_workflow.log
```

## 🔧 **Troubleshooting**

### **LaunchAgent Issues**
```bash
# Check status
launchctl list | grep com.02luka.cls

# Restart service
launchctl kickstart -k gui/$UID/com.02luka.cls.verification
launchctl kickstart -k gui/$UID/com.02luka.cls.workflow

# Check logs
tail -f /Volumes/lukadata/CLS/logs/cls_verification.log
tail -f /Volumes/lukadata/CLS/logs/cls_workflow.log
```

### **Git Hook Issues**
```bash
# Check hook status
test -x .git/hooks/pre-commit && echo "Active" || echo "Disabled"

# Re-enable hook
chmod +x .git/hooks/pre-commit

# Test hook
git add . && git commit -m "test"
```

### **Staging Issues**
```bash
# Check staging branch
git ls-remote --heads origin staging

# Manual staging push
bash scripts/staging_integration.sh

# Check staging telemetry
tail -n 5 g/telemetry/staging_integration.log
```

## 📊 **Monitoring & Metrics**

### **Key Performance Indicators**
- **Conflict Rate:** # conflicts / # patches
- **Auto-resolve Success:** % resolved automatically
- **Staging Push Success:** % successful pushes
- **LaunchAgent Health:** ExitStatus = 0

### **Telemetry Analysis**
```bash
# Conflict rate analysis
grep -E '"conflicts_total"|"conflicts_auto_resolved"' g/telemetry/codex_workflow.log | tail -n 50

# Auto-resolve success rate
node -e '
const fs=require("fs");
const L=fs.readFileSync("g/telemetry/codex_workflow.log","utf8").trim().split("\n").map(JSON.parse);
const last=L.slice(-50);
const auto=last.reduce((a,e)=>a+(e.conflicts_auto_resolved||0),0);
const tot=last.reduce((a,e)=>a+(e.conflicts_total||0),0);
console.log("Auto-resolve success:", tot?Math.round(100*auto/tot):"n/a","%");
'

# Token savings analysis
grep -E '"tokens_cls"|"tokens_clc"' g/telemetry/codex_workflow.log | tail -n 50
```

## 🚨 **Emergency Procedures**

### **Complete Rollback (30 seconds)**
```bash
# Disable LaunchAgent
launchctl bootout gui/$UID ~/Library/LaunchAgents/com.02luka.cls.workflow.plist

# Disable pre-commit hook
chmod -x .git/hooks/pre-commit

# Disable auto-staging
chmod -x scripts/staging_integration.sh
```

### **Partial Rollback**
```bash
# Disable specific components
launchctl bootout gui/$UID ~/Library/LaunchAgents/com.02luka.cls.verification.plist  # Verification only
chmod -x .git/hooks/pre-commit  # Git hooks only
chmod -x scripts/staging_integration.sh  # Staging only
```

## 🔄 **Recovery Procedures**

### **Re-enable System**
```bash
# Re-enable LaunchAgent
launchctl bootstrap gui/$UID ~/Library/LaunchAgents/com.02luka.cls.verification.plist
launchctl bootstrap gui/$UID ~/Library/LaunchAgents/com.02luka.cls.workflow.plist

# Re-enable pre-commit hook
chmod +x .git/hooks/pre-commit

# Re-enable staging integration
chmod +x scripts/staging_integration.sh
```

### **Complete Reinstall**
```bash
# Run complete installation
bash scripts/install_all_workflow_automation.sh

# Validate installation
bash scripts/cls_go_live_validation.sh
```

## 📈 **Performance Optimization**

### **Conflict Resolution Tuning**
- Monitor auto-resolve success rates
- Adjust resolution rules in `scripts/auto_resolve_conflicts.sh`
- Update dependency ordering in `scripts/codex_batch_apply.sh`

### **Staging Optimization**
- Monitor staging push success rates
- Adjust staging integration in `scripts/staging_integration.sh`
- Optimize branch management

### **Telemetry Analysis**
- Review daily conflict patterns
- Identify high-conflict file types
- Optimize workflow assistant rules

## 🎯 **Success Criteria**

### **Daily Health Checks**
- ✅ LaunchAgent ExitStatus = 0
- ✅ Conflict auto-resolve rate ≥ 60%
- ✅ Staging push success ≥ 95%
- ✅ Manual "click-apply" volume measurably reduced

### **Weekly Reviews**
- ✅ Telemetry trend analysis
- ✅ Performance optimization
- ✅ Rule refinement
- ✅ System health assessment

## 📞 **Support & Escalation**

### **Self-Service Tools**
- **Validation:** `bash scripts/cls_go_live_validation.sh`
- **Rollback:** `bash scripts/cls_rollback.sh`
- **Telemetry:** `bash scripts/cls_telemetry_dashboard.sh`
- **Discord Report:** `bash scripts/cls_discord_report.sh`

### **Manual Override**
- **Workflow Assistant:** `bash scripts/codex_workflow_assistant.sh --scan`
- **Auto-resolve:** `bash scripts/auto_resolve_conflicts.sh`
- **Batch Apply:** `bash scripts/codex_batch_apply_with_staging.sh`

---

**CLS Workflow Automation Runbook - Production Ready** 🧠⚡
EOF
    
    echo "   ✅ Runbook generated: $RUNBOOK_FILE"
}

# Function to create quick reference
create_quick_reference() {
    echo ""
    echo "2) Creating quick reference..."
    
    QUICK_REF_FILE="g/reports/CLS_QUICK_REFERENCE.md"
    
    cat > "$QUICK_REF_FILE" << 'EOF'
# CLS Quick Reference

## 🚀 **Daily Commands**

```bash
# Check system status
launchctl list | grep com.02luka.cls
tail -n 5 /Volumes/lukadata/CLS/logs/cls_verification.log

# Run validation
bash scripts/cls_go_live_validation.sh

# Check telemetry
bash scripts/cls_telemetry_dashboard.sh
```

## 🔧 **Troubleshooting**

```bash
# Restart LaunchAgent
launchctl kickstart -k gui/$UID/com.02luka.cls.verification
launchctl kickstart -k gui/$UID/com.02luka.cls.workflow

# Re-enable hooks
chmod +x .git/hooks/pre-commit

# Manual staging
bash scripts/staging_integration.sh
```

## 🚨 **Emergency Rollback**

```bash
# Complete rollback
bash scripts/cls_rollback.sh

# Or manual
launchctl bootout gui/$UID ~/Library/LaunchAgents/com.02luka.cls.workflow.plist
chmod -x .git/hooks/pre-commit
```

## 📊 **Monitoring**

```bash
# Conflict rate
grep -E '"conflicts_total"' g/telemetry/codex_workflow.log | tail -n 50

# Auto-resolve success
node -e 'const fs=require("fs");const L=fs.readFileSync("g/telemetry/codex_workflow.log","utf8").trim().split("\n").map(JSON.parse);const last=L.slice(-50);const auto=last.reduce((a,e)=>a+(e.conflicts_auto_resolved||0),0);const tot=last.reduce((a,e)=>a+(e.conflicts_total||0),0);console.log("Auto-resolve success:", tot?Math.round(100*auto/tot):"n/a","%");'

# Staging status
git ls-remote --heads origin staging
```

**CLS Quick Reference - Keep Handy** 🧠⚡
EOF
    
    echo "   ✅ Quick reference created: $QUICK_REF_FILE"
}

# Main execution
echo "Starting CLS Runbook generation..."

generate_runbook
create_quick_reference

echo ""
echo "🎯 CLS Runbook Generation Complete"
echo "   Comprehensive runbook and quick reference created"
echo "   Files: g/reports/CLS_RUNBOOK_*.md and CLS_QUICK_REFERENCE.md"
