# 251128 — CLS Cursor Wrapper Specification (V1)

**Feature:** `cls_cursor_wrapper`  
**Date:** 2025-11-28  
**Status:** Draft → Ready for Implementation  
**Owner:** LAC / CLS  
**Related Contracts:** `g/ai_contracts/lac_contract_v2.yaml`  
**Related Plan:** `g/reports/feature-dev/cls_cursor_wrapper/251128_cls_cursor_wrapper_PLAN.md` (to be created if needed)

---

## 1. Purpose & Scope

### 1.1 Goal

เชื่อม Cursor (CLS ใน Cursor / Local AI) เข้ากับ LAC/CLS V4 ผ่าน wrapper แบบ optional tool:

- ให้ Cursor ส่งงาน **ซับซ้อน / multi-file / ต้อง pipeline / ต้อง audit** ไปให้ LAC/CLS ทำ
- โดยที่:
  - ไม่แตะ core LAC
  - ไม่บังคับ ทุกงานต้องผ่าน CLS
  - ใช้เป็น "โหมดเสริม" สำหรับงานใหญ่เท่านั้น

### 1.2 Non-Goals

- ไม่แทนที่ Cursor AI ปกติ
- ไม่ทำให้ทุกการแก้ไฟล์ต้องผ่าน WO
- ไม่เพิ่ม paid lane หรือ model ใหม่ (ใช้ LAC engine ที่มีอยู่แล้ว)

---

## 2. High-Level Architecture

### 2.1 Flow Overview

```
Cursor Chat (CLS / AI)
   |
   |  /cls-apply "..."
   v
.cursor/commands/cls-apply.md
   |
   |  (calls local script)
   v
tools/cursor_cls_wrapper.py
   |
   |  1. Read current file / selection / command text
   |  2. Build Work Order JSON
   |  3. Drop to g/bridge/inbox/CLC/
   |  4. Poll g/bridge/outbox/CLC/ for result
   |  5. Print result (diff / summary) back to Cursor
   v
CLS / LAC Engine
   |
   |  DEV → QA → DOCS → DIRECT_MERGE (if applicable)
   v
g/bridge/outbox/CLC/RESULT_*.json
```

### 2.2 Files & Directories

**Cursor side:**
- `.cursor/commands/cls-apply.md` → นิยาม command `/cls-apply` และอธิบายการใช้งาน

**Wrapper side:**
- `tools/cursor_cls_wrapper.py` → main entrypoint (run via CLI จาก Cursor)
- `tools/cursor_cls_bridge/__init__.py`
- `tools/cursor_cls_bridge/wo_builder.py`
- `tools/cursor_cls_bridge/io_utils.py`
- `tools/cursor_cls_bridge/config.py`

**LAC/CLS side (existing):**
- `g/bridge/inbox/CLC/` (WO in)
- `g/bridge/outbox/CLC/` (WO result)
- `schemas/work_order.schema.json`
- Shared policy: `shared/policy.py`
- AI Manager / CLS V4 stack (ไม่ต้องแก้อะไร)

---

## 3. Command & Wrapper Interface

### 3.1 Cursor Command: /cls-apply

**File:** `.cursor/commands/cls-apply.md`

```markdown
---
description: Apply changes via CLS V4 (LAC local-first engine)
---

Use this command when you want the 02luka LAC/CLS engine
to handle complex or multi-file work:

- Large refactors
- Multi-file patches
- Pipeline operations (DEV→QA→DOCS→MERGE)
- Work that should be logged and audited in 02luka

Usage examples:

/cls-apply "Refactor this module into smaller functions"
/cls-apply "Apply a safe patch across all files in this folder"
/cls-apply "Run DEV→QA→DOCS→DIRECT_MERGE for this feature"

The command will:

1. Capture the current file, selection, and your description.
2. Create a Work Order for CLS.
3. Send it to the 02luka LAC engine.
4. Return a summary/diff once processing completes.
```

จริง ๆ ส่วน behaviour ลึก ๆ ถูก implement ที่ `cursor_cls_wrapper.py` ด้านล่าง

---

### 3.2 CLI Interface (Wrapper)

**File:** `tools/cursor_cls_wrapper.py`

**Target interface:**

```bash
python tools/cursor_cls_wrapper.py \
  --base-dir /Users/icmini/LocalProjects/02luka_local_g \
  --file-path <current_file> \
  --selection-start <line> \
  --selection-end <line> \
  --command-text "<user_prompt_text>" \
  [--dry-run] \
  [--timeout-seconds 60]
```

- `--base-dir`: ถ้าไม่ส่ง → ใช้จาก `LAC_BASE_DIR` env, default: project root (02luka_local_g)
- `--file-path`: path ของไฟล์ปัจจุบัน (relative จาก root ที่ Cursor ส่งมา)
- `--selection-start / --selection-end`: line-based (1-indexed) หรือ None ถ้าไม่มี selection
- `--command-text`: ข้อความตามหลัง `/cls-apply` จาก user
- `--dry-run`: ถ้าเปิด → สร้าง WO แล้ว log แต่ไม่รอ result
- `--timeout-seconds`: เวลารอ result จาก outbox ก่อน timeout

**Wrapper stdout contract (กลับไปหา Cursor):**

- **On success (have result JSON):**
  - พิมพ์ summary human-readable (พร้อม bullet)
  - แถม code/diff snippet (ถ้า result มี)
- **On timeout:**
  - พิมพ์สั้น ๆ: `CLS processing is still running. WO-ID: <id>. You can check later in g/bridge/outbox/CLC/.`
- **On failure (I/O, config, etc.):**
  - พิมพ์ error message ชัดเจน + hint

---

## 4. Work Order Format (Wrapper → CLS)

Wrapper จะ build WO ให้สอดคล้องกับ `schemas/work_order.schema.json` (ที่เพิ่ง update แล้ว):

### 4.1 Minimum Fields

```json
{
  "wo_id": "WO-CLS-20251128-001",
  "objective": "Refactor module X for better readability",
  "routing_hint": "dev_oss",
  "priority": "P1",
  "self_apply": true,
  "complexity": "simple",
  "requires_paid_lane": false,
  "source": "cursor_cls_wrapper",
  "context": {
    "file_path": "g/src/.../foo.py",
    "selection": {
      "start_line": 15,
      "end_line": 63
    },
    "cursor_command": "/cls-apply",
    "cursor_prompt": "Refactor this function…",
    "project_root": "/Users/icmini/LocalProjects/02luka_local_g"
  }
}
```

### 4.2 WO ID Convention

- Prefix: `WO-CLS-`
- Example: `WO-CLS-20251128-001`

Wrapper รับผิดชอบการสร้าง WO ID ที่ unique (เช่น timestamp + random suffix)

### 4.3 Routing Hint Logic

Initially simple (ให้ LAC จัดการ dev lane):

- Default: `routing_hint = "oss"`
- ถ้าผู้ใช้เขียนคำว่า:
  - `"gmx"` / `"gmxcli"` → `routing_hint = "gmxcli"`
  - `"gptdeep"` / `"deep"` → `routing_hint = "gptdeep"` (แต่ LAC guard paid lane อยู่แล้ว)

---

## 5. Data Flow & Lifecycle

### 5.1 Inbound (Cursor → Wrapper)

1. User พิมพ์: `/cls-apply "Refactor this file to smaller functions"`
2. Cursor ส่ง:
   - current file path
   - selection range (ถ้ามี)
   - command text
3. Cursor เรียก: `python tools/cursor_cls_wrapper.py ...`

### 5.2 Wrapper → LAC/CLS

1. Normalize base_dir (02luka_local_g root)
2. Validate:
   - base_dir exists
   - `g/bridge/inbox/CLC/` exists
3. สร้าง WO JSON
4. เขียนไฟล์ที่: `g/bridge/inbox/CLC/WO-CLS-YYYYMMDD-HHMMSS-XXXX.json`

### 5.3 CLS → Outbox

- CLS pipeline (ที่มีอยู่แล้ว) อ่าน WO → Dev/QA/Docs → DIRECT_MERGE
- เมื่อเสร็จ: เขียนผลลัพธ์ที่: `g/bridge/outbox/CLC/WO-CLS-...-RESULT.json`

### 5.4 Wrapper Polling (Optional)

ถ้า **ไม่** `--dry-run`:

1. Wrapper loop:
   - look for matching `...-RESULT.json` (ตาม wo_id)
   - poll interval: 1–2s
   - timeout configurable
2. เมื่อเจอ:
   - parse JSON
   - แปลงเป็น message สั้น ๆ (summary, status, files_touched)
   - print ไป stdout → Cursor แสดงให้ user

---

## 6. Operational Modes

### 6.1 Forced CLS Mode (explicit command)

- `/cls-apply` = บังคับส่งผ่าน CLS
- ใช้ในเคส:
  - multi-file
  - งาน pipeline
  - ต้องการ log / audit
  - ต้องให้ agent dev_oss/dev_gmxcli ทำงานเต็ม pipeline

### 6.2 Future: Auto-routing (ไม่ต้องทำในรอบแรก)

Option ในอนาคต (แต่ **ไม่** อยู่ใน scope spec v1):

- Auto call wrapper ถ้า:
  - diff เกิน N บรรทัด
  - จำนวนไฟล์ที่แตะ > 2
  - user ระบุ flag พิเศษ

**ตอนนี้:** ไม่ทำ — ทุกอย่าง explicit ผ่าน `/cls-apply` เท่านั้น

---

## 7. Config & Environment

### 7.1 Base Directory

Priority order:

1. CLI `--base-dir`
2. Env `LAC_BASE_DIR`
3. Default: current working directory (ต้องมี 02luka_local_g structure)

### 7.2 Timeouts & Polling

- Default timeout: 60s
- Poll interval: 1s
- Config ผ่าน env:
  - `CLS_CURSOR_TIMEOUT_SECONDS`
  - `CLS_CURSOR_POLL_INTERVAL_SECONDS`

### 7.3 Logging

Wrapper เองควร log แบบเบา ๆ:

- Path: `g/logs/cls_cursor_wrapper.log` (ถ้ามีสิทธิ์)
- หรือ fallback: stdout debug (ถ้ารันจาก Cursor ที่ไม่อยากให้ log file)

---

## 8. Error Handling & UX

### 8.1 Categories

1. **Config error**
   - Missing base-dir
   - No bridge directories
2. **WO write error**
   - Permission denied
   - Disk full
3. **Timeout**
   - Outbox ยังไม่ตอบในเวลาที่กำหนด
4. **Result error**
   - RESULT JSON invalid
   - status != success

### 8.2 Messages (to user via Cursor)

- **Config error:** `CLS wrapper: configuration error: <detail>. Please verify base-dir and bridge paths.`
- **Timeout:** `CLS wrapper: processing is still running (WO-ID: <id>). Check g/bridge/outbox/CLC/ later for results.`
- **Result error:** `CLS wrapper: CLS reported failure for WO-ID <id>. Reason: <reason>.`

ทั้งหมดนี้ควรสั้น ชัดเจน ไม่ spam

---

## 9. Security & Writer Policy Alignment

- Wrapper **ไม่แก้ไฟล์เอง** → แค่สร้าง WO JSON แล้วส่งให้ CLS/LAC ซึ่งมี `shared/policy.py` บังคับ policy อยู่แล้ว
- **Path:**
  - ใช้ pathlib + normalization
  - ไม่เขียนไฟล์นอก tree ของ base_dir
- **WO:**
  - ผ่าน schema `schemas/work_order.schema.json` (มี `additionalProperties:false`)
- **Paid lane:**
  - Wrapper ไม่ override route ไป paid lane เอง
  - LAC guard ผ่าน `paid_lanes.yaml` + triple guard

---

## 10. Test Plan

### 10.1 Unit Tests (wrapper / bridge)

**Files:**
- `tests/tools/test_cursor_cls_bridge.py` หรือคล้ายกัน ตาม convention ปัจจุบันของโปรเจกต์

**Cases:**

1. `test_build_wo_basic()`
   - ให้ command-text, file-path, selection
   - ตรวจว่า WO JSON แปลงตรง schema
2. `test_drop_wo_to_inbox()`
   - ใช้ tmp dir จำลอง `g/bridge/inbox/CLC/`
   - Verify ว่าไฟล์ถูกเขียน, ชื่อถูกต้อง
3. `test_timeout_waiting_for_result()`
   - ไม่มี RESULT → ส่ง timeout message
4. `test_read_success_result()`
   - สร้าง RESULT JSON ปลอม → verify stdout/summary

### 10.2 Integration (with real CLS, optional)

- Create small WO ผ่าน wrapper:
  - Objective: "Add comment to dummy file"
  - ให้ CLS pipeline run จริง
- Verify:
  - RESULT JSON ถูกเขียน
  - Policy guard ไม่ block
  - DIRECT_MERGE flow ทำงาน

---

## 11. Non-Breaking Constraints

- ไม่แก้ core LAC / AI Manager / shared.policy
- ไม่แก้ paid lane behaviour
- Only adds:
  - new `tools/` script + bridge helpers
  - new `.cursor/commands/` file
  - new tests

---

## 12. Success Criteria

ถือว่า CLS Cursor Wrapper v1 เสร็จสมบูรณ์ เมื่อ:

1. `/cls-apply "…"` ใช้งานได้จริงจาก Cursor
2. เห็น WO ถูกสร้างใน `g/bridge/inbox/CLC/`
3. CLS process แล้วมี RESULT JSON ใน `g/bridge/outbox/CLC/`
4. Wrapper แสดงผลลัพธ์กลับมาบน Cursor (summary + status)
5. ไม่มีการแก้ core LAC logic / contract
6. ไม่มี paid lane call ที่ไม่ผ่าน guard

---

**Document Status:** ✅ READY FOR IMPLEMENTATION

