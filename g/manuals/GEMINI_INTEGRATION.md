# Gemini Integration Manual (Phase 1–5)

**State:** IMPLEMENTED (Phase 1, 4, 5) / PLANNED (Phase 2–3 routing)

## 1. Overview

- Purpose: ใช้ Gemini เป็น heavy-compute offloader + bulk ops
- Scope: ไม่แทน CLC/Codex แต่ช่วยแบ่งโหลด
- Principle: Conservative Additive Integration (ไม่รื้อของเดิม)

## 2. Architecture

- Layer 4.5: Gemini (ตาม Context Protocol v3.x)
- Components:
  - `g/connectors/gemini_connector.py`
  - `bridge/handlers/gemini_handler.py`
  - `bridge/memory/gemini_memory_loader.py`
  - `g/tools/quota_tracker.py`
  - `g/apps/dashboard/data/quota_metrics.json`

Diagram (text): `GG → Liam → WO → GEMINI handler → result → Andy/CLS`

## 3. Routing Rules (Conceptual)

- When to use Gemini:
  - งาน heavy compute, bulk test generation, large refactor proposal
  - งานที่ไม่แตะ locked zone (`/CLC`, core protocols)
- Not for:
  - แก้ governance / AI:OP-001
  - Patch ที่ต้อง SIP โดย CLC/LPE

| Task type              | Preferred | Fallback         |
|------------------------|-----------|------------------|
| Protocol / locked zone | CLC/LPE   | GC planning only |
| Bulk tests / refactor  | Gemini    | Codex assist     |
| Local dev (Cursor)     | Codex     | Gemini (spec)    |

## 4. Work Order Flow

1. GG / Liam ออก WO → `bridge/inbox/GEMINI/WO_*.yaml`  
2. `gemini_handler.py` อ่าน WO → call API → เขียนผลใน `bridge/outbox/GEMINI/WO_*_result.yaml`  
3. Andy/CLS review → เลือกว่าจะให้ใคร apply (CLC/LPE/Codex)  
4. MLS จับ event ผ่าน mls_capture / CI (ถ้ามี)

> หมายเหตุ: ถ้า Phase 3 routing ยังไม่เปิดจริง ให้ถือว่า flow นี้เป็น **PLANNED** แต่ design-ready

## 5. Quota Tracking

- Config: `g/config/quota_config.yaml`
- Tracker: `g/tools/quota_tracker.py`
- Output: `g/apps/dashboard/data/quota_metrics.json`
- UI: “Token Distribution” widget ใน Dashboard (แสดง GPT / Gemini / Codex / CLC)

## 6. Safety & Governance

- Gemini **ห้าม** write SOT โดยตรง  
- ทุก output ของ Gemini:
  - ต้องเข้า WO / review path ก่อน
  - ต้องผ่าน Andy/CLS/CLC/LPE เลือก apply method  
- AI:OP-001 ยังคุมทุก patch ผ่าน SIP

## 7. Usage Examples

- Example 1: ขอ Gemini สร้าง test suite จาก dashboard code
- Example 2: ขอ Gemini ช่วยออกแบบ refactor plan แล้วให้ Codex/CLC implement
- Example 3: ใช้ Gemini ทำ bulk analysis (เช่น scan MLS, generate summary pack)

## 8. Deployment Checklist (Phase 5)

- [x] Connector/handler/memory loader in place (Phase 1)
- [x] Quota tracker + widget live (Phase 4)
- [ ] WO routing enabled (Phase 3)
- [ ] Full CI coverage for Gemini tasks
- [x] Manual (this file) completed

## 9. Future Work

- Implement full WO routing (Phase 3)
- เพิ่ม quota alert → Telegram/Discord
- Deep CI checks for Gemini outputs
