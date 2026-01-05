# LAC ATG Governance Contract (P0)
**Scope:** Antigravity "command run ค้าง / agent execution terminated"
**Goal:** ให้ LAC/CLI เป็น executor แบบ deterministic และลดการพึ่ง IDE execution path

---

## Principle
- **Antigravity = editor/viewer**
- **LAC/CLI = executor (diagnose + recover + verify)**
- ห้ามใช้ "Run command ผ่าน Antigravity" เป็นเส้นทางหลักในการแก้ปัญหา production/ops ของ 02luka

---

## Files
- `g/governance/atg_invariants.zsh`
- `g/governance/atg_remediation.zsh`

---

## Operating Flow (Required)

### Step 1 — Preflight (Always)
รัน invariant ก่อนเสมอ:

```bash
zsh ~/02luka/g/governance/atg_invariants.zsh
```

**Exit codes:**
- `0` = PASS → ไม่ต้องทำอะไร (หรือปัญหาไม่ใช่ chain นี้)
- `1` = FAIL → ไป Step 2 (SAFE remediation)

---

### Step 2 — Remediation (Default = SAFE)

```bash
zsh ~/02luka/g/governance/atg_remediation.zsh SAFE
```

**SAFE จะ:**
- kill เฉพาะ: codex app-server, antigravity-claude-proxy, LSP ที่เกี่ยว
- restart proxy แบบ best-effort (ถ้ามี binary ใน PATH)
- ไม่แตะ service อื่น (redis, gemini_bridge, launchd ของ 02luka ฯลฯ)

---

### Step 3 — Verify (Always)

หลัง remediation ต้องยืนยันด้วย invariants อีกครั้ง:

```bash
zsh ~/02luka/g/governance/atg_invariants.zsh
```

**Expected:**
- codex app-server = running (หรืออย่างน้อยไม่ duplicate)
- proxy = running (และ ideally port listen)
- LSP = warn ได้ (เพราะ lazy start) แต่ไม่ควรมี duplicate/hang pattern

---

### Escalation Rule

ใช้ HARD เฉพาะเมื่อ:
- SAFE ทำแล้วไม่ดีขึ้นภายใน 2 รอบ
- หรือทุก command ที่เกี่ยวกับ agent execution fail ต่อเนื่อง

```bash
zsh ~/02luka/g/governance/atg_remediation.zsh HARD
```

**HARD ยัง "จำกัดวง" แค่ helper/extension chain ของ Antigravity (ไม่แตะบริการอื่นของ 02luka)**

---

### Evidence (What to capture)

เมื่อเกิด incident ให้เก็บผลลัพธ์ 2 ชุดนี้:
1. output ของ `atg_invariants.zsh` ก่อนแก้
2. output ของ `atg_remediation.zsh SAFE` + `atg_invariants.zsh` หลังแก้

(ใน P0 ยังไม่บังคับให้เขียนไฟล์ log; แค่ output ก็ audit ได้)

---

### Success Criteria (P0)
- แก้อาการ "command run ค้าง" ได้โดยไม่ต้องปิดระบบอื่น
- ทำซ้ำได้ (idempotent) และแก้แบบ deterministic
- ลด dependency ต่อ Claude Code/IDE execution loop

---

### หมายเหตุสำคัญ (ตรง ๆ)
- สคริปต์นี้ "ไม่พยายาม" แก้ทุกสาเหตุของ Antigravity ค้าง (เพราะบางทีเป็น UI policy gate / PTY hang ภายใน IDE)
- แต่สำหรับเป้าคุณ (เลิกพึ่ง Claude Code + ให้ LAC เป็น executor) นี่คือ P0 ที่ถูกทิศ: **kill/restart เฉพาะคอขวด + prove ด้วย invariants**

ถ้าคุณต้องการ **P1** ต่อจากนี้ ผมจะเพิ่ม:
- "duplicate detector" แบบละเอียด (แยก PID + start time)
- "port map" ดึงจาก `tools/ports_check.zsh` แล้วตรวจตามจริง (ไม่ hardcode 8080)
- "evidence pack" ออกเป็นไฟล์เดียวใน `g/reports/ops/atg_incidents/YYMMDD_*.md` (ตามมาตรฐานการบันทึกของคุณ)
