# Claude Code - Troubleshooting Guide

**สถานะ**: ✅ Production Ready  
**อัพเดทล่าสุด**: 2025-11-12

---

## 🎯 ภาพรวม

คู่มือนี้รวบรวมปัญหาที่พบบ่อย อาการ สาเหตุ และวิธีแก้ไข

---

## 🔍 Common Issues

### Issue 1: Command ไม่ทำงาน

**อาการ:**
- พิมพ์ `/feature-dev` แล้วไม่มีอะไรเกิดขึ้น
- Claude ไม่ตอบสนองต่อ slash commands

**สาเหตุที่พบบ่อย:**
1. Command file ไม่มีอยู่
2. Cursor Chat ไม่เปิดอยู่
3. Path ไม่ถูกต้อง

**วิธีแก้:**

```bash
# 1. ตรวจสอบว่า command file มีอยู่
ls -la ~/02luka/.claude/commands/feature-dev.md

# 2. ถ้าไม่มี ให้สร้าง directory
mkdir -p ~/02luka/.claude/commands

# 3. ตรวจสอบว่า Cursor เปิดอยู่และ Chat ทำงาน
# ลองพิมพ์ข้อความธรรมดาใน Chat ก่อน

# 4. Reload Cursor window
# Cmd+Shift+P → "Reload Window"
```

**คำสั่งตรวจสอบ:**
```bash
# ตรวจสอบ commands ทั้งหมด
ls -la ~/02luka/.claude/commands/

# ควรเห็น:
# - feature-dev.md
# - code-review.md
# - deploy.md
# - commit.md
# - health-check.md
```

---

### Issue 2: Hook Errors เมื่อ Commit

**อาการ:**
```
git commit -m "test"
❌ pre-commit hook failed
```

**สาเหตุที่พบบ่อย:**
1. Hook script มี syntax error
2. Dependencies ไม่ครบ (shellcheck, jq, etc.)
3. Hook script ไม่ executable
4. Path ไม่ถูกต้อง

**วิธีแก้:**

```bash
# 1. ดู error message
git commit -m "test" 2>&1 | tee /tmp/commit_error.log

# 2. ตรวจสอบ hook script
cat ~/02luka/tools/claude_hooks/pre_commit.zsh

# 3. ตรวจสอบ syntax
zsh -n ~/02luka/tools/claude_hooks/pre_commit.zsh

# 4. ตรวจสอบ dependencies
command -v shellcheck || echo "shellcheck missing"
command -v jq || echo "jq missing"

# 5. ตรวจสอบ permissions
ls -la ~/02luka/tools/claude_hooks/pre_commit.zsh
# ควรเห็น: -rwxr-xr-x (executable)

# 6. ถ้าไม่ executable ให้ chmod
chmod +x ~/02luka/tools/claude_hooks/pre_commit.zsh

# 7. ดู hook logs
tail -f ~/02luka/logs/pre_commit.err.log
```

**คำสั่งตรวจสอบ:**
```bash
# ตรวจสอบ hooks ทั้งหมด
ls -la ~/02luka/tools/claude_hooks/

# ตรวจสอบ dependencies
~/02luka/tools/claude_hooks/setup_dependencies.zsh

# ตรวจสอบ hook syntax
for hook in ~/02luka/tools/claude_hooks/*.zsh; do
  echo "Checking: $hook"
  zsh -n "$hook" || echo "❌ Syntax error in $hook"
done
```

---

### Issue 3: Code Review ไม่ทำงาน

**อาการ:**
```
/code-review
❌ Orchestrator failed
```

**สาเหตุที่พบบ่อย:**
1. Orchestrator script ไม่มีอยู่
2. Backend adapter ไม่มีอยู่
3. Dependencies ไม่ครบ (jq, etc.)
4. Path ไม่ถูกต้อง

**วิธีแก้:**

```bash
# 1. ตรวจสอบ orchestrator script
ls -la ~/02luka/tools/subagents/orchestrator.zsh

# 2. ตรวจสอบ backend adapters
ls -la ~/02luka/tools/subagents/adapters/

# ควรเห็น:
# - cls.zsh
# - claude.zsh

# 3. ตรวจสอบ dependencies
command -v jq || echo "jq missing - install: brew install jq"

# 4. ทดสอบ orchestrator โดยตรง
cd ~/02luka
tools/subagents/orchestrator.zsh review "echo test" 2

# 5. ดู logs
tail -f ~/02luka/logs/subagent_metrics.log
```

**คำสั่งตรวจสอบ:**
```bash
# ตรวจสอบ subagent infrastructure
ls -la ~/02luka/tools/subagents/
ls -la ~/02luka/tools/subagents/adapters/

# ตรวจสอบ orchestrator summary
cat ~/02luka/g/reports/system/subagent_orchestrator_summary.json | jq .

# ตรวจสอบ compare results
cat ~/02luka/g/reports/system/subagent_compare_summary.json | jq .
```

---

### Issue 4: Deployment Fails

**อาการ:**
```
/deploy
❌ Deployment failed
❌ Health check failed
```

**สาเหตุที่พบบ่อย:**
1. Health check script ไม่มีอยู่
2. Rollback script ไม่ถูก generate
3. Backup failed
4. Service restart failed

**วิธีแก้:**

```bash
# 1. ตรวจสอบ deployment logs
tail -f ~/02luka/logs/claude_deployments.log

# 2. ตรวจสอบ health check
~/02luka/tools/system_health_check.zsh

# 3. ตรวจสอบ rollback script
ls -la ~/02luka/tools/rollback_*.zsh

# 4. ตรวจสอบ backup
ls -la ~/02luka/backups/

# 5. ตรวจสอบ service status
launchctl list | grep com.02luka

# 6. Manual health check
/health-check
```

**คำสั่งตรวจสอบ:**
```bash
# ตรวจสอบ deployment infrastructure
ls -la ~/02luka/tools/claude_hooks/verify_deployment.zsh
ls -la ~/02luka/tools/claude_tools/generate_rollback.zsh

# ตรวจสอบ health scripts
ls -la ~/02luka/tools/*_health_check.zsh
ls -la ~/02luka/tools/memory_hub_health.zsh
```

---

### Issue 5: Health Check Fails

**อาการ:**
```
/health-check
❌ Health check failed
Exit code: 1
```

**สาเหตุที่พบบ่อย:**
1. Health script ไม่มีอยู่
2. Dependencies ไม่ครบ
3. Services ไม่ทำงาน (Redis, LaunchAgents, etc.)
4. JSON output invalid

**วิธีแก้:**

```bash
# 1. ตรวจสอบ health script
ls -la ~/02luka/tools/system_health_check.zsh
ls -la ~/02luka/tools/memory_hub_health.zsh

# 2. รัน health check โดยตรง
~/02luka/tools/system_health_check.zsh

# 3. ตรวจสอบ services
# Redis
redis-cli -a gggclukaic PING || echo "❌ Redis not connected"

# LaunchAgents
launchctl list | grep com.02luka || echo "❌ No LaunchAgents found"

# 4. ตรวจสอบ health dashboard
cat ~/02luka/g/reports/health_dashboard.json | jq .

# 5. ตรวจสอบ JSON validity
jq . ~/02luka/g/reports/health_dashboard.json || echo "❌ Invalid JSON"
```

**คำสั่งตรวจสอบ:**
```bash
# ตรวจสอบ health infrastructure
ls -la ~/02luka/tools/*health*.zsh
ls -la ~/02luka/g/reports/health_dashboard.json

# ตรวจสอบ services
redis-cli -a gggclukaic PING
launchctl list | grep com.02luka

# ตรวจสอบ health dashboard
node ~/02luka/run/health_dashboard.cjs
```

---

### Issue 6: MLS Capture ไม่ทำงาน

**อาการ:**
- MLS entries ไม่ถูกสร้างหลัง code review/deployment
- `g/knowledge/mls_lessons.jsonl` ไม่มี entry ใหม่

**สาเหตุที่พบบ่อย:**
1. `mls_capture.zsh` ไม่มีอยู่
2. `g/knowledge/` directory ไม่มีอยู่
3. Hook ไม่เรียก `mls_capture.zsh`
4. MLS capture fail แต่ hook continue (wrapped in `|| true`)

**วิธีแก้:**

```bash
# 1. ตรวจสอบ mls_capture.zsh
ls -la ~/02luka/tools/mls_capture.zsh
chmod +x ~/02luka/tools/mls_capture.zsh

# 2. ตรวจสอบ directory
ls -la ~/02luka/g/knowledge/
mkdir -p ~/02luka/g/knowledge

# 3. ทดสอบ mls_capture โดยตรง
~/02luka/tools/mls_capture.zsh solution "Test" "Test description" "Test context"

# 4. ตรวจสอบ entry
tail -1 ~/02luka/g/knowledge/mls_lessons.jsonl | jq .

# 5. ตรวจสอบ hooks
grep -n "mls_capture" ~/02luka/tools/subagents/compare_results.zsh
grep -n "mls_capture" ~/02luka/tools/claude_hooks/verify_deployment.zsh
```

**คำสั่งตรวจสอบ:**
```bash
# ตรวจสอบ MLS infrastructure
ls -la ~/02luka/tools/mls_capture.zsh
ls -la ~/02luka/g/knowledge/mls_lessons.jsonl

# ตรวจสอบ MLS index
cat ~/02luka/g/knowledge/mls_index.json | jq .

# ตรวจสอบ hooks integration
grep -r "mls_capture" ~/02luka/tools/subagents/
grep -r "mls_capture" ~/02luka/tools/claude_hooks/
```

---

### Issue 7: Dashboard ไม่แสดงข้อมูล

**อาการ:**
- เปิด `g/apps/dashboard/claude_code.html` แล้วแสดง "No data available"
- JSON file ไม่มีอยู่

**สาเหตุที่พบบ่อย:**
1. JSON file ไม่ถูก generate
2. `metrics_to_json.zsh` ไม่ทำงาน
3. JSON format ไม่ถูกต้อง
4. Dashboard JavaScript error

**วิธีแก้:**

```bash
# 1. ตรวจสอบ JSON file
ls -la ~/02luka/g/reports/claude_code_metrics_*.json

# 2. ตรวจสอบ metrics_to_json.zsh
ls -la ~/02luka/tools/claude_tools/metrics_to_json.zsh

# 3. Generate JSON manually
~/02luka/tools/claude_tools/metrics_to_json.zsh

# 4. ตรวจสอบ JSON validity
jq . ~/02luka/g/reports/claude_code_metrics_*.json || echo "❌ Invalid JSON"

# 5. ตรวจสอบ dashboard HTML
# เปิด browser console (F12) ดู error messages
```

**คำสั่งตรวจสอบ:**
```bash
# ตรวจสอบ dashboard infrastructure
ls -la ~/02luka/g/apps/dashboard/claude_code.html
ls -la ~/02luka/tools/claude_tools/metrics_to_json.zsh

# ตรวจสอบ JSON files
ls -la ~/02luka/g/reports/claude_code_metrics_*.json
ls -la ~/02luka/g/reports/claude_code_metrics_*.md

# ตรวจสอบ metrics logs
tail -f ~/02luka/logs/claude_hooks.log
tail -f ~/02luka/logs/subagent_metrics.log
```

---

### Issue 8: Smoke Tests Fail

**อาการ:**
```
tests/claude_code/e2e_smoke_commands.zsh
❌ Test failed
Exit code: 1
```

**สาเหตุที่พบบ่อย:**
1. Command files ไม่มีอยู่
2. Scripts ไม่ executable
3. Dependencies ไม่ครบ
4. Path ไม่ถูกต้อง

**วิธีแก้:**

```bash
# 1. ตรวจสอบ test script
ls -la ~/02luka/tests/claude_code/e2e_smoke_commands.zsh
chmod +x ~/02luka/tests/claude_code/e2e_smoke_commands.zsh

# 2. ตรวจสอบ check_runner library
ls -la ~/02luka/tools/lib/check_runner.zsh

# 3. รัน test โดยตรง
cd ~/02luka
tests/claude_code/e2e_smoke_commands.zsh

# 4. ดู test reports
ls -la ~/02luka/g/reports/system/system_checks_*.md
ls -la ~/02luka/g/reports/system/system_checks_*.json

# 5. ตรวจสอบ dependencies
command -v jq || echo "jq missing"
command -v shellcheck || echo "shellcheck missing"
```

**คำสั่งตรวจสอบ:**
```bash
# ตรวจสอบ test infrastructure
ls -la ~/02luka/tests/claude_code/
ls -la ~/02luka/tools/lib/check_runner.zsh

# ตรวจสอบ test reports
ls -la ~/02luka/g/reports/system/system_checks_*.{md,json}

# ตรวจสอบ dependencies
~/02luka/tools/claude_hooks/setup_dependencies.zsh
```

---

## 🔧 Hook Debugging Steps

### Step 1: ตรวจสอบ Hook ถูกเรียกหรือไม่

```bash
# ตรวจสอบ git hooks
ls -la ~/02luka/.git/hooks/

# ตรวจสอบว่า hook ถูกเรียก
git commit -m "test" --dry-run

# ดู hook logs
tail -f ~/02luka/logs/pre_commit.err.log
tail -f ~/02luka/logs/quality_gate.err.log
```

### Step 2: ตรวจสอบ Hook Syntax

```bash
# ตรวจสอบ syntax
for hook in ~/02luka/tools/claude_hooks/*.zsh; do
  echo "Checking: $hook"
  zsh -n "$hook" || echo "❌ Syntax error"
done
```

### Step 3: ตรวจสอบ Hook Execution

```bash
# รัน hook โดยตรง
~/02luka/tools/claude_hooks/pre_commit.zsh

# ตรวจสอบ exit code
echo $?

# ดู output
~/02luka/tools/claude_hooks/pre_commit.zsh 2>&1 | tee /tmp/hook_output.log
```

### Step 4: ตรวจสอบ Dependencies

```bash
# รัน dependency setup
~/02luka/tools/claude_hooks/setup_dependencies.zsh

# ตรวจสอบ tools
command -v shellcheck
command -v jq
command -v gh
command -v git
```

---

## 📝 Error Message Interpretation

### Error: "Command not found"

**ความหมาย:** Command หรือ script ไม่มีอยู่หรือไม่อยู่ใน PATH

**วิธีแก้:**
```bash
# ตรวจสอบ command
which <command>

# ตรวจสอบ PATH
echo $PATH

# ใช้ absolute path
~/02luka/tools/<script>.zsh
```

### Error: "Permission denied"

**ความหมาย:** Script ไม่ executable

**วิธีแก้:**
```bash
# เพิ่ม execute permission
chmod +x ~/02luka/tools/<script>.zsh

# ตรวจสอบ permissions
ls -la ~/02luka/tools/<script>.zsh
```

### Error: "No such file or directory"

**ความหมาย:** File หรือ directory ไม่มีอยู่

**วิธีแก้:**
```bash
# ตรวจสอบ file
ls -la <path>

# สร้าง directory ถ้าจำเป็น
mkdir -p <directory>
```

### Error: "Syntax error"

**ความหมาย:** Script มี syntax error

**วิธีแก้:**
```bash
# ตรวจสอบ syntax
zsh -n <script>.zsh

# ดู error details
zsh -n <script>.zsh 2>&1
```

### Error: "Exit code 1"

**ความหมาย:** Command หรือ script failed

**วิธีแก้:**
```bash
# ดู error output
<command> 2>&1 | tee /tmp/error.log

# ตรวจสอบ logs
tail -f ~/02luka/logs/*.err.log
```

---

## 🆘 Quick Reference Commands

### ตรวจสอบ System Health

```bash
# Health check
/health-check

# หรือ
~/02luka/tools/system_health_check.zsh
~/02luka/tools/memory_hub_health.zsh
```

### ตรวจสอบ Commands

```bash
# ตรวจสอบ commands ทั้งหมด
ls -la ~/02luka/.claude/commands/

# ตรวจสอบ command content
cat ~/02luka/.claude/commands/feature-dev.md
```

### ตรวจสอบ Hooks

```bash
# ตรวจสอบ hooks ทั้งหมด
ls -la ~/02luka/tools/claude_hooks/

# ตรวจสอบ hook syntax
for hook in ~/02luka/tools/claude_hooks/*.zsh; do
  zsh -n "$hook" && echo "✅ $hook" || echo "❌ $hook"
done
```

### ตรวจสอบ Logs

```bash
# ดู logs ทั้งหมด
ls -la ~/02luka/logs/

# ดู hook logs
tail -f ~/02luka/logs/pre_commit.err.log
tail -f ~/02luka/logs/quality_gate.err.log

# ดู subagent logs
tail -f ~/02luka/logs/subagent_metrics.log
```

### ตรวจสอบ Dependencies

```bash
# Setup dependencies
~/02luka/tools/claude_hooks/setup_dependencies.zsh

# ตรวจสอบ tools
command -v shellcheck && echo "✅ shellcheck" || echo "❌ shellcheck"
command -v jq && echo "✅ jq" || echo "❌ jq"
command -v gh && echo "✅ gh" || echo "❌ gh"
```

---

## 📖 เอกสารเพิ่มเติม

- **Onboarding Guide**: `docs/claude_code/ONBOARDING.md`
- **Best Practices**: `docs/claude_code/BEST_PRACTICES.md`
- **Slash Commands**: `docs/claude_code/SLASH_COMMANDS_GUIDE.md`

---

## 🆘 ยังแก้ไม่ได้?

ถ้ายังแก้ปัญหาไม่ได้:

1. **ตรวจสอบ logs:**
   ```bash
   tail -f ~/02luka/logs/*.err.log
   ```

2. **รัน health check:**
   ```bash
   /health-check
   ```

3. **ตรวจสอบ system health:**
   ```bash
   cat ~/02luka/g/reports/health_dashboard.json | jq .
   ```

4. **Capture MLS lesson:**
   ```bash
   ~/02luka/tools/mls_capture.zsh failure "Issue: <description>" "What happened" "Context"
   ```

---

**สถานะ**: ✅ Ready to Use  
**Version**: 1.0  
**Last Updated**: 2025-11-12

*คู่มือนี้จะถูกอัพเดทเมื่อมี issues ใหม่หรือ solutions เพิ่มเติม*
