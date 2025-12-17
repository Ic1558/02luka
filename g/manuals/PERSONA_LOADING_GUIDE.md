# คู่มือการโหลด Persona (Persona Loading Guide)

**เวอร์ชัน:** 3.0
**อัปเดต:** 2025-12-17
**สำหรับ:** Persona v3 + v5 Loader

---

## 📋 สารบัญ

1. [ภาพรวม](#ภาพรวม)
2. [คำสั่ง Load Persona](#คำสั่ง-load-persona)
3. [การใช้งานแต่ละ Agent](#การใช้งานแต่ละ-agent)
4. [การทดสอบและตรวจสอบ](#การทดสอบและตรวจสอบ)
5. [Troubleshooting](#troubleshooting)

---

## ภาพรวม

### Persona คืออะไร?

Persona คือ "บุคลิกภาพและข้อกำหนดการทำงาน" ของแต่ละ AI Agent ในระบบ 02luka ที่ประกอบด้วย:
- Identity & Mission (บทบาทและภารกิจ)
- Two Worlds Model (CLI vs Background)
- Zone Permissions (สิทธิ์การเข้าถึง Locked/Open zones)
- Work Order Rules (กฎการใช้ WO)
- Governance Integration (การบูรณาการกับระบบ governance)

### Persona Versions

- **v2 (Legacy):** Persona รุ่นเก่า (เก็บใน `personas/_archive/`)
- **v3 (Current):** Persona รุ่นปัจจุบัน (ใช้ Two Worlds Model)
- **v5 Loader:** Loader รุ่นล่าสุดที่รองรับทั้ง v3 และ v5

### Supported Agents

1. **CLS** - System Orchestrator / Router
2. **GG** - Co-Orchestrator
3. **GM** - Co-Orchestrator with GG
4. **Liam** - Explorer & Planner
5. **Mary** - Traffic / Safety Router
6. **CLC** - Locked-zone Executor
7. **GMX** - CLI Worker
8. **Codex** - IDE Assistant
9. **Gemini** - Operational Worker
10. **LAC** - Auto-Coder

---

## คำสั่ง Load Persona

### Loader Scripts

- **v3 Loader:** `~/02luka/tools/load_persona_v3.zsh`
- **v5 Loader:** `~/02luka/tools/load_persona_v5.zsh` (recommended)

### รูปแบบคำสั่ง

```bash
~/02luka/tools/load_persona_v5.zsh <agent> <target>
~/02luka/tools/load_persona_v3.zsh <agent> <target>
```

**Parameters:**
- `<agent>`: ชื่อ agent (cls, gg, gm, liam, mary, clc, gmx, codex, gemini, lac)
- `<target>`: เป้าหมาย (cursor, ag, both, sync)

**Targets:**
- `cursor` - โหลดไปที่ Cursor IDE
- `ag` - โหลดไปที่ Antigravity IDE
- `both` - โหลดทั้งสอง IDE
- `sync` - ซิงค์ไฟล์ (สำหรับ v5)

---

## การใช้งานแต่ละ Agent

### 1. CLS on Cursor

```bash
~/02luka/tools/load_persona_v3.zsh cls cursor
```

**สิ่งที่เกิดขึ้น:**
- อัปเดต `~/02luka/CLS.md` ด้วย `CLS_PERSONA_v3.md`
- ใช้ atomic operation (`/tmp` + `mv`) เพื่อความปลอดภัย
- Cursor จะอ่านไฟล์ `CLS.md` โดยอัตโนมัติ

**ผลลัพธ์:**
```
✅ CLS persona loaded to Cursor
✅ ~/02luka/CLS.md updated
```

---

### 2. CLS on Antigravity

```bash
~/02luka/tools/load_persona_v3.zsh cls ag
```

**สิ่งที่เกิดขึ้น:**
- หา brain folder ล่าสุดใน `~/02luka_ws/dev/.antigravity/brain/`
- สร้าง `00_ACTIVE_PERSONA_CLS.md` ใน brain folder
- สร้าง `01_CONTEXT_SUMMARY.md` (governance rules)
- อัปเดต `task.md` ให้ reference ทั้งสองไฟล์

**ผลลัพธ์:**
```
✅ CLS persona loaded to Antigravity
✅ Brain: ~/02luka_ws/dev/.antigravity/brain/2025-12-17T23:45:00
✅ Created: 00_ACTIVE_PERSONA_CLS.md
✅ Created: 01_CONTEXT_SUMMARY.md
✅ Updated: task.md
```

---

### 3. CLS Sync (v5 Loader)

```bash
~/02luka/tools/load_persona_v5.zsh cls sync
```

**สิ่งที่เกิดขึ้น:**
- ซิงค์ไฟล์ `CLS.md` จาก repo ไปยัง Cursor
- ตรวจสอบและอัปเดตไฟล์หากมีการเปลี่ยนแปลง
- ใช้สำหรับการซิงค์หลังจากแก้ไข persona

**ผลลัพธ์:**
```
✅ CLS persona synced
✅ CLS.md up to date
```

---

### 4. Liam on Cursor

```bash
~/02luka/tools/load_persona_v3.zsh liam cursor
```

**สิ่งที่เกิดขึ้น:**
- Skip Cursor injection (เพราะ Cursor รองรับเฉพาะ CLS)

**ผลลัพธ์:**
```
⚠️ Skipping Cursor injection: persona 'liam' is not CLS
ℹ️ Cursor only supports CLS persona
```

**เหตุผล:** Cursor มีการ integrate กับ CLS โดยเฉพาะ (อ่านจาก `CLS.md`)

---

### 5. Liam on Antigravity

```bash
~/02luka/tools/load_persona_v3.zsh liam ag
```

**สิ่งที่เกิดขึ้น:**
- หา brain folder ล่าสุด
- สร้าง `00_ACTIVE_PERSONA_LIAM.md` ใน brain folder
- สร้าง `01_CONTEXT_SUMMARY.md` (governance rules)
- อัปเดต `task.md` ให้ reference ทั้งสองไฟล์

**ผลลัพธ์:**
```
✅ Liam persona loaded to Antigravity
✅ Brain: ~/02luka_ws/dev/.antigravity/brain/2025-12-17T23:50:00
✅ Created: 00_ACTIVE_PERSONA_LIAM.md
✅ Created: 01_CONTEXT_SUMMARY.md
✅ Updated: task.md
```

---

### 6. Liam on Both (Optional)

```bash
~/02luka/tools/load_persona_v3.zsh liam both
```

**สิ่งที่เกิดขึ้น:**
- Skip Cursor (เพราะไม่ใช่ CLS)
- Inject ไปที่ Antigravity เท่านั้น

**ผลลัพธ์:**
```
⚠️ Skipping Cursor injection: persona 'liam' is not CLS
✅ Liam persona loaded to Antigravity
```

**หมายเหตุ:** สำหรับ agents อื่นๆ ที่ไม่ใช่ CLS, `both` จะมีผลเหมือน `ag`

---

## ตัวอย่างการใช้งานทั้งหมด

### CLS Examples

```bash
# Load CLS to Cursor
~/02luka/tools/load_persona_v3.zsh cls cursor

# Load CLS to Antigravity
~/02luka/tools/load_persona_v3.zsh cls ag

# Load CLS to both (v3)
~/02luka/tools/load_persona_v3.zsh cls both

# Sync CLS (v5)
~/02luka/tools/load_persona_v5.zsh cls sync
```

### GG Examples

```bash
# Load GG to Antigravity
~/02luka/tools/load_persona_v3.zsh gg ag

# Load GG to both (skips Cursor)
~/02luka/tools/load_persona_v3.zsh gg both
```

### GM Examples

```bash
# Load GM to Antigravity
~/02luka/tools/load_persona_v3.zsh gm ag
```

### Liam Examples

```bash
# Load Liam to Antigravity
~/02luka/tools/load_persona_v3.zsh liam ag

# Load Liam to both (skips Cursor)
~/02luka/tools/load_persona_v3.zsh liam both
```

### Mary Examples

```bash
# Load Mary to Antigravity
~/02luka/tools/load_persona_v3.zsh mary ag
```

### CLC Examples

```bash
# Load CLC to Antigravity
~/02luka/tools/load_persona_v3.zsh clc ag
```

### GMX Examples

```bash
# Load GMX to Antigravity
~/02luka/tools/load_persona_v3.zsh gmx ag
```

### Codex Examples

```bash
# Load Codex to Antigravity
~/02luka/tools/load_persona_v3.zsh codex ag
```

### Gemini Examples

```bash
# Load Gemini to Antigravity
~/02luka/tools/load_persona_v3.zsh gemini ag
```

### LAC Examples

```bash
# Load LAC to Antigravity
~/02luka/tools/load_persona_v3.zsh lac ag
```

---

## การทดสอบและตรวจสอบ

### 1. ตรวจสอบ CLS.md (Cursor)

```bash
cat ~/02luka/CLS.md | head -20
```

**ต้องเห็น:**
```markdown
# PERSONA: CLS – v3

**Role:** System Orchestrator / Router
**Context:** Cursor IDE
**World:** CLI / Interactive
```

### 2. ตรวจสอบ Antigravity Brain

```bash
# หา brain ล่าสุด
ls -lt ~/02luka_ws/dev/.antigravity/brain/ | head -5

# ดูไฟล์ persona
cat ~/02luka_ws/dev/.antigravity/brain/*/00_ACTIVE_PERSONA_*.md | head -20

# ดู context summary
cat ~/02luka_ws/dev/.antigravity/brain/*/01_CONTEXT_SUMMARY.md | head -20
```

### 3. ตรวจสอบ task.md

```bash
# ดู task.md ล่าสุด
cat ~/02luka_ws/dev/.antigravity/brain/*/task.md
```

**ต้องมี:**
```markdown
# Read these files first:
- 00_ACTIVE_PERSONA_XXX.md
- 01_CONTEXT_SUMMARY.md
```

---

## Troubleshooting

### ❌ Error: Persona file not found

**อาการ:**
```
Error: personas/CLS_PERSONA_v3.md not found
```

**แก้ไข:**
```bash
# ตรวจสอบว่าไฟล์ persona มีอยู่
ls ~/02luka/personas/

# ควรเห็น:
# CLS_PERSONA_v3.md
# GG_PERSONA_v3.md
# ... (other personas)
```

**สาเหตุ:** ไฟล์ persona v3 ยังไม่ได้สร้าง หรือถูกลบไป

---

### ❌ Error: Antigravity brain not found

**อาการ:**
```
Error: Antigravity brain folder not found
```

**แก้ไข:**
```bash
# ตรวจสอบว่า Antigravity ติดตั้งแล้ว
ls -la ~/02luka_ws/dev/.antigravity/

# สร้าง brain folder manually
mkdir -p ~/02luka_ws/dev/.antigravity/brain/
```

**สาเหตุ:** Antigravity ยังไม่ได้ติดตั้ง หรือ brain folder ถูกลบ

---

### ⚠️ Warning: Cursor injection skipped

**อาการ:**
```
⚠️ Skipping Cursor injection: persona 'liam' is not CLS
```

**คำอธิบาย:** นี่ไม่ใช่ error แต่เป็นพฤติกรรมปกติ

**เหตุผล:** Cursor รองรับเฉพาะ CLS persona เท่านั้น

**การใช้งาน:** ใช้ `ag` หรือ `both` สำหรับ agents อื่นๆ

---

### ❌ Error: CLS.md locked or in use

**อาการ:**
```
Error: Cannot write to ~/02luka/CLS.md (file locked)
```

**แก้ไข:**
```bash
# ปิด Cursor ก่อน
# แล้วรัน load_persona อีกครั้ง
~/02luka/tools/load_persona_v3.zsh cls cursor
```

**สาเหตุ:** Cursor กำลังอ่านไฟล์ `CLS.md` อยู่

---

### ❌ Error: Persona v3 file is empty

**อาการ:**
```
Error: personas/CLS_PERSONA_v3.md is empty or invalid
```

**แก้ไข:**
```bash
# ตรวจสอบเนื้อหาไฟล์
cat ~/02luka/personas/CLS_PERSONA_v3.md

# ถ้าไฟล์เสีย restore จาก git
cd ~/02luka
git checkout HEAD -- personas/CLS_PERSONA_v3.md
```

**สาเหตุ:** ไฟล์ persona เสียหาย หรือถูกแก้ไขผิดพลาด

---

## Best Practices

### 1. โหลด Persona ก่อนเริ่มงาน

**แนะนำ:**
```bash
# ก่อนเปิด Cursor
~/02luka/tools/load_persona_v5.zsh cls sync

# ก่อนเปิด Antigravity กับ Liam
~/02luka/tools/load_persona_v3.zsh liam ag
```

### 2. ซิงค์ Persona หลังแก้ไข

**เมื่อแก้ไข persona files:**
```bash
# แก้ไขไฟล์
vim ~/02luka/personas/CLS_PERSONA_v3.md

# ซิงค์ไปที่ Cursor
~/02luka/tools/load_persona_v5.zsh cls sync

# ซิงค์ไปที่ Antigravity
~/02luka/tools/load_persona_v3.zsh cls ag
```

### 3. ตรวจสอบ Version

**ตรวจสอบ persona version:**
```bash
grep "^# PERSONA:" ~/02luka/CLS.md
# ควรเห็น: # PERSONA: CLS – v3
```

### 4. Backup ก่อนแก้ไข

**สำรองไฟล์ก่อนแก้:**
```bash
cp ~/02luka/personas/CLS_PERSONA_v3.md \
   ~/02luka/personas/CLS_PERSONA_v3.md.bak
```

---

## Advanced Usage

### การสร้าง Custom Persona

1. สร้างไฟล์ persona ใหม่:
```bash
vim ~/02luka/personas/CUSTOM_PERSONA_v3.md
```

2. ใช้ template จาก CLS_PERSONA_v3.md

3. แก้ไข loader script ให้รองรับ custom persona:
```bash
vim ~/02luka/tools/load_persona_v3.zsh
```

### การ Debug Persona Loading

**เปิด debug mode:**
```bash
export DEBUG=1
~/02luka/tools/load_persona_v3.zsh cls cursor
```

**ดู log:**
```bash
tail -f /tmp/persona_loader.log
```

---

## References

- **Persona v3 Plan:** `g/reports/feature-dev/persona_v3_governance_rollout_PLAN.md`
- **Two Worlds Model:** `g/docs/HOWTO_TWO_WORLDS.md`
- **Governance:** `g/docs/GOVERNANCE_CLI_VS_BACKGROUND_v1.md`
- **Loader Script v3:** `tools/load_persona_v3.zsh`
- **Loader Script v5:** `tools/load_persona_v5.zsh`

---

## Version History

- **v3.0 (2025-12-17):** คู่มือครอบคลุม, รองรับ v3 + v5 loader
- **v2.0 (2025-12-09):** Persona v3 deployment
- **v1.0 (2025-11-XX):** Persona v2 (legacy)

---

**อัปเดตล่าสุด:** 2025-12-17
**ผู้ดูแล:** CLC (Claude Code)
**สถานะ:** Production Ready ✅
