# Claude Code - Quick Start Guide

**สถานะ**: ✅ Production Ready  
**เวลาในการตั้งค่า**: ~5 นาที  
**อัพเดทล่าสุด**: 2025-11-12

---

## 🎯 ภาพรวม

Claude Code Best Practices System คือชุดเครื่องมือและ workflow ที่ช่วยให้การพัฒนาโค้ดด้วย Claude AI มีประสิทธิภาพและปลอดภัยมากขึ้น

### สิ่งที่คุณจะได้

- ✅ **Slash Commands**: คำสั่งพิเศษสำหรับ feature development, code review, deployment
- ✅ **Automated Hooks**: ตรวจสอบคุณภาพโค้ดอัตโนมัติก่อน commit/deploy
- ✅ **Subagent Orchestration**: ใช้หลาย agents ทำงานร่วมกันสำหรับ code review
- ✅ **Metrics & Monitoring**: ติดตามการใช้งานและสุขภาพระบบ

---

## ⚡ Quick Start (5 นาที)

### ขั้นตอนที่ 1: ตรวจสอบ Prerequisites

```bash
# ตรวจสอบว่า Cursor/Claude Code ใช้งานได้
# เปิด Cursor → Cmd+L (Chat) → พิมพ์ "hello"

# ตรวจสอบว่า git repository ถูกต้อง
cd ~/02luka
git status
```

### ขั้นตอนที่ 2: ตรวจสอบ Commands

```bash
# ตรวจสอบว่า commands มีอยู่
ls -la ~/02luka/.claude/commands/

# ควรเห็น:
# - feature-dev.md
# - code-review.md
# - deploy.md
# - commit.md
# - health-check.md
```

### ขั้นตอนที่ 3: ทดสอบ Command แรก

เปิด Cursor Chat (Cmd+L) แล้วพิมพ์:

```
/feature-dev
```

Claude จะถามคำถามชี้แจงก่อนสร้าง SPEC และ PLAN

---

## 📚 First Run Example

### ตัวอย่าง: สร้าง Feature ใหม่

**1. เริ่มด้วย `/feature-dev`:**

```
User: /feature-dev
      เพิ่ม API endpoint สำหรับ export ข้อมูล MLS เป็น CSV

Claude: ขอถามชี้แจงก่อนครับ:
        1. ข้อมูล MLS ทั้งหมด หรือกรองตามวันที่?
        2. รูปแบบ CSV ต้องการ column อะไรบ้าง?
        3. จำกัดขนาดไฟล์ไหม (เช่น max 10MB)?
        4. Authentication ใช้วิธีเดียวกับ API อื่นๆ?

User: ตามวันที่, column ทั้งหมด, ไม่จำกัดขนาด, ใช่ auth เดียวกัน

Claude: เข้าใจแล้วครับ กำลังสร้างแผน...

        📋 SPEC.md
        📋 PLAN.md
```

**2. Review SPEC และ PLAN:**

```bash
# ดู SPEC
cat ~/02luka/g/reports/feature_mls_export_csv_SPEC.md

# ดู PLAN
cat ~/02luka/g/reports/feature_mls_export_csv_PLAN.md
```

**3. เริ่ม Implementation:**

```
User: เริ่มทำตาม PLAN ข้อ 1: สร้าง API route

Claude: [สร้างโค้ดตาม PLAN]
```

**4. Code Review:**

```
User: /code-review
      Review API route ที่สร้างเสร็จแล้ว

Claude: [Multi-agent review results]
```

**5. Deploy:**

```
User: /deploy
      Deploy MLS export API to production

Claude: [Deployment checklist]
```

---

## 🛠️ Commands ที่มี

### 1. `/feature-dev` - พัฒนา Feature ใหม่

**เมื่อไหร่ใช้:**
- สร้าง feature ใหม่ที่ซับซ้อน
- ต้องการแผนการพัฒนาที่ชัดเจน
- ไม่แน่ใจว่าจะเริ่มต้นอย่างไร

**ตัวอย่าง:**
```
/feature-dev
เพิ่ม caching layer สำหรับ API responses
```

### 2. `/code-review` - Review โค้ด

**เมื่อไหร่ใช้:**
- Review PR ก่อน merge
- ต้องการ second opinion
- โค้ดมีความซับซ้อนสูง

**ตัวอย่าง:**
```
/code-review
Review PR #123 ที่เพิ่ม authentication module
```

### 3. `/deploy` - Deploy ระบบ

**เมื่อไหร่ใช้:**
- Deploy ไปยัง production
- Deploy configuration changes ที่สำคัญ
- ต้องการ rollback plan

**ตัวอย่าง:**
```
/deploy
Deploy updated authentication module to production
```

### 4. `/commit` - สร้าง Commit

**เมื่อไหร่ใช้:**
- Commit changes หลังจากแก้ไขเสร็จ
- ต้องการให้ commit message ถูกต้องตาม Conventional Commits

**ตัวอย่าง:**
```
/commit "feat(api): add MLS export endpoint"
```

### 5. `/health-check` - ตรวจสอบสุขภาพระบบ

**เมื่อไหร่ใช้:**
- ตรวจสอบว่าระบบทำงานปกติ
- หลัง deploy เพื่อยืนยันว่าไม่มีปัญหา

**ตัวอย่าง:**
```
/health-check
```

---

## 📋 Sample SPEC/PLAN Template

เมื่อใช้ `/feature-dev` คุณจะได้ SPEC และ PLAN ที่มีโครงสร้างแบบนี้:

### SPEC Structure

```markdown
# Feature Specification: [Feature Name]

**Feature ID:** `feature_slug`  
**Date:** YYYY-MM-DD  
**Status:** 📋 **SPECIFICATION**

## Objective
[What this feature does]

## Context
[Why this feature is needed]

## Requirements
### Must Have
- [Requirement 1]
- [Requirement 2]

## Design
[How it will be implemented]

## Acceptance Criteria
1. ✅ [Criterion 1]
2. ✅ [Criterion 2]
```

### PLAN Structure

```markdown
# Feature Plan: [Feature Name]

**Time Estimate:** X hours  
**Approach:** MVS / Full  
**Strategy:** [Strategy description]

## Task Breakdown

### Phase 1: [Phase Name]
**Time:** X hours

#### Task 1.1: [Task Name]
- [ ] Step 1
- [ ] Step 2
- **Deliverable:** [What you'll get]

## Test Strategy
[How to test]

## Success Criteria
1. ✅ [Criterion 1]
2. ✅ [Criterion 2]
```

---

## ✅ Verification Checklist

หลังจาก setup เสร็จ ตรวจสอบว่า:

- [ ] Commands ทั้ง 5 ตัวใช้งานได้ (`/feature-dev`, `/code-review`, `/deploy`, `/commit`, `/health-check`)
- [ ] สามารถสร้าง SPEC/PLAN ได้ (`/feature-dev`)
- [ ] Code review ทำงานได้ (`/code-review`)
- [ ] Health check ผ่าน (`/health-check`)
- [ ] ไม่มี hook errors เมื่อ commit

---

## 🆘 ปัญหาที่พบบ่อย

### Problem: Command ไม่ทำงาน

**อาการ:** พิมพ์ `/feature-dev` แล้วไม่มีอะไรเกิดขึ้น

**วิธีแก้:**
```bash
# ตรวจสอบว่า command file มีอยู่
ls -la ~/02luka/.claude/commands/feature-dev.md

# ตรวจสอบว่า Cursor เปิดอยู่และ Chat ทำงาน
# ลองพิมพ์ข้อความธรรมดาใน Chat ก่อน
```

### Problem: Hook errors เมื่อ commit

**อาการ:** `git commit` แล้วมี error จาก hooks

**วิธีแก้:**
```bash
# ดู error message
git commit -m "test"

# ถ้าเป็น hook error ให้ดู:
cat ~/02luka/logs/pre_commit.err.log

# หรือดู BEST_PRACTICES.md และ TROUBLESHOOTING.md
```

---

## 📖 เอกสารเพิ่มเติม

- **Best Practices**: `docs/claude_code/BEST_PRACTICES.md`
- **Troubleshooting**: `docs/claude_code/TROUBLESHOOTING.md`
- **Slash Commands Guide**: `docs/claude_code/SLASH_COMMANDS_GUIDE.md`
- **Directory Structure**: `docs/claude_code/DIRECTORY_STRUCTURE.md`

---

## 🎓 Next Steps

1. **ทดลองใช้ `/feature-dev`** กับ feature เล็กๆ
2. **อ่าน BEST_PRACTICES.md** เพื่อเรียนรู้ patterns ที่ดี
3. **ใช้ `/code-review`** กับ PR ถัดไป
4. **ใช้ `/deploy`** ทุกครั้งที่ deploy production

---

**สถานะ**: ✅ Ready to Use  
**Version**: 1.0  
**Last Updated**: 2025-11-12

*คู่มือนี้จะถูกอัพเดทเมื่อมี features ใหม่หรือการปรับปรุง*
