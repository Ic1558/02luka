# คู่มือ Local Luka CLI และ GitHub Repo Sync

**เวอร์ชัน:** 2.0 (Post-Architecture Upgrade)
**อัปเดต:** 2025-11-04
**สำหรับ:** 02LUKA System v2.0

---

## 📋 สารบัญ

1. [Local Luka CLI - การใช้งาน](#local-luka-cli---การใช้งาน)
2. [กลไกการ Sync Repo](#กลไกการ-sync-repo)
3. [Pull Request จาก GitHub](#pull-request-จาก-github)
4. [SOT Structure ล่าสุด](#sot-structure-ล่าสุด)
5. [สิ่งที่เปลี่ยนไปจากเดิม](#สิ่งที่เปลี่ยนไปจากเดิม)
6. [Workflow ใหม่](#workflow-ใหม่)

---

## Local Luka CLI - การใช้งาน

### 🤖 Luka คืออะไร?

**Luka** = Local LLM provider ที่ทำงานออฟไลน์
- ✅ **ไม่ต้องใช้ internet**
- ✅ **ไม่มีค่าใช้จ่าย** (ไม่เรียก external API)
- ✅ **ทดสอบได้ทันที** (ไม่ต้องมี API key)
- ✅ **Format เหมือน provider อื่น** (standard output)

**จุดประสงค์:**
- ทดสอบ work order format
- ตรวจสอบว่าระบบทำงานก่อนเรียก API จริง
- Development/Testing ที่ไม่ต้องใช้ quota

---

### 🔧 การใช้งาน Luka CLI

#### 1. การใช้งานพื้นฐาน

```bash
# ตรวจสุขภาพ (ดูว่า Luka พร้อมหรือยัง)
~/02luka/tools/llm-run --health

# Output:
# Providers:
#   ✅ luka: ready
#   ✅ grok: ready
#   ...
```

---

#### 2. ส่ง Work Order แบบ Direct Call

```bash
# สร้าง work order (JSON)
cat > /tmp/test_luka.json <<'JSON'
{
  "id": "WO-LUKA-001",
  "op": "analyze",
  "inputs": {
    "text": "วิเคราะห์ข้อความนี้: ระบบ LLM ทำงานได้ดีมาก"
  },
  "constraints": {
    "timeout_s": 30
  }
}
JSON

# เรียกใช้ Luka
~/02luka/tools/llm-run --in /tmp/test_luka.json --provider luka

# ดูผลลัพธ์
cat /tmp/test_luka.json.result | jq .
```

**Output ตัวอย่าง:**
```json
{
  "id": "WO-LUKA-001",
  "provider": "luka",
  "status": "ok",
  "output": {
    "text": "Local Luka response to: วิเคราะห์ข้อความนี้...",
    "note": "Offline local processing"
  },
  "telemetry": {
    "tokens_in": 15,
    "tokens_out": 42,
    "cost_usd": 0
  }
}
```

---

#### 3. ส่ง Work Order ผ่าน Queue

```bash
# วาง work order ใน queue
cp /tmp/test_luka.json ~/02luka/bridge/inbox/LLM/

# ระบบจะ process อัตโนมัติ (ถ้ามี worker ทำงาน)
# หรือรัน manual:
for wo in ~/02luka/bridge/inbox/LLM/*.json; do
  ~/02luka/tools/llm-run --in "$wo" --provider luka
done

# ดูผลลัพธ์
ls -lh ~/02luka/bridge/inbox/LLM/*.result
```

---

#### 4. ใช้ Luka ทดสอบก่อนเปลี่ยน Provider

```bash
# ทดสอบด้วย Luka (ออฟไลน์, ฟรี)
~/02luka/tools/llm-run --in test.json --provider luka
cat test.json.result

# ถ้า format ถูกต้อง → เปลี่ยนเป็น provider จริง
~/02luka/tools/llm-run --in test.json --provider grok
cat test.json.result
```

**ประโยชน์:**
- ไม่เสีย API quota ตอนทดสอบ
- ไม่ต้องรอ network
- เห็นว่า work order format ถูกต้องหรือยัง

---

#### 5. Debugging ด้วย Luka

```bash
# เปิด verbose mode (ถ้า adapter รองรับ)
DEBUG=1 ~/02luka/tools/llm-run --in test.json --provider luka

# ดู telemetry real-time
tail -f ~/02luka/telemetry/metrics.jsonl

# เช็ค exit code
~/02luka/tools/llm-run --in test.json --provider luka
echo $?  # 0 = success, non-zero = error
```

---

### 📊 Luka Adapter Architecture

```
Work Order (JSON)
       ↓
llm-run (shim)
       ↓
luka_adapter.zsh
       ↓
┌─────────────────────────────┐
│  Local Processing           │
│  • Read input               │
│  • Count tokens (approx)    │
│  • Generate stub response   │
│  • Write output JSON        │
└─────────────────────────────┘
       ↓
Result JSON + Telemetry
```

**Luka Adapter Location:**
```bash
~/02luka/tools/providers/luka_adapter.zsh
```

**สิ่งที่ Luka ทำ:**
1. อ่าน work order
2. Extract text จาก inputs
3. Count tokens (ประมาณ)
4. สร้าง response (stub/mock)
5. เขียน result JSON (format มาตรฐาน)
6. บันทึก telemetry

---

## กลไกการ Sync Repo

### 🔄 Overview: Repo Sync Architecture

```
┌────────────────────────────────────────────────────────┐
│                  GitHub (Remote)                       │
│  github.com/lc1558/02luka                             │
│  github.com/lc1558/02luka-memory                      │
└──────────────┬─────────────────────────────────────────┘
               │
        git fetch/pull/push
               │
┌──────────────┴─────────────────────────────────────────┐
│              ~/dev/ (Git Repos)                        │
│  ~/dev/02luka-repo/         (code repository)         │
│  ~/dev/02luka-memory/       (sessions/memory)         │
└──────────────┬─────────────────────────────────────────┘
               │
        ~/02luka/tools/sync_with_repos.zsh
               │
        ┌──────┴──────┐
        │             │
   --from-repo   --to-repo
        │             │
        ↓             ↓
┌──────────────────────────────────────────────────────┐
│         ~/02luka/ (Runtime SOT)                      │
│  Working directory ที่ระบบใช้งานจริง                │
└──────────────────────────────────────────────────────┘
```

---

### 📂 โครงสร้าง 3 Layer

#### Layer 1: GitHub (Remote) - Version Control
```
github.com/lc1558/02luka
github.com/lc1558/02luka-memory

• ประวัติการแก้ไข (git history)
• Pull requests, Issues
• Collaboration
• Backup อัตโนมัติ
```

#### Layer 2: ~/dev/ (Local Git Repos)
```
~/dev/02luka-repo/         # Clone of github.com/lc1558/02luka
~/dev/02luka-memory/       # Clone of github.com/lc1558/02luka-memory

• Git working directory
• Commit changes ที่นี่
• Push/pull กับ GitHub
• Branching, PR development
```

#### Layer 3: ~/02luka/ (Runtime SOT)
```
~/02luka/                  # Single Source of Truth

• ระบบใช้งานจริง
• Tools ทำงานที่นี่
• LaunchAgents อ่านที่นี่
• ไม่มี .git/ (no git tracking)
```

---

### 🔄 Sync Scripts

#### 1. Bootstrap Repos (ครั้งแรก)

```bash
# สร้าง repos structure
~/02luka/tools/repos_bootstrap.zsh
```

**สิ่งที่สคริปต์ทำ:**
```bash
1. สร้าง ~/dev/ directory
2. Clone repos จาก GitHub:
   - git clone https://github.com/lc1558/02luka.git ~/dev/02luka-repo
   - git clone https://github.com/lc1558/02luka-memory.git ~/dev/02luka-memory
3. ตั้งค่า git credential helper (osxkeychain)
4. Config remotes ให้ใช้ HTTPS (or SSH if available)
```

**Authentication:**
- ✅ **SSH Keys** (แนะนำ) - ไม่ต้องจัดการ PAT
- ⚙️ **HTTPS + Keychain PAT** - สำหรับ HTTPS auth

**ตรวจสอบ:**
```bash
# เช็คว่า repos clone แล้ว
ls -la ~/dev/02luka-repo/.git
ls -la ~/dev/02luka-memory/.git

# เช็ค remotes
cd ~/dev/02luka-repo && git remote -v
cd ~/dev/02luka-memory && git remote -v
```

---

#### 2. Sync: Repo → Runtime (Deploy)

```bash
# ดึง code จาก repo มาใช้ใน runtime
~/02luka/tools/sync_with_repos.zsh --from-repo
```

**สิ่งที่เกิดขึ้น:**
```bash
1. อ่าน allowlist (PULL_LIST)
   PULL_LIST=("tools" "scripts" "agents" "bridge" "docs")

2. สำหรับแต่ละ directory ใน list:
   rsync -av --delete \
     ~/dev/02luka-repo/tools/ \
     ~/02luka/tools/

3. ทำซ้ำกับทุก directory ใน PULL_LIST

4. แสดงผลลัพธ์:
   ✅ Deployed from repo → runtime
```

**ตัวอย่าง:**
```bash
# Before deploy
~/02luka/tools/my_script.sh  # Version A

# In repo, คุณแก้เป็น Version B
~/dev/02luka-repo/tools/my_script.sh  # Version B

# Run deploy
~/02luka/tools/sync_with_repos.zsh --from-repo

# After deploy
~/02luka/tools/my_script.sh  # Version B (ถูกแทนที่)
```

**⚠️ คำเตือน:**
- `--delete` flag จะลบไฟล์ที่ไม่มีใน repo
- Backup ไฟล์สำคัญก่อน deploy
- ตรวจสอบว่าแก้ code ที่ repo, ไม่ใช่ runtime

---

#### 3. Sync: Runtime → Repo (Collect)

```bash
# เก็บ artifacts จาก runtime ไป commit
~/02luka/tools/sync_with_repos.zsh --to-repo
```

**สิ่งที่เกิดขึ้น:**
```bash
1. อ่าน allowlist (PUSH_LIST)
   PUSH_LIST=("tools" "docs")

2. สำหรับแต่ละ directory ใน list:
   rsync -av --exclude '*.log' \
     ~/02luka/tools/ \
     ~/dev/02luka-repo/tools/

3. ไม่รวม: logs, temp files, cache

4. แสดงผลลัพธ์:
   ✅ Collected runtime → repo (commit & push manually)
```

**ขั้นตอนหลัง collect:**
```bash
# 1. ไปที่ repo
cd ~/dev/02luka-repo

# 2. ดูว่ามีอะไรเปลี่ยน
git status
git diff

# 3. Add & commit
git add tools/ docs/
git commit -m "Update: new LLM adapters and documentation"

# 4. Push to GitHub
git push origin main
```

**Use Case:**
- เก็บ tools ที่สร้างใหม่ไป version control
- เก็บ docs ที่อัปเดต
- **ไม่เก็บ** logs, temp files, sensitive data

---

### 🔐 Allowlists (Whitelist Directories)

**PULL_LIST (from-repo):**
```bash
# ใน sync_with_repos.zsh
PULL_LIST=(
  "tools"      # Scripts, adapters
  "scripts"    # Automation scripts
  "agents"     # Agent implementations
  "bridge"     # Message bridge
  "docs"       # Documentation
)
```

**PUSH_LIST (to-repo):**
```bash
# ใน sync_with_repos.zsh
PUSH_LIST=(
  "tools"      # Updated scripts
  "docs"       # Updated documentation
)
```

**ทำไมไม่เท่ากัน?**
- **PULL:** ดึงทุกอย่างที่จำเป็นมา runtime
- **PUSH:** เก็บเฉพาะสิ่งที่ควร version control (ไม่เก็บ config, logs, data)

**แก้ไข Allowlists:**
```bash
vim ~/02luka/tools/sync_with_repos.zsh

# หา PULL_LIST และ PUSH_LIST
# เพิ่ม/ลบ directories ตามต้องการ
```

---

### 🔄 Bidirectional Sync Flow

#### Scenario 1: พัฒนา Feature ใหม่

```bash
# 1. แก้ code ใน repo
cd ~/dev/02luka-repo
vim tools/my_new_feature.sh
git add tools/my_new_feature.sh
git commit -m "Add: new feature"

# 2. Deploy ไป runtime ทดสอบ
~/02luka/tools/sync_with_repos.zsh --from-repo

# 3. ทดสอบใน runtime
~/02luka/tools/my_new_feature.sh

# 4. ถ้าทำงาน → push to GitHub
cd ~/dev/02luka-repo
git push origin main
```

---

#### Scenario 2: สร้าง Tool ใหม่ใน Runtime

```bash
# 1. สร้าง/แก้ใน runtime (ทดสอบเร็ว)
vim ~/02luka/tools/experimental_tool.sh
chmod +x ~/02luka/tools/experimental_tool.sh
~/02luka/tools/experimental_tool.sh  # ทดสอบ

# 2. ถ้าทำงานดี → collect ไป repo
~/02luka/tools/sync_with_repos.zsh --to-repo

# 3. Commit & push
cd ~/dev/02luka-repo
git status  # เห็น experimental_tool.sh
git add tools/experimental_tool.sh
git commit -m "Add: experimental tool for testing"
git push origin main
```

---

#### Scenario 3: Update จาก Pull Request

```bash
# 1. มี PR merge บน GitHub
# (คนอื่น contribute หรือ merge branch)

# 2. Pull ใน repo
cd ~/dev/02luka-repo
git pull origin main

# 3. Deploy ไป runtime
~/02luka/tools/sync_with_repos.zsh --from-repo

# 4. ทดสอบว่าทำงาน
~/02luka/tools/llm-run --health
```

---

## Pull Request จาก GitHub

### 📥 กระบวนการ PR กับ SOT Structure

#### 1. โครงสร้าง SOT ล่าสุด (Post-Migration)

```
/Users/icmini/02luka/                 ← Runtime SOT (ไม่มี .git)
├── tools/
│   ├── llm-run                       ← LLM shim
│   ├── providers/                    ← Provider adapters
│   │   ├── luka_adapter.zsh
│   │   ├── grok_adapter.zsh
│   │   ├── gci_adapter.zsh
│   │   └── clc_adapter.zsh
│   ├── backup_to_gdrive.zsh
│   ├── sync_with_repos.zsh
│   └── repos_bootstrap.zsh
├── config/
│   ├── system.yaml                   ← Global config
│   └── routing.yaml                  ← Provider routing
├── bridge/
│   ├── inbox/LLM/                    ← Work order queue
│   └── outbox/LLM/                   ← Results
├── g/                                ← Working directory
│   ├── manuals/                      ← Documentation
│   ├── reports/                      ← Session reports
│   └── tools/                        ← Utility scripts
├── logs/                             ← System logs
├── telemetry/                        ← Metrics
├── memory/                           ← Memory system
└── 02luka.md                         ← Master SOT doc

~/dev/02luka-repo/                    ← Git repo (มี .git)
├── tools/                            ← Source code
├── docs/                             ← Documentation
├── config/                           ← Config templates
├── .github/                          ← GitHub workflows
├── README.md                         ← Project README
└── .gitignore                        ← Git ignore rules
```

---

#### 2. การจัดการ PR (Pull Request)

##### Step 1: รับ PR จาก GitHub

```bash
# 1. Review PR บน GitHub
# https://github.com/lc1558/02luka/pulls

# 2. Merge PR (บน GitHub UI)
# คลิก "Merge pull request"

# 3. Pull changes มายัง local repo
cd ~/dev/02luka-repo
git checkout main
git pull origin main

# Output:
# Updating abc1234..def5678
# Fast-forward
#  tools/new_adapter.zsh | 150 ++++++++++++++++
#  1 file changed, 150 insertions(+)
```

---

##### Step 2: Deploy PR ไป Runtime

```bash
# Deploy changes ไป runtime SOT
~/02luka/tools/sync_with_repos.zsh --from-repo

# Output:
# ✅ Deployed from repo → runtime

# ตรวจสอบว่าไฟล์ใหม่อยู่ที่ runtime
ls -la ~/02luka/tools/new_adapter.zsh
```

---

##### Step 3: ทดสอบใน Runtime

```bash
# ทดสอบไฟล์/feature ใหม่
~/02luka/tools/llm-run --health

# หรือทดสอบ adapter ใหม่
~/02luka/tools/llm-run --in test.json --provider new-provider
```

---

##### Step 4: Rollback (ถ้ามีปัญหา)

```bash
# 1. Revert commit ใน repo
cd ~/dev/02luka-repo
git revert HEAD
git push origin main

# 2. Deploy version เก่ากลับมา
~/02luka/tools/sync_with_repos.zsh --from-repo

# หรือ restore จาก snapshot
rsync -a --delete \
  ~/02luka/_safety_snapshots/final_verified_20251104_0304/ \
  ~/02luka/
```

---

#### 3. สร้าง PR จาก Local Changes

##### Scenario: แก้ไข Adapter ใน Runtime

```bash
# 1. แก้ไข/สร้างไฟล์ใหม่ใน runtime
vim ~/02luka/tools/providers/my_new_adapter.zsh
chmod +x ~/02luka/tools/providers/my_new_adapter.zsh

# ทดสอบ
~/02luka/tools/llm-run --in test.json --provider my-new-provider

# 2. Collect ไป repo
~/02luka/tools/sync_with_repos.zsh --to-repo

# 3. สร้าง branch ใหม่
cd ~/dev/02luka-repo
git checkout -b feature/my-new-adapter

# 4. Commit changes
git add tools/providers/my_new_adapter.zsh
git commit -m "feat: add my new adapter for XYZ provider"

# 5. Push branch
git push origin feature/my-new-adapter

# 6. สร้าง PR บน GitHub
# ไปที่ https://github.com/lc1558/02luka
# คลิก "Compare & pull request"
# เขียน description
# คลิก "Create pull request"
```

---

#### 4. Review PR Best Practices

**ก่อน Deploy PR ไป Runtime:**

```bash
# 1. ดู changes ใน PR
cd ~/dev/02luka-repo
git log -1 -p  # ดู last commit diff

# 2. เช็คว่าไม่มี sensitive data
git diff origin/main | grep -i "password\|secret\|key"

# 3. Backup runtime ก่อน deploy
SNAPSHOT_DIR=~/02luka/_safety_snapshots/pre_pr_$(date +%s)
rsync -a --delete ~/02luka/ "$SNAPSHOT_DIR/"

# 4. Deploy
~/02luka/tools/sync_with_repos.zsh --from-repo

# 5. ทดสอบ
~/02luka/tools/llm-run --health

# 6. ถ้ามีปัญหา → restore จาก snapshot
rsync -a --delete "$SNAPSHOT_DIR/" ~/02luka/
```

---

### 🔄 PR Workflow Diagram

```
┌────────────────────────────────────────────────────────┐
│  Developer (Local or Remote)                          │
│  1. Clone repo                                        │
│  2. Create branch                                     │
│  3. Make changes                                      │
│  4. Push branch                                       │
└───────────────┬────────────────────────────────────────┘
                │
                ↓
┌────────────────────────────────────────────────────────┐
│  GitHub Pull Request                                   │
│  • Code review                                        │
│  • CI/CD tests (optional)                            │
│  • Discussion                                         │
│  • Approve & Merge                                    │
└───────────────┬────────────────────────────────────────┘
                │
                ↓
┌────────────────────────────────────────────────────────┐
│  main branch updated                                   │
└───────────────┬────────────────────────────────────────┘
                │
                ↓
┌────────────────────────────────────────────────────────┐
│  Your Local Repo (~/dev/02luka-repo)                  │
│  git pull origin main                                 │
└───────────────┬────────────────────────────────────────┘
                │
                ↓
┌────────────────────────────────────────────────────────┐
│  sync_with_repos.zsh --from-repo                      │
│  Deploy to runtime                                    │
└───────────────┬────────────────────────────────────────┘
                │
                ↓
┌────────────────────────────────────────────────────────┐
│  Runtime SOT (~/02luka)                               │
│  Changes applied                                      │
│  Test & Verify                                        │
└────────────────────────────────────────────────────────┘
```

---

## SOT Structure ล่าสุด

### 📁 โครงสร้างปัจจุบัน (v2.0)

```
/Users/icmini/02luka/                     # Root SOT
│
├── 02luka.md                             # Master SOT document
├── paths.env                             # Environment variables
├── .sot_real_20251103_015144             # SOT marker
│
├── tools/                                # System tools
│   ├── llm-run                           # Main LLM shim ⭐
│   ├── providers/                        # Provider adapters ⭐
│   │   ├── luka_adapter.zsh             # Local offline
│   │   ├── grok_adapter.zsh             # xAI Grok
│   │   ├── gci_adapter.zsh              # Google Gemini
│   │   └── clc_adapter.zsh              # Anthropic Claude
│   ├── llm_resource_mgmt.zsh            # Resource management ⭐
│   ├── backup_to_gdrive.zsh             # GD backup ⭐
│   ├── sync_with_repos.zsh              # Repo sync ⭐
│   ├── repos_bootstrap.zsh              # GitHub setup ⭐
│   ├── cleanup_to_lukadata.zsh          # Cleanup script
│   └── verify_sot.sh                    # Health check
│
├── config/                               # Configuration ⭐ NEW
│   ├── system.yaml                       # Global config
│   └── routing.yaml                      # Provider routing
│
├── bridge/                               # Message bridge
│   ├── inbox/                            # Incoming
│   │   ├── LLM/                         # LLM work orders ⭐
│   │   ├── CLC/  → inbox/LLM           # Legacy symlink
│   │   └── GCI/  → inbox/LLM           # Legacy symlink
│   ├── outbox/                           # Results
│   │   ├── LLM/                         # LLM results ⭐
│   │   ├── CLC/  → outbox/LLM          # Legacy symlink
│   │   └── GCI/  → outbox/LLM          # Legacy symlink
│   └── archive/                          # Old work orders
│
├── telemetry/                            # Metrics ⭐ NEW
│   ├── metrics.jsonl                     # Usage logs
│   └── archive/                          # Rotated telemetry
│
├── g/                                    # Working directory
│   ├── manuals/                          # คู่มือ
│   │   ├── 02luka_system_capabilities_th.md
│   │   ├── QUICK_START_TH.md
│   │   └── local_luka_cli_and_repo_sync_th.md
│   ├── reports/                          # รายงาน
│   │   └── sessions/                     # Session reports
│   └── tools/                            # Utility scripts
│
├── logs/                                 # System logs
├── memory/                               # Memory system
│   ├── autosave/                         # Auto-saved memories
│   └── cls/                              # Classified memories
│
├── _safety_snapshots/  → /Volumes/lukadata/...  # Symlink
└── archive/            → /Volumes/lukadata/...  # Symlink

/Volumes/lukadata/02luka_archives/        # External storage
├── snapshots/                            # 89GB safety snapshots
├── legacy_reports/                       # Old scan reports
├── old_archives/                         # Historical archives
└── rotated_logs/                         # Compressed logs

~/dev/                                    # Git repos
├── 02luka-repo/                          # Main code repo
└── 02luka-memory/                        # Memory/sessions repo
```

---

### 🆕 สิ่งใหม่ที่เพิ่มเข้ามา (v2.0)

#### 1. Multi-Provider LLM System
```
tools/
├── llm-run                    # Provider-agnostic shim
└── providers/                 # Adapter pattern
    ├── luka_adapter.zsh      # Offline provider
    ├── grok_adapter.zsh      # xAI
    ├── gci_adapter.zsh       # Google
    └── clc_adapter.zsh       # Anthropic
```

#### 2. Configuration System
```
config/
├── system.yaml      # Global: provider, timeouts, limits
└── routing.yaml     # Auto-routing by task pattern
```

#### 3. Telemetry System
```
telemetry/
├── metrics.jsonl    # All LLM calls logged
└── archive/         # Auto-rotated old data
```

#### 4. Automation Scripts
```
tools/
├── backup_to_gdrive.zsh    # Automated backups
├── sync_with_repos.zsh     # Bidirectional sync
└── repos_bootstrap.zsh     # GitHub setup
```

#### 5. Provider-Neutral Queues
```
bridge/
├── inbox/LLM/      # Neutral queue (vs old CLC/GCI)
└── outbox/LLM/     # Neutral results
```

---

## สิ่งที่เปลี่ยนไปจากเดิม

### 🔄 ก่อน vs หลัง Architecture Upgrade

#### 1. SOT Location

**ก่อน:**
```
/Users/icmini/LocalProjects/02luka_local_g/
หรือ
~/Library/CloudStorage/GoogleDrive-.../My Drive/02luka/
```

**หลัง:**
```
/Users/icmini/02luka/          # เฉพาะที่นี่เท่านั้น!
```

**ทำไมเปลี่ยน:**
- ✅ ทำงานเร็วขึ้น (local disk vs cloud sync)
- ✅ ไม่ขึ้นกับ Google Drive
- ✅ Path สั้นกว่า, จำง่ายกว่า
- ✅ ไม่ conflict กับ GD sync

---

#### 2. LLM Provider System

**ก่อน (Monolithic):**
```bash
# Hard-coded provider
# ต้องแก้ code ทุกครั้งที่เปลี่ยน provider

# Example:
if provider == "claude":
    call_claude_api(...)
elif provider == "gemini":
    call_gemini_api(...)
```

**หลัง (Provider-Agnostic):**
```bash
# เปลี่ยน provider ใน 1 บรรทัด
~/02luka/tools/llm-run --in wo.json --provider grok

# หรือใน config
# config/system.yaml:
#   llm.provider: grok
```

**ประโยชน์:**
- ✅ เปลี่ยน provider ได้ทันที (ไม่ต้องแก้โค้ด)
- ✅ A/B test providers ได้ง่าย
- ✅ Fallback chains (ถ้า provider 1 fail → ลอง provider 2)
- ✅ Cost optimization (route ตามประเภทงาน)

---

#### 3. Work Order Queues

**ก่อน:**
```
bridge/inbox/CLC/     # สำหรับ Claude
bridge/inbox/GCI/     # สำหรับ Gemini
```

**หลัง:**
```
bridge/inbox/LLM/     # Provider-neutral queue
bridge/inbox/CLC/     → symlink to LLM/ (backward compat)
bridge/inbox/GCI/     → symlink to LLM/ (backward compat)
```

**ประโยชน์:**
- ✅ Queue เดียว ทำงานกับทุก provider
- ✅ Backward compatible (queue เก่ายังใช้ได้)
- ✅ Simpler routing logic

---

#### 4. Configuration

**ก่อน:**
```bash
# Hard-coded ใน scripts
TIMEOUT=600
MAX_INPUT_SIZE=10485760
PROVIDER="claude"
```

**หลัง:**
```yaml
# config/system.yaml
llm:
  provider: gemini
  timeout_s: 600
  max_input_mb: 10
  rate_limit_per_min: 10
```

**ประโยชน์:**
- ✅ เปลี่ยน config ไม่ต้องแก้โค้ด
- ✅ แชร์ config ได้ง่าย
- ✅ Version control config ง่าย

---

#### 5. Resource Management

**ก่อน:**
```
❌ ไม่มี auto-cleanup
❌ Telemetry เติบโตไม่จำกัด
❌ ไม่มี disk guards
❌ ไม่มี rate limiting
```

**หลัง:**
```
✅ Auto-rotation telemetry (>10MB)
✅ Auto-cleanup WO queue (>7 days)
✅ Disk guards (ต้องมี >5GB free)
✅ Rate limiting (10 calls/min)
✅ Input capping (max 10MB)
```

**ประโยชน์:**
- ป้องกันระบบล้มเพราะ disk เต็ม
- ป้องกัน quota หมด
- ระบบดูแลตัวเองอัตโนมัติ

---

#### 6. GitHub Integration

**ก่อน:**
```
❌ ไม่มี sync scripts
❌ แก้ใน runtime โดยตรง
❌ ไม่มี version control workflow
```

**หลัง:**
```
✅ sync_with_repos.zsh (bidirectional)
✅ repos_bootstrap.zsh (setup)
✅ แยก runtime vs repo ชัดเจน
✅ PR workflow สำเร็จรูป
```

**ประโยชน์:**
- Version control code อย่างถูกต้อง
- Collaboration ง่าย (PR, reviews)
- Rollback ได้ทันที
- Backup code บน GitHub

---

#### 7. Backups

**ก่อน:**
```
❌ Manual backup
❌ ไม่มี automation
❌ Inconsistent schedule
```

**หลัง:**
```
✅ Automated backups ทุก 8 ชั่วโมง
✅ LaunchAgent scheduled
✅ Exclude logs, cache (ไม่backup ของไม่จำเป็น)
✅ One-way sync to GD
```

**ประโยชน์:**
- ไม่ลืม backup
- ประหยัดพื้นที่ (backup เฉพาะที่จำเป็น)
- Disaster recovery ready

---

#### 8. Telemetry

**ก่อน:**
```
❌ ไม่มี centralized logging
❌ ไม่ track costs
❌ ไม่รู้ว่าใช้ provider ไหนบ่อย
```

**หลัง:**
```
✅ telemetry/metrics.jsonl
✅ Track: provider, tokens, cost, duration
✅ Auto-rotation
✅ Query ได้ด้วย jq
```

**ประโยชน์:**
- รู้ว่าใช้เงินไปเท่าไหร่
- Optimize provider selection
- Debug performance issues

---

### 📊 เปรียบเทียบ Workflows

#### Workflow: แก้ Code

**ก่อน (v1.0):**
```bash
1. แก้ไฟล์ใน SOT โดยตรง
   vim ~/LocalProjects/02luka_local_g/tools/script.sh

2. ทดสอบ
   ~/LocalProjects/02luka_local_g/tools/script.sh

3. ไม่มี version control
   (เสี่ยงสูญหาย)
```

**หลัง (v2.0):**
```bash
1. แก้ใน repo
   cd ~/dev/02luka-repo
   vim tools/script.sh
   git add tools/script.sh
   git commit -m "fix: script improvement"

2. Deploy to runtime
   ~/02luka/tools/sync_with_repos.zsh --from-repo

3. ทดสอบใน runtime
   ~/02luka/tools/script.sh

4. Push to GitHub
   git push origin main
```

**ประโยชน์:**
- ✅ มี history (git log)
- ✅ Rollback ได้ (git revert)
- ✅ Backup บน GitHub
- ✅ Collaborate ได้ (PR)

---

#### Workflow: เปลี่ยน LLM Provider

**ก่อน (v1.0):**
```bash
1. หา code ที่ hard-coded provider
2. แก้ทุกไฟล์ที่เกี่ยวข้อง
3. Test ทีละไฟล์
4. เสี่ยง break existing code
```

**หลัง (v2.0):**
```bash
1. เปลี่ยน 1 บรรทัด:
   vim ~/02luka/config/system.yaml
   # llm.provider: gemini → grok

2. หรือใช้ parameter:
   ~/02luka/tools/llm-run --in wo.json --provider grok

3. เสร็จ! ไม่ต้องแก้โค้ด
```

**ประโยชน์:**
- ✅ เร็วมาก (1 บรรทัด)
- ✅ ไม่ break existing code
- ✅ A/B test ได้ง่าย

---

#### Workflow: ทดสอบ LLM Call

**ก่อน (v1.0):**
```bash
1. เรียก provider จริงทันที
   (เสีย quota, รอ API response)

2. ถ้า WO format ผิด = เสียเงินฟรี
```

**หลัง (v2.0):**
```bash
1. ทดสอบด้วย Luka (offline, ฟรี)
   ~/02luka/tools/llm-run --in test.json --provider luka

2. ตรวจ format ว่าถูกต้อง
   cat test.json.result

3. ค่อยเปลี่ยนเป็น provider จริง
   ~/02luka/tools/llm-run --in test.json --provider grok
```

**ประโยชน์:**
- ✅ ประหยัด quota
- ✅ ทดสอบเร็ว (ไม่ต้องรอ API)
- ✅ แน่ใจว่า format ถูกก่อนเสียเงิน

---

## Workflow ใหม่

### 🎯 Recommended Workflows (v2.0)

#### Workflow 1: Daily Development

```bash
# Morning: Sync latest from GitHub
cd ~/dev/02luka-repo
git pull origin main
~/02luka/tools/sync_with_repos.zsh --from-repo

# Work: แก้ code ใน runtime (quick testing)
vim ~/02luka/tools/my_tool.sh
~/02luka/tools/my_tool.sh  # ทดสอบ

# ถ้าทำงานดี: Collect ไป repo
~/02luka/tools/sync_with_repos.zsh --to-repo
cd ~/dev/02luka-repo
git add tools/my_tool.sh
git commit -m "feat: add my tool"
git push origin main

# Evening: Backup (อัตโนมัติ ทุก 8 ชม)
# (ไม่ต้องทำอะไร - LaunchAgent ทำให้)
```

---

#### Workflow 2: Feature Development

```bash
# 1. Create feature branch
cd ~/dev/02luka-repo
git checkout -b feature/new-provider

# 2. Develop in runtime
~/02luka/tools/sync_with_repos.zsh --from-repo
vim ~/02luka/tools/providers/new_provider.zsh
~/02luka/tools/llm-run --in test.json --provider new

# 3. Test thoroughly with Luka first
~/02luka/tools/llm-run --in test.json --provider luka
# ตรวจ output format

# 4. Test with real provider
~/02luka/tools/llm-run --in test.json --provider new

# 5. Collect & commit
~/02luka/tools/sync_with_repos.zsh --to-repo
cd ~/dev/02luka-repo
git add tools/providers/new_provider.zsh
git commit -m "feat: add new provider adapter"
git push origin feature/new-provider

# 6. Create PR on GitHub
# Review → Merge → Pull → Deploy
```

---

#### Workflow 3: Production Deployment

```bash
# 1. Review PR on GitHub
# Check code, tests, discussion

# 2. Merge PR (on GitHub)

# 3. Pull to local repo
cd ~/dev/02luka-repo
git pull origin main

# 4. Backup runtime before deploy
SNAPSHOT=~/02luka/_safety_snapshots/pre_deploy_$(date +%s)
rsync -a ~/02luka/ "$SNAPSHOT/"

# 5. Deploy to runtime
~/02luka/tools/sync_with_repos.zsh --from-repo

# 6. Verify deployment
~/02luka/tools/llm-run --health
~/02luka/tools/llm-run --in test.json --provider luka

# 7. Monitor telemetry
tail -f ~/02luka/telemetry/metrics.jsonl

# 8. Rollback if issues
rsync -a --delete "$SNAPSHOT/" ~/02luka/
```

---

#### Workflow 4: Cost Optimization

```bash
# 1. ดู telemetry แยกตาม provider
jq -s 'group_by(.provider) |
  map({
    provider: .[0].provider,
    calls: length,
    tokens_total: (map(.tokens_in + .tokens_out) | add),
    cost_total: (map(.cost_usd) | add)
  })' ~/02luka/telemetry/metrics.jsonl

# 2. เช็คว่า provider ไหนแพงที่สุด

# 3. Route งานบางประเภทไป provider ถูกกว่า
vim ~/02luka/config/routing.yaml

# Example: งาน simple → ใช้ gemini (ถูกกว่า)
#          งาน complex → ใช้ claude (แม่นกว่า)

# 4. Monitor ว่าต้นทุนลดลง
jq -s 'map(.cost_usd) | add' ~/02luka/telemetry/metrics.jsonl
```

---

## 🎓 สรุป

### การเปลี่ยนแปลงหลัก

1. **SOT Location:** `~/02luka` (เดียว, ชัดเจน)
2. **LLM System:** Provider-agnostic (เปลี่ยนได้ใน 1 บรรทัด)
3. **Repo Sync:** Bidirectional workflow (repo ↔ runtime)
4. **Automation:** Backups, resource management, telemetry
5. **Configuration:** YAML-based, ไม่ hard-code

### ประโยชน์ที่ได้

✅ **เร็วขึ้น** - Local disk vs cloud sync
✅ **ยืดหยุ่นขึ้น** - เปลี่ยน provider ได้ง่าย
✅ **ปลอดภัยขึ้น** - Version control, automated backups
✅ **ประหยัดขึ้น** - ทดสอบด้วย Luka ก่อน, cost tracking
✅ **ดูแลง่ายขึ้น** - Auto-cleanup, health monitoring

### Workflows ใหม่

- Daily development: Quick iteration ใน runtime → collect to repo
- Feature development: Branch → develop → PR → merge → deploy
- Production deployment: Review → backup → deploy → verify → rollback if needed
- Cost optimization: Monitor telemetry → route by task type

---

**เอกสารนี้สร้างเมื่อ:** 2025-11-04
**สำหรับ:** 02LUKA System v2.0
**โดย:** Claude Code (CLC)

**เอกสารอื่นๆ:**
- `02luka_system_capabilities_th.md` - ความสามารถระบบ
- `QUICK_START_TH.md` - Quick reference
- `~/02luka/02luka.md` - Master SOT document
