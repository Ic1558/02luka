# Production Ready v5 — Battle-Tested SPEC

**Date:** 2025-12-11  
**Depends on:** `251210_governance_v5_readiness_SPEC.md`  
**Previous State:** WIRED (Integrated)  
**Target State:** PRODUCTION READY v5 — BATTLE-TESTED

---

## 0. Definition

**"Production Ready v5 — Battle-Tested"** =
1. v5 stack ทำงานใน production จริงต่อเนื่อง
2. มี เคสผิดพลาดจริง ที่ถูกจับได้ → rollback/guard ทำงานถูกต้อง
3. มี หลักฐานเชิงตัวเลข + log รองรับ (ไม่ใช่แค่ report เขียนว่า "โอเค")

จนเชื่อได้ว่า:

**"ถ้ามันพัง มันจะพังแบบควบคุมได้, ไม่ทำลาย SOT, และเรารู้เร็ว"**

---

## 1. Pre-condition (ต้องผ่านก่อน)

ทั้งหมดจาก Readiness v5 ต้อง ผ่านแล้วจริง:
- ✅ PR-1: Code & Docs Integrity
- ✅ PR-2: Full v5 test suite green (ไม่มี fail ไม่ได้ mark xfail)
- ✅ PR-3: Gateway v3 wiring → v5 stack active
- ✅ PR-4: Health/Telemetry/Monitoring พร้อม
- ✅ PR-5: Safety & rollback tests (ใน test env) ผ่าน
- ✅ PR-6: Runbook พร้อมใช้งาน

**State ณ ตอนนี้:** WIRED (Integrated) — Limited Production Verification  
→ จากตรงนี้แหละที่เราจะดันขึ้น "Battle-Tested"

---

## 2. PR-7 — Real Production Usage (Volume)

**Objective:** มี "จำนวนครั้ง" มากพอในโลกจริง ไม่ใช่แค่ sample 3 ครั้ง

**Criteria:**
- v5 operations ≥ 30 ภายในช่วงเวลา ≥ 7 วัน
- นับจาก `g/telemetry/gateway_v3_router.log` ที่ `action:"process_v5"`
- การกระจาย lane:
  - `strict_ops` ≥ 5 (มีดีลที่เข้า STRICT lane จริง)
  - `local_ops` ≥ 20 (งาน local FAST/WARN ปกติ)
  - `rejected_ops` ≥ 1 (เคสถูก block จริง)

**Evidence:**
- ไฟล์สรุป: `2512xx_v5_production_usage_STATS.json`
- รวมตัวเลข: total ops / strict / local / rejected
- ช่วงวันที่ที่นับ

---

## 3. PR-8 — Real Error & Recovery

**Objective:** ไม่ใช่โลกสวย ต้องมี incident จริง แล้วระบบรับมือได้

**Criteria (อย่างน้อย):**
- Error จริง ≥ 3 เคส ที่ v5 จับได้ (ไม่ใช่ legacy)
- เช่น YAML parse error, invalid target, sandbox block
- ถูกบันทึกใน `bridge/error/MAIN/` + telemetry
- ทุก error เคส:
  - main/CLC inbox ไม่ติด backlog ค้าง
  - gateway/mary ไม่ crash
  - log ระบุเหตุ + moved_to ชัดเจน

**Evidence:**
- Incident summary: `2512xx_v5_incident_log.md`
- รายการ: timestamp, wo_id, cause, system reaction, manual action (ถ้ามี)

---

## 4. PR-9 — Real Rollback Exercise (Live)

**Objective:** พิสูจน์ว่า rollback ทำงาน "ของจริง" อย่างน้อย 1 ครั้ง

**Criteria:**
- เลือก WO high-risk 1 เคส (STRICT lane → CLC) ในโฟลเดอร์ที่ปลอดภัย (เช่น sandbox file, ไม่ใช่ 02luka.md)
- ให้ CLC Executor v5 ทำงาน → เขียนไฟล์จริง
- แล้ว เจตนาสั่ง rollback ผ่าน `apply_rollback()` (เช่น git_revert)
- ตรวจสอบ:
  - checksum ก่อน/หลัง ตรงกัน
  - audit log ใน `g/logs/clc_execution/...json` มี fields ครบ:
    - `before_checksum`
    - `after_checksum`
    - `rollback_strategy`
    - `status = "rollback_ok"`

**Evidence:**
- `2512xx_v5_live_rollback_REPORT.md`
- WO id, target files, checksums, log path

---

## 5. PR-10 — CLS Auto-Approve in Real Use

**Objective:** พิสูจน์ว่า CLS auto-approve ทำงานตาม mission scope จริง ๆ

**Criteria:**
- อย่างน้อย 2 เคส CLS auto-approve (WARN lane) ใน path แบบนี้:
  - `bridge/templates/...` หรือ `g/reports/...` หรือโซนที่เรากำหนดเป็น WHITELIST
- ทุกเคสต้องมี:
  - `rollback_strategy` ถูกใส่ใน context
  - `boss_approved_pattern` match กับ pattern ที่เคยใช้จริง
  - sandbox ไม่ block
- ไม่มีเคส CLS auto-approve:
  - ใน blacklist zone (`core/`, `bridge/core/`, `launchd/` ฯลฯ)

**Evidence:**
- Extract log จาก v5 telemetry + CLS audit → รวมเป็น `2512xx_cls_auto_approve_EVIDENCE.md`

---

## 6. PR-11 — Monitoring Stability Window

**Objective:** ดูเสถียรภาพ v5 ภายใต้ usage จริง

**Window:** อย่างน้อย 7 วันต่อเนื่อง นับจากวันที่เริ่มใช้ v5 จริง (ไม่ใช่ test)

**Criteria:**
- `monitor_v5_production.zsh` รันอย่างน้อย วันละ 1 ครั้ง
- ใน window นี้:
  - status ไม่เคยเป็น "down" หรือ "degraded"
  - `error_stats.error_rate` ของ v5 ops ≤ 10%
  - `inbox_backlog.main == 0` (ไม่มี WO ติดค้าง)
  - `inbox_backlog.clc == 0` (ไม่มี YAML pending ใน root CLC)

**Evidence:**
- capture output monitor รวม 7 วัน → `2512xx_v5_monitor_window_SUMMARY.md`

---

## 7. PR-12 — Post-Mortem & Final Sign-off

**Objective:** สรุปภาพรวม, ยอมรับว่ามัน "ผ่านไฟต์จริงแล้ว"

**Criteria:**
- Document เดียวสรุปทั้งหมด: `2512xx_v5_battle_tested_FINAL.md`
- ต้องมี:
  1. ตัวเลขรวม: total ops, strict/local/rejected, errors, rollback count
  2. สรุป incident สำคัญ + บทเรียน
  3. ยืนยันตาม checklist:
     - PR-7 fulfilled
     - PR-8 fulfilled
     - PR-9 fulfilled
     - PR-10 fulfilled
     - PR-11 fulfilled
  4. Final statement:
     > "As of <date>, Governance v5 routing stack is Production Ready (Battle-Tested) under real workload in 02luka. Future failures are expected to be contained and diagnosable using the documented runbooks and telemetry."

---

## Short "จากตรงนี้ไปยัง Battle-Tested" (สำหรับ GG / Liam / CLS)

1. ใช้ระบบจริง: ให้ทุก WO เข้าที่ MAIN → v5 stack (ห้าม bypass)
2. ให้ monitor รันทุกวัน → เก็บ output
3. บังคับ incident log: ทุก error ให้เขียนลง incident markdown
4. จงใจซ้อม rollback 1 เคสที่ควบคุมได้
5. รอให้ usage ≥ 30 ops + window 7 วันผ่านไป
6. รัน checklist PR-7..PR-12 → ถ้าครบ → เขียน `..._FINAL.md` แล้วค่อยเปลี่ยน status เป็น:
   - **Status:** ✅ **PRODUCTION READY v5 — Battle-Tested**

---

## Labeling Rules

**เมื่อผ่าน PR-7 ถึง PR-12:**
- อนุญาตให้ใช้ label: **Status: ✅ PRODUCTION READY v5 — Battle-Tested**
- ต้องมีไฟล์สรุป readiness: `2512xx_v5_battle_tested_FINAL.md`
- รวม checklist (PR-7..PR-12) + evidence (paths/commands/logs)

**ห้ามเขียนใน report ใด ๆ ว่า "Production Ready v5 — Battle-Tested" ถ้า:**
- Checklist ไฟล์นี้ยังไม่ tick ครบ
- หรือ evidence ยังไม่แนบใน report คู่กัน

---

## Current Status

**State:** ✅ **WIRED (Integrated)** — Limited Production Verification

- ✅ All PR-1 to PR-6 complete
- ⏳ PR-7 to PR-12: PENDING (Battle-Tested criteria)

**Next:** Collect production usage data and verify battle-tested criteria

---

**Last Updated:** 2025-12-11  
**Quick Path Guide:** See `251211_BATTLE_TESTED_QUICK_PATH.md` for practical 7-day plan

