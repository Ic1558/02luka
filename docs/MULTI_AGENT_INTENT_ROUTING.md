# Multi-Agent Intent Routing Cheat Sheet

**Purpose:** ให้ทั้งคนและ bot ใช้เป็น "คู่มือสั้น ๆ" ในการตัดสินว่า task ปัจจุบันควรถูกแปลงเป็นอะไร:

- Git PR
- Local fix (ไม่ต้อง PR)
- Work Order (WO)
- แค่ถาม / จด note

---

## 1. Routing Question Tree

### 1️⃣ **แตะไฟล์ใน repo จริงไหม?**

- ถ้าไม่ → อาจเป็นแค่ **"Asking / Planning"**

- ถ้าใช่ → ไปข้อ 2

### 2️⃣ **แตะไฟล์ระบบกลางไหม?**  

(`.github`, `docs` ระบบ, `launchd/LaunchAgents`, `tools` shared, `config`, `schemas`, `telemetry`, `state`, `system_map`)

- ถ้าใช่ → **PR / Feature / Governance**

- ถ้าไม่ → ไปข้อ 3

### 3️⃣ **เป็นแค่แก้ implementation จุดเล็ก ๆ ไหม (1–2 module, no protocol)?**

- ถ้าใช่ → **Local Fix**

- ถ้าไม่ → ไปข้อ 4

### 4️⃣ **เกี่ยวกับ automation / worker / pipeline / launchd / tools/wo_pipeline ไหม?**

- ถ้าใช่ → **Work Order (WO) / Automation PR**

### 5️⃣ ถ้าไม่ตรงอะไรเลย → default = **PR (small)** + specify ใน template ให้ชัด

---

## 2. Signal จากข้อความธรรมชาติ (สำหรับ bot)

### ถ้ามีคำว่า:

- **"template"**, **"governance"**, **"sandbox"**, **"guardrail"**, **"multi-agent"**

  → bias = **PR / Governance**

- **"ลองแก้ log ตรงนี้"**, **"แค่เปลี่ยนข้อความ"**, **"แค่ refactor function เดียว"**

  → candidate = **Local Fix**

- **"deploy script"**, **"run worker"**, **"ตั้ง LaunchAgent"**, **"wo pipeline"**

  → candidate = **WO / Automation**

- **"ช่วยคิด"**, **"อธิบายหน่อย"**, **"ทำ spec"**, **"PLAN อย่างเดียว"**

  → candidate = **Asking / Docs-only**

bot สามารถใช้ signal เหล่านี้ + paths ที่แตะจริงใน diff เพื่อ confirm อีกที

---

## 3. Contract ระหว่าง GG / GC / CLS / Mary

### ถ้าระบุ type ผิด:

- GG/GC สามารถ **"ยกระดับ"** type ได้ (จาก Local → PR / WO)

- แต่ห้ามลดระดับ PR ที่มี security / governance ลงเป็น Local Fix

### Mary ใช้ type พวกนี้เพื่อตัดสินใจว่าจะ:

- รันเทสไหน

- ส่ง alert ไปหาใคร

- เขียน report อะไรเพิ่ม

---

## 4. Quick Reference Table

| Signal | Type | Example |
|--------|------|---------|
| `.github/`, `docs/` (system) | PR / Governance | PR template, sandbox rules |
| Security, auth, path | PR / Governance | Path traversal fix, auth token |
| 1-2 files, no protocol | Local Fix | Typo fix, log message |
| `tools/wo_pipeline/`, `agents/` | WO / Automation | New worker, deploy script |
| Spec, PLAN, docs only | Asking | Feature spec, exploration |

---

## 5. Edge Cases

### ถ้า Local Fix แต่แตะ `launchd/` หรือ `tools/wo_pipeline/`:

→ ยกระดับเป็น **WO** หรือ **PR / Governance**

### ถ้าเป็น Docs แต่เปลี่ยน behavior ของ agent:

→ ยกระดับเป็น **PR / Governance**

### ถ้าไม่แน่ใจ:

→ เลือก **PR / Governance** (ปลอดภัยกว่า)

---

**Related Documents:**

- `docs/MULTI_AGENT_PR_CONTRACT.md` - Full contract specification
- `.github/PULL_REQUEST_TEMPLATE.md` - PR template with routing types

