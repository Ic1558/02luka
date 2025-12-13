# Catalog Gate System — Automation Guide

**Date:** 2025-12-10  
**Feature Slug:** `catalog_gate_system`  
**Status:** ✅ **AUTOMATION READY**

---

## 🤖 Question 1: Do I Have to Run Validation Manually Every Time?

### Answer: No — Multiple Automation Options

### Option 1: Auto Workflow Executor (Recommended)
```bash
# Run full workflow automatically (includes validation at end)
zsh tools/run_tool.zsh auto-workflow <feature-slug>
```

**This automatically:**
- Runs all workflow stages
- **Includes mandatory validation (Gate 4) at end**
- Blocks completion if validation fails
- No manual step needed

### Option 2: Git Hook Integration
Add to `.git/hooks/pre-commit`:
```bash
#!/bin/zsh
# Auto-validate before commit
if [[ -n "$(git diff --cached --name-only | grep -E '^(tools/|agents/|bridge/)')" ]]; then
    zsh tools/run_tool.zsh feature-dev-validate catalog_gate_system || exit 1
fi
```

### Option 3: CI/CD Integration
Add to GitHub Actions:
```yaml
- name: Validate Feature
  run: zsh tools/run_tool.zsh feature-dev-validate ${{ github.event.inputs.feature_slug }}
```

### Option 4: Manual (Current)
```bash
# Only if not using auto workflow
zsh tools/run_tool.zsh feature-dev-validate <feature-slug>
```

---

## 📚 Question 2: How Does Catalog Self-Update? Daily or Every 8 Hours?

### Answer: Manual (Curated) — Not Auto-Updated

**Catalog is NOT auto-updated** because:
- ✅ **Quality over quantity** — Only "official" tools in catalog
- ✅ **Prevents junk** — Experimental tools excluded
- ✅ **Maintains integrity** — Single source of truth stays clean

### How Catalog Updates Work

**Current Process: Manual (On-Demand)**
1. New tool created
2. Tool becomes "official" (production-ready)
3. **Manually add to `tools/catalog.yaml`**
4. Update `updated:` date field

**Scan Tool (Optional):**
```bash
# Scan for tools not in catalog (suggestions only)
zsh tools/run_tool.zsh catalog-auto-update --scan
```

**Output:**
```
🔍 Scanning tools/ directory...

Found tools:
  ⚠️  Not in catalog: my_new_tool (my_new_tool.zsh)
  ✅ In catalog: code-review
  ✅ In catalog: save-now
```

### Scheduled Scan (Optional — Not Auto-Update)

If you want daily **suggestions** (not auto-update):

**Create LaunchAgent:**
```xml
<!-- ~/Library/LaunchAgents/com.02luka.catalog.scan.plist -->
<key>StartCalendarInterval</key>
<dict>
    <key>Hour</key>
    <integer>8</integer>  <!-- 8:00 AM daily -->
    <key>Minute</key>
    <integer>0</integer>
</dict>
<key>ProgramArguments</key>
<array>
    <string>/bin/zsh</string>
    <string>/Users/icmini/02luka/tools/catalog_auto_update.zsh</string>
    <string>--scan</string>
</array>
```

**Frequency Recommendation:**
- ✅ **Daily scan:** 8:00 AM (suggestions only, logged to file)
- ❌ **NOT every 8 hours** — Too frequent, catalog is stable
- ✅ **Manual update:** When tool becomes production-ready

---

## 🔄 Recommended Workflow

### For Feature Development:
```bash
# Use auto workflow (includes validation automatically)
zsh tools/run_tool.zsh auto-workflow <feature-slug>

# Validation runs automatically at end
# No manual step needed
```

### For Catalog Updates:
```bash
# 1. Scan for suggestions (optional, daily)
zsh tools/run_tool.zsh catalog-auto-update --scan

# 2. Review suggestions
# 3. Manually add to catalog.yaml when tool is production-ready
# 4. Update 'updated:' date field
```

---

## 📊 Summary

| Task | Frequency | Method |
|------|-----------|--------|
| **Feature Validation** | Every feature | Auto (via auto_workflow_executor) |
| **Catalog Scan** | Daily (optional) | LaunchAgent (suggestions only) |
| **Catalog Update** | On-demand | Manual (when tool is production-ready) |

---

**Status:** ✅ **AUTOMATION READY**  
**Validation:** Auto via workflow executor  
**Catalog:** Manual (curated, not auto-updated)

