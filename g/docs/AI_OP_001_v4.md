# 02luka Operational Protocol – Version 4.0.0 (Lego Edition)

Date: 2025-11-29
Authority: Boss
Status: Active – Replaces v1/v2/v3

---

## 1. Purpose

Version 4 turns the 02luka system into a modular, Lego-style architecture:
- ลดความซับซ้อนของกติกา
- ตัด WO เกินจำเป็น
- เปิดให้หลาย agent เขียนได้ (เฉพาะ Open Zones)
- ลด bottleneck ของ CLC
- ให้ระบบทำงานเร็วขึ้น ~5–10 เท่า

---

## 2. Core Principles

### 2.1 Lego Architecture

ทุกส่วนของระบบ ต้องสามารถ:
- แยก
- สลับ
- ต่อ
- เพิ่ม
- ถอด
ได้โดยไม่กระทบ core

### 2.2 Multi-Writer Model
- **ไม่ใช่ “One Writer Model” แล้ว**
- ต่อ 1 task จะมี “หนึ่ง lane ที่เขียนจริง”
- หลาย agent สามารถคิดร่วมกันได้ แต่เขียนได้ตาม routing เท่านั้น

### 2.3 2-Zone Model

**Locked Zones (LZ) – ต้องใช้ CLC/LPE เท่านั้น**

Paths:
- `core/**`
- `CLC/**`
- `launchd/**`
- `bridge/inbox/**`
- `bridge/outbox/**`
- `bridge/handlers/**`
- `bridge/core/**`
- `bridge/templates/**`
- `bridge/production/**`

**Open Zones (OZ) – เขียนได้ (Gemini, LAC, Codex, GC, GG, CLS)**

Paths:
- `apps/**`
- `tools/**`
- `agents/**`
- `tests/**`
- `docs/**`            (non-governance)
- `bridge/docs/**`
- `bridge/samples/**`

---

## 3. Work Order (WO) Rules

### 3.1 When WO is REQUIRED

WO จำเป็นเฉพาะกรณีต่อไปนี้:
1. แตะ Locked Zone (core/ CLC/ launchd/ bridge pipeline)
2. แตะ ≥ 3 ไฟล์
3. แก้ governance/protocol:
    - `AI_OP_001`
    - `02LUKA_PHILOSOPHY`
    - `CONTEXT_ENGINEERING_PROTOCOL`
    - `CLS agent spec`
4. เปลี่ยน system-level behavior
5. เปลี่ยน security/routing
6. เปลี่ยน logic ของ bridge/queue

### 3.2 When WO is NOT Required

กรณีปกติ (80% ของงาน):
- อยู่ใน Open Zones
- ≤ 3 files
- ≤ 500 lines
- Not governance
- ไม่แตะ system behavior
→ ทำได้เลย, commit ได้เลย, no WO

---

## 4. Writer Capabilities (Who Can Write What)

| Agent | Locked | Open | Notes |
| :--- | :---: | :---: | :--- |
| **CLC** | ✅ | ⚠️ rare | Primary Locked writer |
| **LPE** | ⚠️ emergency only | ❌ | Dumb executor, Boss approval |
| **CLS** | ❌ | ✅ | Under routing |
| **Gemini** | ❌ | ✅ | For code/content rewrite |
| **LAC** | ❌ | ✅ | Autonomous code generation |
| **Codex** | ❌ | ✅ | Diff-only |
| **GG Core** | ❌ | ⚠️ propose only | GG never writes directly |
| **GC Core** | ❌ | ⚠️ propose only | GC never writes directly |

---

## 5. Routing Rules (v4)

### 5.1 Routing decides:
- Writer lane
- WO vs no-WO
- Which model to use (Gemini/GG/LAC/CLS/CLC)

### 5.2 First-Writer-Locks Rule

เมื่อ routing เลือก lane แล้ว:
- Lane นั้นเป็นคนเดียวที่ write
- อื่นเสนอได้ แต่ห้ามเขียน

### 5.3 Drift to Locked Zone → auto-escalate

ถ้าเริ่มจาก Open Zone แล้วงาน drift ไปแตะ Locked:
- ระบบต้อง reroute → CLC
- ทำ WO เพิ่มถ้าจำเป็น

---

## 6. Safety & Audit

### 6.1 mktemp → mv (SIP)

ทุกการแก้ไขต้องใช้กระบวนการ:
`mktemp → write → validate → mv`

### 6.2 Open Zone Audit

เมื่อ WO ไม่จำเป็น:
- commit message ต้อง tag เช่น `[LAC]`, `[Gemini]`, `[CLS]`, `[Codex]`
- diff summary ต้องถูกบันทึกใน MLS (auto)
- ตัวเลือกเพิ่ม: `mls/open_zone_history/YYYYMMDD/<filename>.bak`

### 6.3 Locked Zone Audit

ต้องผ่าน:
- WO
- CLC apply
- Full diff
- SHA256 evidence

---

## 7. Governance Document Set (v4)

เอกสารทั้งหมดในรายการนี้ = **Locked Zone** by definition:
1. `g/docs/AI_OP_001_v4.md`
2. `g/docs/02LUKA_PHILOSOPHY_v1.3.md`
3. `g/docs/CONTEXT_ENGINEERING_PROTOCOL_v4.md`
4. `CLS/agents/CLS_agent_latest.md`
5. LaunchAgent registry
6. Queue/routing spec
7. Identity Matrix
8. Core Registration Protocol
9. System Setup Guide
10. Sandbox/Isolation Policy

---

## 8. Conflict Resolution Model

**Rule 1: First-Writer-Locks**
ถ้า lane ถูกเลือกแล้ว → ห้ามเปลี่ยน writer

**Rule 2: Drift → escalate**
Open → Locked → reroute to CLC

**Rule 3: Post-facto correction**
ถ้ามี mistake ใน OZ ที่มี impact → route to CLC for correction

---

## 9. LPE (Local Patch Executor)
- ไม่คิด ไม่วิเคราะห์
- ไม่สามารถ invoke โดย AI อื่น
- ใช้เป็น emergency เท่านั้น
- ต้องมี Boss approval ใน chat
- ต้องสร้าง MLS emergency log ทุกครั้งที่ใช้

---

## 10. Backward Compatibility
- WO v1-v3 ทั้งหมดยัง valid
- One Writer Model = archived (legacy mode)
- Routing v4 ใช้แทนกติกาเก่าแบบทันที
- ไม่มี breaking change กับ runtime agents
- ไม่มีผลกับ Redis queues หรือ protocol เดิม

---

## 11. Migration Notes
- Governance v4 ใช้ได้ทันที (mental model)
- แต่ไฟล์ governance 4 ชุดนี้จะกลายเป็น SOT โดยสมบูรณ์เมื่อ merge PR
- ไม่จำเป็นต้อง migrate code ก่อน
- Code migration v4.1/v4.2 ตามแผน roadmap

---

## 12. Version

**AI/OP-001 v4.0.0 (Lego Edition)**
Status: Active
Supersedes: v1, v2, v3
SOT: `g/docs/AI_OP_001_v4.md`
