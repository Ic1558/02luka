# 02LUKA Documentation Index (ภาษาไทย)

**เวอร์ชัน:** 2.0 (Provider-Agnostic Architecture)
**อัปเดต:** 2025-11-04
**สถานะ:** ✅ PRODUCTION READY

---

## 📚 คู่มือทั้งหมด

### 🚀 เริ่มต้นใช้งาน

#### 1. [QUICK_START_TH.md](./QUICK_START_TH.md)
**สำหรับ:** ผู้ใช้ใหม่ ต้องการเริ่มใช้งานเร็ว
**ขนาด:** ~3 หน้า (Quick Reference)

**เนื้อหา:**
- เริ่มต้นใช้งาน 3 คำสั่ง
- คำสั่งที่ใช้บ่อย
- API Keys setup
- Config files
- Cursor IDE setup (ย่อ)
- Troubleshooting

**เมื่อไหร่ควรอ่าน:**
- ✅ ครั้งแรกที่ใช้ระบบ
- ✅ ต้องการ reference ด่วน
- ✅ ต้องการ cheat sheet

```bash
# อ่านเลย
cat ~/02luka/g/manuals/QUICK_START_TH.md
```

---

### 📘 คู่มือฉบับเต็ม

#### 2. [02luka_system_capabilities_th.md](./02luka_system_capabilities_th.md)
**สำหรับ:** เข้าใจระบบลึก, ใช้งานเต็มศักยภาพ
**ขนาด:** ~15 หน้า (Comprehensive)

**เนื้อหา:**
- ระบบมีความสามารถอะไรบ้าง (6 หมวดหลัก)
- ระบบทำงานอย่างไร (Architecture)
- รองรับเรื่องใดบ้าง
- การตั้งค่า Cursor IDE (ทีละขั้นตอน)
- FAQ 10 ข้อ

**หัวข้อหลัก:**
1. Multi-Provider LLM System
2. Resource Management
3. Automated Backups
4. GitHub Integration
5. Telemetry & Cost Tracking
6. System Cleanup

**เมื่อไหร่ควรอ่าน:**
- ✅ หลังจากผ่าน Quick Start แล้ว
- ✅ ต้องการเข้าใจ architecture
- ✅ ต้องการตั้งค่า Cursor อย่างละเอียด
- ✅ ต้องการรู้ว่ารองรับอะไรบ้าง

```bash
# อ่านด้วย less (scroll ได้)
less ~/02luka/g/manuals/02luka_system_capabilities_th.md

# หรือเปิดใน editor
open ~/02luka/g/manuals/02luka_system_capabilities_th.md
```

---

### 🔧 Advanced Topics

#### 3. [local_luka_cli_and_repo_sync_th.md](./local_luka_cli_and_repo_sync_th.md)
**สำหรับ:** ใช้ Luka CLI, ทำงานกับ GitHub repos
**ขนาด:** ~12 หน้า (Advanced Guide)

**เนื้อหา:**
- Local Luka CLI - การใช้งานละเอียด
- กลไกการ Sync Repo (bidirectional)
- Pull Request workflow
- SOT Structure ล่าสุด
- สิ่งที่เปลี่ยนไปจากเดิม (v1.0 vs v2.0)
- Workflows แนะนำ

**หัวข้อหลัก:**
1. Luka CLI (offline testing)
2. Repo Sync Scripts (--from-repo, --to-repo)
3. PR Workflow (GitHub → Runtime)
4. Before vs After comparison
5. Recommended workflows

**เมื่อไหร่ควรอ่าน:**
- ✅ ต้องการใช้ Luka ทดสอบ
- ✅ ต้องการ sync code กับ GitHub
- ✅ ต้องการทำ PR
- ✅ อยากเข้าใจว่าเปลี่ยนแปลงอะไรจาก v1.0

```bash
# อ่านส่วนที่สนใจ
less +/Local\ Luka ~/02luka/g/manuals/local_luka_cli_and_repo_sync_th.md
```

---

## 📖 เอกสารอื่นๆ (English)

### Master Documents

#### [~/02luka/02luka.md](~/../../02luka.md)
**Master SOT Document** - Single source of truth
- System architecture
- Environment configuration
- Storage & capacity
- Common operations
- Recovery history
- Troubleshooting

```bash
cat ~/02luka/02luka.md
```

---

#### [~/DEPLOYMENT_READY.md](~/../../DEPLOYMENT_READY.md)
**Deployment Guide** - How to deploy the system
- What was created
- Deployment phases
- Quick start (3 commands)
- Verification checklist
- Troubleshooting

```bash
cat ~/DEPLOYMENT_READY.md
```

---

#### [~/02luka/PRAGMATIC_SECURITY_PILOT.md](~/../../PRAGMATIC_SECURITY_PILOT.md)
**Security for Pilot Phase**
- Pragmatic approach (not paranoid)
- What to do about exposed tokens
- Options for repos authentication

```bash
cat ~/02luka/PRAGMATIC_SECURITY_PILOT.md
```

---

#### [~/02luka/HOW_TO_ROTATE_PAT_SAFELY.md](~/../../HOW_TO_ROTATE_PAT_SAFELY.md)
**PAT Rotation Guide**
- Why rotation matters
- How to rotate safely
- Never expose new tokens to CLC

```bash
cat ~/02luka/HOW_TO_ROTATE_PAT_SAFELY.md
```

---

## 🗺️ เส้นทางการเรียนรู้แนะนำ

### สำหรับผู้เริ่มต้น (Beginner)

```
1. QUICK_START_TH.md
   ↓
2. ลองใช้งานจริง (3 คำสั่ง)
   ↓
3. 02luka_system_capabilities_th.md (อ่านบางส่วน)
   ↓
4. ตั้งค่า Cursor IDE
   ↓
5. ทดสอบ Luka provider
```

**เวลา:** ~30 นาที
**ได้อะไร:** ใช้งานพื้นฐานได้

---

### สำหรับผู้พัฒนา (Developer)

```
1. QUICK_START_TH.md (ทบทวน)
   ↓
2. 02luka_system_capabilities_th.md (อ่านครบ)
   ↓
3. local_luka_cli_and_repo_sync_th.md
   ↓
4. Setup GitHub repos
   ↓
5. ทดสอบ sync workflow
   ↓
6. พัฒนา feature ใหม่
```

**เวลา:** ~2 ชั่วโมง
**ได้อะไร:** ใช้งานเต็มศักยภาพ, พัฒนาได้

---

### สำหรับ Advanced Users

```
1. อ่านทุกเอกสาร
   ↓
2. Implement provider ใหม่
   ↓
3. Customize routing.yaml
   ↓
4. Optimize costs (telemetry analysis)
   ↓
5. Contribute back (PR to repos)
```

**เวลา:** ต่อเนื่อง
**ได้อะไร:** เชี่ยวชาญระบบ, customize ได้ตามต้องการ

---

## 🔍 หาเอกสารตามหัวข้อ

### ต้องการเริ่มต้นใช้งาน
→ [QUICK_START_TH.md](./QUICK_START_TH.md)

### ต้องการเข้าใจว่าระบบทำอะไรได้บ้าง
→ [02luka_system_capabilities_th.md](./02luka_system_capabilities_th.md) (Section 1)

### ต้องการเข้าใจว่าระบบทำงานอย่างไร
→ [02luka_system_capabilities_th.md](./02luka_system_capabilities_th.md) (Section 2)

### ต้องการตั้งค่า Cursor IDE
→ [02luka_system_capabilities_th.md](./02luka_system_capabilities_th.md) (Section 4)
→ [QUICK_START_TH.md](./QUICK_START_TH.md) (Cursor section)

### ต้องการใช้ Luka ทดสอบ
→ [local_luka_cli_and_repo_sync_th.md](./local_luka_cli_and_repo_sync_th.md) (Section 1)

### ต้องการ sync code กับ GitHub
→ [local_luka_cli_and_repo_sync_th.md](./local_luka_cli_and_repo_sync_th.md) (Section 2-3)

### ต้องการทำ Pull Request
→ [local_luka_cli_and_repo_sync_th.md](./local_luka_cli_and_repo_sync_th.md) (Section 3)

### ต้องการเปลี่ยน LLM provider
→ [QUICK_START_TH.md](./QUICK_START_TH.md) (Config section)
→ [02luka_system_capabilities_th.md](./02luka_system_capabilities_th.md) (Multi-Provider section)

### ต้องการดูต้นทุนการใช้งาน
→ [QUICK_START_TH.md](./QUICK_START_TH.md) (Cost tracking section)
→ [02luka_system_capabilities_th.md](./02luka_system_capabilities_th.md) (Telemetry section)

### ต้องการแก้ปัญหา
→ [QUICK_START_TH.md](./QUICK_START_TH.md) (Troubleshooting)
→ [02luka_system_capabilities_th.md](./02luka_system_capabilities_th.md) (FAQ)
→ [~/02luka/02luka.md](~/../../02luka.md) (Troubleshooting section)

### ต้องการเข้าใจการเปลี่ยนแปลงจาก v1.0
→ [local_luka_cli_and_repo_sync_th.md](./local_luka_cli_and_repo_sync_th.md) (Section 5)

---

## 📊 สรุปเอกสารทั้งหมด

| เอกสาร | ขนาด | ระดับ | ภาษา | เนื้อหาหลัก |
|--------|------|-------|------|-------------|
| **QUICK_START_TH.md** | 3 หน้า | Beginner | TH | Quick reference, เริ่มต้นเร็ว |
| **02luka_system_capabilities_th.md** | 15 หน้า | Intermediate | TH | ความสามารถ, Architecture, Cursor setup |
| **local_luka_cli_and_repo_sync_th.md** | 12 หน้า | Advanced | TH | Luka CLI, Repo sync, Workflows |
| **02luka.md** | 9 หน้า | Reference | EN | Master SOT document |
| **DEPLOYMENT_READY.md** | 11 หน้า | Reference | EN | Deployment guide |
| **PRAGMATIC_SECURITY_PILOT.md** | 7 หน้า | Reference | EN/TH | Security for pilot |
| **HOW_TO_ROTATE_PAT_SAFELY.md** | 5 หน้า | Reference | EN/TH | PAT rotation |

---

## 💡 Tips การอ่านเอกสาร

### 1. ใช้ `less` สำหรับเอกสารยาว
```bash
less ~/02luka/g/manuals/02luka_system_capabilities_th.md

# คำสั่งใน less:
# Space - หน้าถัดไป
# b - หน้าก่อน
# /keyword - ค้นหา
# n - ค้นหาต่อ
# q - ออก
```

### 2. ค้นหาเนื้อหา
```bash
# ค้นหาคำว่า "provider"
grep -n "provider" ~/02luka/g/manuals/*.md

# ค้นหาในเอกสารเฉพาะ
grep -i "cursor" ~/02luka/g/manuals/02luka_system_capabilities_th.md
```

### 3. เปิดใน Editor
```bash
# Cursor
open -a Cursor ~/02luka/g/manuals/

# VS Code
code ~/02luka/g/manuals/

# Vim
vim ~/02luka/g/manuals/QUICK_START_TH.md
```

### 4. สร้าง PDF (ถ้าต้องการ)
```bash
# ใช้ pandoc
pandoc ~/02luka/g/manuals/QUICK_START_TH.md -o quickstart.pdf

# หรือ print to PDF จาก browser
# (เปิดไฟล์ด้วย Marked 2, Chrome, etc.)
```

---

## 🔄 การอัปเดตเอกสาร

เอกสารเหล่านี้อยู่ใน git repo:

```bash
# ดู history
cd ~/dev/02luka-repo
git log -- docs/manuals/

# Pull updates
git pull origin main
~/02luka/tools/sync_with_repos.zsh --from-repo

# เช็ค version ล่าสุด
head -5 ~/02luka/g/manuals/*.md
```

---

## 📝 การ Contribute เอกสาร

ถ้าพบข้อผิดพลาด หรืออยากเพิ่มเนื้อหา:

```bash
# 1. แก้ไขใน repo
cd ~/dev/02luka-repo
vim docs/manuals/QUICK_START_TH.md

# 2. Commit
git add docs/manuals/QUICK_START_TH.md
git commit -m "docs: fix typo in quick start"

# 3. Push
git push origin main

# 4. Deploy
~/02luka/tools/sync_with_repos.zsh --from-repo
```

หรือสร้าง PR:

```bash
# 1. Create branch
git checkout -b docs/improve-quick-start

# 2. Make changes & commit
# 3. Push branch
git push origin docs/improve-quick-start

# 4. Create PR on GitHub
```

---

## 🆘 ต้องการความช่วยเหลือ

### ถ้าอ่านเอกสารแล้วยังไม่เข้าใจ:

1. **ลองใช้จริง** - หลายอย่างเข้าใจง่ายกว่าเมื่อลองทำ
2. **ดู session reports** - มีตัวอย่างการใช้งานจริง
   ```bash
   ls ~/02luka/g/reports/sessions/
   ```
3. **ใช้ Cursor AI** - ถามเกี่ยวกับเอกสาร
   ```
   ⌘+L - Open chat
   "อธิบาย local_luka_cli_and_repo_sync_th.md ให้ฟังหน่อย"
   ```

---

## ✅ Checklist หลังอ่านเอกสาร

### Beginner Level
- [ ] อ่าน QUICK_START_TH.md จบ
- [ ] รัน health check สำเร็จ
- [ ] ทดสอบ Luka provider ได้
- [ ] ตั้งค่า Cursor IDE พื้นฐาน

### Intermediate Level
- [ ] อ่าน 02luka_system_capabilities_th.md จบ
- [ ] เข้าใจ architecture ระบบ
- [ ] ตั้งค่า Cursor IDE ครบ
- [ ] เปลี่ยน provider ใน config ได้

### Advanced Level
- [ ] อ่านทุกเอกสาร
- [ ] Setup GitHub repos สำเร็จ
- [ ] ทดสอบ sync workflow ได้
- [ ] เข้าใจ v1.0 vs v2.0 ต่างกันอย่างไร

---

**Index นี้สร้างเมื่อ:** 2025-11-04
**สำหรับ:** 02LUKA System v2.0 Documentation
**โดย:** Claude Code (CLC)

**เริ่มเลย:** [QUICK_START_TH.md](./QUICK_START_TH.md) 🚀
