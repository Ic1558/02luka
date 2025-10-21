#!/usr/bin/env bash
set -euo pipefail

# CLS Ops Runbook PDF Generator
# Creates a one-page PDF runbook for team handover

echo "🧠 CLS Ops Runbook PDF Generator"
echo "==============================="

# Function to generate runbook content
generate_runbook_content() {
    echo "1) Generating runbook content..."
    
    RUNBOOK_FILE="g/reports/CLS_OPS_RUNBOOK_$(date +%Y%m%d).md"
    mkdir -p "$(dirname "$RUNBOOK_FILE")"
    
    cat > "$RUNBOOK_FILE" << 'EOF'
# CLS Operations Runbook

**System:** CLS Workflow Automation  
**Version:** 1.0  
**Status:** Production Ready  
**Generated:** 2025-10-21  

---

## 🚀 **Quick Start**

### **Daily Operations**
```bash
# Check system health
launchctl list | grep com.02luka.cls
tail -n 5 /Volumes/lukadata/CLS/logs/cls_workflow.log

# Run validation
bash scripts/cls_go_live_validation.sh

# Check telemetry
bash scripts/cls_telemetry_dashboard.sh
```

### **Emergency Procedures**
```bash
# Complete rollback (30 seconds)
bash scripts/cls_rollback.sh

# Manual rollback
launchctl bootout gui/$UID ~/Library/LaunchAgents/com.02luka.cls.workflow.plist
chmod -x .git/hooks/pre-commit
```

---

## 📊 **System Components**

| Component | Purpose | Status Check |
|-----------|---------|--------------|
| **LaunchAgent** | Daily automation (09:00, 10:00) | `launchctl print gui/$UID/com.02luka.cls.workflow` |
| **Git Hooks** | Pre-commit auto-resolve | `test -x .git/hooks/pre-commit` |
| **Staging** | Auto-push successful patches | `git ls-remote --heads origin staging` |
| **Telemetry** | Performance tracking | `tail -f g/telemetry/codex_workflow.log` |

---

## 🔧 **Troubleshooting**

### **LaunchAgent Issues**
```bash
# Restart service
launchctl kickstart -k gui/$UID/com.02luka.cls.workflow

# Check logs
tail -f /Volumes/lukadata/CLS/logs/cls_workflow.log
```

### **Git Hook Issues**
```bash
# Re-enable hook
chmod +x .git/hooks/pre-commit

# Test hook
git add . && git commit -m "test"
```

### **Staging Issues**
```bash
# Manual staging push
bash scripts/staging_integration.sh

# Check staging status
git ls-remote --heads origin staging
```

---

## 📈 **Success Criteria**

### **Daily Health Checks**
- ✅ LaunchAgent ExitStatus = 0
- ✅ Conflict auto-resolve rate ≥ 60%
- ✅ Staging push success ≥ 95%
- ✅ Manual "click-apply" volume reduced

### **Performance Monitoring**
```bash
# Conflict rate analysis
grep -E '"conflicts_total"|"conflicts_auto_resolved"' g/telemetry/codex_workflow.log | tail -n 50

# Auto-resolve success rate
node -e 'const fs=require("fs");const L=fs.readFileSync("g/telemetry/codex_workflow.log","utf8").trim().split("\n").map(JSON.parse);const last=L.slice(-50);const auto=last.reduce((a,e)=>a+(e.conflicts_auto_resolved||0),0);const tot=last.reduce((a,e)=>a+(e.conflicts_total||0),0);console.log("Auto-resolve success:", tot?Math.round(100*auto/tot):"n/a","%");'
```

---

## 🚨 **Emergency Contacts**

### **Self-Service Tools**
- **Validation:** `bash scripts/cls_go_live_validation.sh`
- **Rollback:** `bash scripts/cls_rollback.sh`
- **Monitoring:** `bash scripts/cls_telemetry_dashboard.sh`
- **Discord Report:** `bash scripts/cls_discord_report.sh`

### **Manual Override**
- **Workflow Scan:** `bash scripts/codex_workflow_assistant.sh --scan`
- **Auto-resolve:** `bash scripts/auto_resolve_conflicts.sh`
- **Batch Apply:** `bash scripts/codex_batch_apply_with_staging.sh`

---

## 📋 **Daily Checklist**

### **Morning (09:00)**
- [ ] Check LaunchAgent status
- [ ] Review verification logs
- [ ] Check reports directory

### **Workflow Scan (10:00)**
- [ ] Check workflow LaunchAgent
- [ ] Review conflict telemetry
- [ ] Verify staging activity

### **End of Day**
- [ ] Review daily metrics
- [ ] Check for any issues
- [ ] Plan next day optimizations

---

**CLS Operations Runbook - Production Ready** 🧠⚡

*For detailed documentation, see: g/reports/CLS_RUNBOOK_*.md*
EOF
    
    echo "   ✅ Runbook content generated: $RUNBOOK_FILE"
}

# Function to convert to PDF (if pandoc available)
convert_to_pdf() {
    echo ""
    echo "2) Converting to PDF..."
    
    if command -v pandoc >/dev/null 2>&1; then
        PDF_FILE="g/reports/CLS_OPS_RUNBOOK_$(date +%Y%m%d).pdf"
        
        if pandoc "g/reports/CLS_OPS_RUNBOOK_$(date +%Y%m%d).md" -o "$PDF_FILE" --pdf-engine=wkhtmltopdf 2>/dev/null; then
            echo "   ✅ PDF generated: $PDF_FILE"
        else
            echo "   ⚠️  PDF conversion failed (pandoc/wkhtmltopdf not available)"
            echo "   Markdown file available: g/reports/CLS_OPS_RUNBOOK_$(date +%Y%m%d).md"
        fi
    else
        echo "   ⚠️  pandoc not available - PDF conversion skipped"
        echo "   Markdown file available: g/reports/CLS_OPS_RUNBOOK_$(date +%Y%m%d).md"
    fi
}

# Function to create HTML version
create_html_version() {
    echo ""
    echo "3) Creating HTML version..."
    
    HTML_FILE="g/reports/CLS_OPS_RUNBOOK_$(date +%Y%m%d).html"
    
    if command -v pandoc >/dev/null 2>&1; then
        if pandoc "g/reports/CLS_OPS_RUNBOOK_$(date +%Y%m%d).md" -o "$HTML_FILE" --standalone --css=<(echo "body{font-family:Arial,sans-serif;max-width:800px;margin:0 auto;padding:20px;}h1,h2,h3{color:#333;}code{background:#f4f4f4;padding:2px 4px;border-radius:3px;}pre{background:#f4f4f4;padding:10px;border-radius:5px;overflow-x:auto;}table{border-collapse:collapse;width:100%;}th,td{border:1px solid #ddd;padding:8px;text-align:left;}th{background:#f2f2f2;}") 2>/dev/null; then
            echo "   ✅ HTML generated: $HTML_FILE"
        else
            echo "   ⚠️  HTML conversion failed"
        fi
    else
        echo "   ⚠️  pandoc not available - HTML conversion skipped"
    fi
}

# Function to create summary
create_summary() {
    echo ""
    echo "4) Creating summary..."
    
    SUMMARY_FILE="g/reports/CLS_OPS_SUMMARY_$(date +%Y%m%d).txt"
    
    cat > "$SUMMARY_FILE" << EOF
CLS Operations Runbook Summary
==============================

Generated: $(date -Iseconds)
Files Created:
- g/reports/CLS_OPS_RUNBOOK_$(date +%Y%m%d).md (Markdown)
- g/reports/CLS_OPS_RUNBOOK_$(date +%Y%m%d).html (HTML, if pandoc available)
- g/reports/CLS_OPS_RUNBOOK_$(date +%Y%m%d).pdf (PDF, if pandoc/wkhtmltopdf available)

Quick Commands:
- Check health: launchctl list | grep com.02luka.cls
- Run validation: bash scripts/cls_go_live_validation.sh
- Emergency rollback: bash scripts/cls_rollback.sh

For team handover, share the PDF or HTML version.
EOF
    
    echo "   ✅ Summary created: $SUMMARY_FILE"
}

# Main execution
echo "Starting CLS Ops Runbook PDF generation..."

generate_runbook_content
convert_to_pdf
create_html_version
create_summary

echo ""
echo "🎯 CLS Ops Runbook PDF Generation Complete"
echo "   One-page runbook created for team handover"
echo "   Files: g/reports/CLS_OPS_RUNBOOK_*.md/html/pdf"
echo "   Summary: g/reports/CLS_OPS_SUMMARY_*.txt"
