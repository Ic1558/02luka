# Governance v5 Readiness SPEC — "Production Ready v5"

**Date:** 2025-12-10  
**Owner:** GG / Mary / CLS / CLC  
**Scope:** Router v5 + SandboxGuard v5 + CLC Executor v5 + SIP Engine v5 + WO Processor v5  
**Goal:** กำหนด "เกณฑ์ขั้นต่ำ" ที่ต้องผ่านก่อนจะกล้าติดป้ายว่า **Production Ready v5**

---

## 1. Definition of States

เราจะใช้ 3 สถานะชัดเจน:

1. `IMPLEMENTED (Standalone)`
   - โค้ดแต่ละ Block มีไฟล์จริง, import ได้, ฟังก์ชันหลักครบ
   - ยังไม่ผูกกับ Gateway v3 / Mary Router
   - ยังไม่บังคับใช้ใน production

2. `WIRED (Integrated)`
   - Gateway v3 Router / Mary Dispatcher เรียกใช้ v5 stack จริง
   - MAIN inbox → WO Processor v5 → Router v5 → SandboxGuard v5 → (Local / CLC / SIP)
   - ยังไม่ผ่าน full test suite + health checks

3. `PRODUCTION READY v5`
   - ทั้งโค้ด, wiring, tests, health, rollback, docs **ผ่านทุกเกณฑ์ใน SPEC นี้**
   - ใช้จริงใน production path ได้ และถ้า fail มีแผน rollback ชัดเจน

ห้ามใช้คำว่า "Production Ready v5" ถ้า checklist ในไฟล์นี้ยังไม่ครบ

---

## 2. Blocks in Scope

- Block 1 — `bridge/core/router_v5.py`
- Block 2 — `bridge/core/sandbox_guard_v5.py`
- Block 3 — `agents/clc/executor_v5.py`
- Block 4 — `bridge/core/sip_engine_v5.py`
- Block 5 — `bridge/core/wo_processor_v5.py`

---

## 3. Readiness Gates (PR-*)

การเลื่อนจาก `IMPLEMENTED (Standalone)` → `PRODUCTION READY v5` ต้องผ่านทุก Gate:

### PR-1 — Code & Docs Integrity

**Objective:** ไม่มี "โกหกตัวเอง" ระหว่างโค้ดกับเอกสาร

Checklist:

- [ ] ทุกไฟล์ Block 1–5 มีอยู่จริง, import ได้ โดยใช้:
  - `python -m compileall` หรือเทียบเท่า
- [ ] `251209_reality_checklist.md` อัปเดตล่าสุด และไฟล์ทุก block ตรงกับขนาด+path จริง
- [ ] References ใน:
  - `GOVERNANCE_UNIFIED_v5.md`
  - `PERSONA_MODEL_v5.md`
  - `AI_OP_001_v5.md`
  - `SCOPE_DECLARATION_v1.md`
  
  ไม่มีการอ้างอิง function / module ที่ไม่มีจริง (เช่น v4 vs v5 name mismatch)
- [ ] รายงาน "IMPLEMENTED (Standalone)" ล่าสุด (เช่น `251209_real_implementation_validation_REPORT.md`) ไม่ claim เกินความจริง (ไม่มีคำว่า "production ready" ถ้ายังไม่ผ่าน PR-2–PR-6)

**Pass condition:** ไม่มี mismatch ระหว่าง docs ↔ code ที่เป็นสาระ (semantic)

---

### PR-2 — Test Execution & Quality Gate

**Objective:** ไม่ให้ v5 เข้าระบบโดยไม่มี test รันจริง

Minimum:

- [ ] ติดตั้ง test runner ที่ใช้งานได้อย่างน้อยหนึ่ง:
  - `pytest` **หรือ** `python tests/v5_runner_unittest.py`
- [ ] ทดสอบกลุ่ม v5 ทั้งหมด:

  ```bash
  pytest tests/v5_* -v   # หรือเทียบเท่า
  ```

- [ ] เก็บผลรัน test เป็นไฟล์:
  - `g/reports/feature-dev/governance_v5_unified_law/2512xx_v5_tests_RESULTS.json`
  - หรือ log เทียบเท่า
- [ ] ไม่มี test ที่ fail โดยไม่ได้ mark เป็น xfail หรือ "known limitation"
- [ ] สำหรับ test ที่เกี่ยวกับ security / DANGER zone / rollback:
  - ต้องผ่าน 100% (ไม่มี fail/xfail)
- [ ] มี test อย่างน้อยในกลุ่มนี้:
  - Router v5 world/zone/lane routing
  - SandboxGuard v5 path/content safety
  - Executor v5 งานปกติ + rollback path
  - SIP Engine v5 multi-file atomic transaction
  - WO Processor v5 lane-based routing (FAST/WARN vs STRICT)

**Quality Gate:**
- [ ] สรุปรวมใน report ว่า:
  - จำนวน tests ทั้งหมด
  - จำนวนผ่าน/ตก
  - ระบุ explicit ว่า security-critical tests = 100% PASS

---

### PR-3 — Production Wiring (Gateway v3 Integration)

**Objective:** v5 stack ต้องอยู่ใน flow จริงของระบบ โดยไม่ bypass lane semantics

Minimum wiring:

- [ ] Gateway v3 Router / Mary Router ใช้:

  ```python
  bridge/inbox/MAIN/ → wo_processor_v5.process_wo_from_main(...)
  ```

- [ ] WO Processor v5 ใช้ Router v5 เพื่อ determine lane:
  - STRICT → create CLC WO → `bridge/inbox/CLC/`
  - FAST/WARN → local execution (agent + SandboxGuard)
  - BLOCKED → error + log → `bridge/error/MAIN/`

- [ ] ห้าม drop WO ตรงไป `bridge/inbox/CLC/` จากระบบอัตโนมัติ (ยกเว้น manual emergency)
- [ ] CLC Executor v5 (`agents/clc/executor_v5.py`) ถูกเรียกจาก worker/background lane เท่านั้น
- [ ] MAIN inbox flow ตรวจแล้วว่า:
  - WO จาก Kim/Mary/Entry ไปเข้า MAIN
  - ไม่มี path ลักลอบข้าม Router v5/SandboxGuard v5

**Evidence:**
- [ ] ไฟล์ config ของ Gateway v3 (เช่น `g/config/mary_router_gateway_v3.yaml`) อัปเดตแล้วให้ชี้ไปหา v5
- [ ] มี report wiring เช่น `2512xx_v5_integration_wiring_REPORT.md`
  - แสดง diagram: MAIN → WO Processor v5 → Router v5 → (Local/CLC/SIP)

---

### PR-4 — Health, Telemetry, and Alerts

**Objective:** ถ้า v5 ตาย/ค้าง ต้องรู้และมี alert

Minimum:

- [ ] มี health check script อย่างน้อยหนึ่ง:
  - เช่น `tools/check_mary_gateway_health.zsh`
- [ ] Health check ตรวจอย่างน้อย:
  - LaunchAgent status (`com.02luka.*`)
  - Gateway v3 / Mary Router process (`ps`)
  - ล่าสุด activity ใน log (เช่น `g/telemetry/gateway_v3_router.log`)
  - backlog ใน `bridge/inbox/MAIN/` และ `bridge/inbox/CLC/`
- [ ] มี telemetry log แยกสำหรับ:
  - Router v5 decisions
  - SandboxGuard v5 denials
  - CLC Executor v5 executions (ผ่าน audit log)
- [ ] มีทางเรียก health check ง่าย ๆ:
  - ผ่าน CLI
  - หรือผ่าน Kim / Telegram command (เช่น `/v5-health`)

**Pass condition:**
- [ ] Report แสดงผล health check ล่าสุด + sample output
- [ ] อธิบาย flow แจ้งเตือน (ใครจะรู้ว่าพัง, ผ่านช่องทางไหน)

---

### PR-5 — Rollback & Safety Guarantees

**Objective:** ถ้า v5 ทำพลาด ต้อง rollback ได้จริง ไม่ใช่แค่เขียนใน spec

Minimum:

- [ ] สำหรับอย่างน้อย 1 real WO (sample high-risk):
  - ทดสอบ `git_revert` rollback ผ่าน `apply_rollback()`
  - ยืนยันว่าไฟล์กลับสู่ state ก่อนหน้า (checksum match)
- [ ] DANGER zone rules ทดสอบจริง:
  - Operation ที่ target `/System`, `/usr`, `~/.ssh`, หรือ path นอก 02luka ถูก block แน่นอน
- [ ] LOCKED zone:
  - ไม่มี autonomous write โดย agent ที่ไม่ใช่ CLC/CLS ตาม persona matrix
- [ ] CLS auto-approve:
  - เฉพาะ path ที่อยู่ใน Mission Scope WHITELIST
  - AUTO-approve ถูก block ถ้า:
    - path in blacklist
    - ไม่มี rollback strategy
    - ไม่มี evidence ว่า Boss/CLS เคย approve pattern นี้มาก่อน

**Evidence:**
- [ ] Report sandbox/rollback test: `2512xx_v5_safety_validation_REPORT.md`
- [ ] มี log path + checksum ก่อน/หลัง ให้ตรวจย้อนหลังได้

---

### PR-6 — Runbook & Operational Usage

**Objective:** คน/agent อื่นต้องใช้ v5 ได้โดยไม่ต้องอ่านโค้ด

Minimum:

- [ ] Runbook/How-to file:
  - เช่น `V5_ROUTING_RUNBOOK.md` หรือ section ใน `HOWTO_TWO_WORLDS_v2.md`
- [ ] ชี้ให้ชัด:
  - ใครควร drop WO ที่ไหน (ENTRY vs MAIN vs CLC emergency)
  - จะ debug routing decision ยังไง (CLI usage ของ `router_v5.py`)
  - จะ check sandbox decision ยังไง
  - วิธีอ่าน audit log ของ CLC Executor
- [ ] มี example end-to-end scenario 1–2 เคส:
  - CLS แก้ไฟล์ใน OPEN zone (FAST lane)
  - BACKGROUND job แก้ไฟล์ใน LOCKED zone (STRICT lane → CLC)

**Pass condition:**
- [ ] มี report/markdown ที่ agent อื่นใช้เป็น reference ได้ โดยไม่ต้องถาม GG/GC เพิ่ม
- [ ] ตัวอย่างคำสั่งจริง (copy-paste ได้) อยู่ใน runbook

---

## 4. Labeling Rules

เมื่อผ่าน PR-1 ถึง PR-6:

- [ ] อนุญาตให้ใช้ label:
  ```
  Status: ✅ PRODUCTION READY v5
  ```
- [ ] ต้องมีไฟล์สรุป readiness เช่น:
  - `251210_governance_v5_readiness_CHECKLIST.md`
  - รวม checklist (PR-1..PR-6) + evidence (paths/commands/logs)

ห้ามเขียนใน report ใด ๆ ว่า "Production Ready v5" ถ้า:

- [ ] Checklist ไฟล์นี้ยังไม่ tick ครบ
- [ ] หรือ evidence ยังไม่แนบใน report คู่กัน

---

## 5. Minimal Evidence Pack (What to attach)

สำหรับการประกาศว่า "Ready v5" จริง ๆ ต้องมีอย่างน้อย:

1. `v5_tests_RESULTS.json` หรือ log เทียบเท่า
2. Wiring diagram / description ของ MAIN → v5 stack
3. Health check output ล่าสุด 1 ชุด
4. Rollback test report 1 เคสจริง
5. Runbook พร้อม sample flows

ถ้า Evidence ไม่ครบ = ยังถือว่าอยู่แค่ `IMPLEMENTED (Standalone)` หรือ `WIRED (Integrated)` เท่านั้น

---

**Last Updated:** 2025-12-10

