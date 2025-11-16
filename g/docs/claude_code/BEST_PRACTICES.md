# Claude Code - Best Practices

**สถานะ**: ✅ Production Ready  
**อัพเดทล่าสุด**: 2025-11-12

---

## 🎯 ภาพรวม

เอกสารนี้รวบรวม best practices และ patterns ที่ดีจากการใช้งานจริงในระบบ Claude Code

---

## ✅ DO - สิ่งที่ควรทำ

### 1. ใช้ Plan-First Approach

**✅ DO:**
```
/feature-dev
เพิ่ม feature ใหม่
```

**ทำไม:** Claude จะถามคำถามชี้แจงก่อน สร้าง SPEC/PLAN ที่ชัดเจน ทำให้ implementation มีคุณภาพสูงขึ้น

**Pattern:**
- ใช้ `/feature-dev` สำหรับ feature ใหม่ที่ซับซ้อน
- Review SPEC/PLAN ก่อนเริ่ม implementation
- Follow TODO list ทีละข้อ

### 2. Code Review ก่อน Merge

**✅ DO:**
```
/code-review
Review PR #123 ก่อน merge
```

**ทำไม:** Multi-agent review ช่วยจับ bugs, security issues, และ performance problems

**Pattern:**
- ใช้ `/code-review` สำหรับ PR ที่ซับซ้อน
- Fix "Must Fix" issues ก่อน approve
- เก็บ review results เพื่อเรียนรู้ patterns

### 3. Deploy แบบ Checklist-Driven

**✅ DO:**
```
/deploy
Deploy feature X to production
```

**ทำไม:** Checklist-driven deployment มี backup, rollback plan, และ health check อัตโนมัติ

**Pattern:**
- ใช้ `/deploy` ทุกครั้งที่ deploy production
- Review checklist ทั้งหมดก่อน confirm
- เก็บ rollback script ไว้เผื่อต้องใช้

### 4. ใช้ Conventional Commits

**✅ DO:**
```
/commit "feat(api): add MLS export endpoint"
```

**ทำไม:** Conventional Commits ทำให้ commit history อ่านง่าย และสามารถ generate changelog อัตโนมัติ

**Pattern:**
- Format: `type(scope): subject`
- Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`
- Scope: optional, lowercase
- Subject: imperative mood, no period

### 5. ตรวจสอบสุขภาพระบบหลัง Deploy

**✅ DO:**
```
/deploy
... (deployment complete)

/health-check
```

**ทำไม:** Health check ช่วยยืนยันว่า deployment สำเร็จและระบบทำงานปกติ

**Pattern:**
- Run `/health-check` หลัง deploy
- Monitor logs ใน 30 นาทีแรก
- เก็บ health check results เป็น evidence

### 6. ใช้ Error Handling Pattern

**✅ DO:**
```zsh
#!/usr/bin/env zsh
set -euo pipefail

BASE="${LUKA_SOT:-$HOME/02luka}"

# Safe execution
{
  set +e
  "$@" >"$output" 2>"$error"
  rc=$?
  set -e
} || true

# Check exit code
if [[ $rc -eq 0 ]]; then
  echo "✅ Success"
else
  echo "❌ Failed (rc=$rc)"
fi
```

**ทำไม:** Pattern นี้ป้องกัน early exit จาก `set -e` และยัง capture exit code ได้

**Pattern:**
- ใช้ `set +e` / `set -e` blocks สำหรับ commands ที่อาจ fail
- Capture exit code แทนการ rely on `set -e` เท่านั้น
- ใช้ `check_runner.zsh` สำหรับ multiple checks

### 7. Backup ก่อนแก้ไข Hooks

**✅ DO:**
```zsh
# Backup before modification
BACKUP_DIR="backups/hooks_$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"
cp tools/claude_hooks/pre_commit.zsh "$BACKUP_DIR/"
```

**ทำไม:** Backup ช่วยให้ rollback ได้ง่ายถ้ามีปัญหา

**Pattern:**
- Backup hooks ก่อนแก้ไข
- เก็บ backup ใน `backups/hooks_YYYYMMDD/`
- Test hooks หลังแก้ไข

### 8. ใช้ MLS Capture สำหรับ Lessons Learned

**✅ DO:**
```zsh
# After successful code review
"$BASE/tools/mls_capture.zsh" solution \
  "Code Review: Feature X" \
  "Multi-agent review found 3 critical issues" \
  "Backend=cls, agents=2, review strategy"
```

**ทำไม:** MLS capture ช่วยบันทึก lessons learned เพื่อใช้ในอนาคต

**Pattern:**
- Capture หลัง code review (type: `solution`)
- Capture หลัง deployment (type: `improvement`)
- Capture patterns ที่ดี (type: `pattern`)

---

## ❌ DON'T - สิ่งที่ไม่ควรทำ

### 1. อย่าใช้ `/feature-dev` แล้วบังคับให้เขียนโค้ดทันที

**❌ DON'T:**
```
User: /feature-dev ทำ feature X
Claude: [ถามคำถาม]
User: เริ่มเขียนโค้ดเลย!  ❌
```

**✅ DO:**
```
User: /feature-dev ทำ feature X
Claude: [ถามคำถาม]
User: [ตอบคำถาม]
Claude: [สร้าง PLAN.md]
User: แผนนี้โอเค เริ่มได้  ✅
```

**ทำไม:** Plan-first approach ช่วยให้ได้ SPEC/PLAN ที่ดีก่อน implementation

### 2. อย่าใช้ `/code-review` กับการเปลี่ยนแปลงเล็กๆ

**❌ DON'T:**
```
/code-review
แก้ typo ในคอมเมนต์  ❌
```

**✅ DO:**
```
/code-review
Review PR #123 ที่ refactor authentication  ✅
```

**ทำไม:** Subagents ใช้เวลาและ resources มาก ไม่จำเป็นสำหรับการเปลี่ยนแปลงเล็กๆ

### 3. อย่า Deploy Production โดยไม่ใช้ `/deploy`

**❌ DON'T:**
```
Copy ไฟล์ใหม่ไป production แล้ว restart service  ❌
(ไม่มี backup, ไม่มี rollback plan)
```

**✅ DO:**
```
/deploy
Deploy updated authentication module to production  ✅
```

**ทำไม:** `/deploy` มี backup, rollback plan, และ health check อัตโนมัติ

### 4. อย่า Hard-code Credentials

**❌ DON'T:**
```zsh
REDIS_PASS="gggclukaic"  # ❌ Hard-coded
```

**✅ DO:**
```zsh
REDIS_PASS="${REDIS_PASSWORD:-gggclukaic}"  # ✅ Environment variable
```

**ทำไม:** Hard-coded credentials เป็น security risk

**Pattern:**
- ใช้ environment variables
- ใช้ `:-` fallback สำหรับ default values
- ตรวจสอบด้วย `security_check.zsh` hook

### 5. อย่า Skip Error Handling

**❌ DON'T:**
```zsh
#!/usr/bin/env zsh
set -euo pipefail

# No error handling
"$SCRIPT"  # ❌ May exit early
```

**✅ DO:**
```zsh
#!/usr/bin/env zsh
set -euo pipefail

# Safe execution
{
  set +e
  "$SCRIPT" >"$output" 2>"$error"
  rc=$?
  set -e
} || true

# Check result
if [[ $rc -ne 0 ]]; then
  echo "❌ Script failed"
  exit 1
fi
```

**ทำไม:** Error handling ช่วยให้ script ทำงานครบถ้วนและ generate reports ได้เสมอ

### 6. อย่า Modify Hooks โดยไม่ Backup

**❌ DON'T:**
```zsh
# Direct modification without backup
vim tools/claude_hooks/pre_commit.zsh  # ❌
```

**✅ DO:**
```zsh
# Backup first
BACKUP_DIR="backups/hooks_$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"
cp tools/claude_hooks/pre_commit.zsh "$BACKUP_DIR/"

# Then modify
vim tools/claude_hooks/pre_commit.zsh  # ✅
```

**ทำไม:** Backup ช่วยให้ rollback ได้ง่ายถ้ามีปัญหา

### 7. อย่าใช้ Relative Paths ข้าม Major Directories

**❌ DON'T:**
```zsh
# Relative path (may break)
cd ../g/reports  # ❌
```

**✅ DO:**
```zsh
# Absolute path with BASE variable
BASE="${LUKA_SOT:-$HOME/02luka}"
cd "$BASE/g/reports"  # ✅
```

**ทำไม:** Absolute paths ช่วยให้ script ทำงานได้จาก directory ไหนก็ได้

---

## 🔄 Common Workflows

### Workflow 1: พัฒนา Feature ใหม่

```
1. /feature-dev
   → Claude ถามคำถาม
   → ตอบคำถามให้ละเอียด
   → ได้ SPEC.md + PLAN.md

2. Review SPEC/PLAN
   → ตรวจสอบว่า requirements ครบถ้วน
   → ตรวจสอบว่า timeline สมเหตุสมผล

3. Follow TODO list ทีละข้อ
   → พิมพ์ธรรมดา: "ทำข้อ 1: สร้าง API route"
   → Claude เขียนโค้ด
   → Test
   → Next TODO

4. /code-review (เมื่อทำเสร็จทั้งหมด)
   → Claude review โค้ดที่เขียน
   → แก้ issues ที่พบ

5. /deploy (เมื่อ ready สำหรับ production)
   → Deploy แบบปลอดภัย
   → Health check
   → Monitor
```

### Workflow 2: แก้ Bug + Deploy

```
1. พิมพ์ธรรมดา: "แก้ bug: API timeout after 10 requests"
   → Claude investigate
   → Fix code

2. /code-review
   → Review fix ว่าแก้ถูกต้อง
   → ไม่ทำให้เกิด regression

3. /deploy
   → Deploy fix to production
   → Verify bug หายแล้ว
```

### Workflow 3: Review Code Only

```
1. /code-review
   → Review PR ก่อน merge

2. แก้ issues ที่พบ (พิมพ์ธรรมดา)
   → Claude แก้ไข

3. /code-review อีกรอบ (optional)
   → ยืนยันว่าแก้ถูกต้อง
```

---

## 📊 Patterns จาก Codebase

### Pattern 1: Safe Command Execution

**จาก:** `tools/lib/check_runner.zsh`, `tools/subagents/orchestrator.zsh`

```zsh
run_check() {
  local cmd="$*"
  local output="$(mktemp)"
  local error="$(mktemp)"
  local rc=0
  
  {
    set +e
    eval "$cmd" >"$output" 2>"$error"
    rc=$?
    set -e
  } || true
  
  # Process result
  if [[ $rc -eq 0 ]]; then
    echo "✅ PASS"
  else
    echo "❌ FAIL (rc=$rc)"
  fi
  
  return 0  # Always return 0 to prevent early exit
}
```

**ใช้เมื่อ:** ต้องการ run multiple checks โดยไม่ให้ early exit

### Pattern 2: Environment Variable Fallback

**จาก:** `tools/claude_tools/metrics_collector.zsh`

```zsh
BASE="${LUKA_SOT:-$HOME/02luka}"
REDIS_PASS="${REDIS_PASSWORD:-gggclukaic}"
```

**ใช้เมื่อ:** ต้องการ default value แต่ยังรองรับ environment variable

### Pattern 3: Directory Creation with Verification

**จาก:** PLAN v1.1 Task 2.0, 3.0

```zsh
# Verify and create directory
if [[ ! -d "$BASE/g/knowledge" ]]; then
  mkdir -p "$BASE/g/knowledge"
fi

# Verify it was created
if [[ ! -d "$BASE/g/knowledge" ]]; then
  echo "❌ Failed to create directory"
  exit 1
fi
```

**ใช้เมื่อ:** ต้องการ directory แต่ไม่แน่ใจว่ามีอยู่แล้ว

### Pattern 4: JSON Validation Before Write

**จาก:** `run/health_dashboard.cjs`

```javascript
// Atomic write with validation
const tmp = OUT + '.tmp';
fs.writeFileSync(tmp, JSON.stringify(payload, null, 2));
JSON.parse(fs.readFileSync(tmp, 'utf8')); // validate
fs.renameSync(tmp, OUT);
```

**ใช้เมื่อ:** เขียน JSON file และต้องการให้แน่ใจว่า valid

---

## 🎓 Learning Resources

- **Onboarding Guide**: `docs/claude_code/ONBOARDING.md`
- **Troubleshooting**: `docs/claude_code/TROUBLESHOOTING.md`
- **Slash Commands**: `docs/claude_code/SLASH_COMMANDS_GUIDE.md`
- **Code Examples**: `tools/claude_hooks/`, `tools/claude_tools/`

---

**สถานะ**: ✅ Ready to Use  
**Version**: 1.0  
**Last Updated**: 2025-11-12

*เอกสารนี้จะถูกอัพเดทเมื่อมี patterns ใหม่หรือ best practices เพิ่มเติม*
