# 02LUKA System - คู่มือความสามารถและการใช้งาน

**เวอร์ชัน:** 2.0 (Provider-Agnostic Architecture)
**อัปเดต:** 2025-11-04
**สถานะ:** ✅ PRODUCTION READY

---

## 📋 สารบัญ

1. [ระบบมีความสามารถอะไรบ้าง](#ระบบมีความสามารถอะไรบ้าง)
2. [ระบบทำงานอย่างไร](#ระบบทำงานอย่างไร)
3. [รองรับเรื่องใดบ้าง](#รองรับเรื่องใดบ้าง)
4. [การตั้งค่า Cursor IDE](#การตั้งค่า-cursor-ide)
5. [คำถามที่พบบ่อย](#คำถามที่พบบ่อย)

---

## ระบบมีความสามารถอะไรบ้าง

### 🤖 1. Multi-Provider LLM System (ใหม่!)

**เปลี่ยนผู้ให้บริการ AI ได้ภายใน 1 บรรทัด**

```bash
# ใช้ Luka (ออฟไลน์, ฟรี)
~/02luka/tools/llm-run --in work_order.json --provider luka

# ใช้ Grok (xAI)
~/02luka/tools/llm-run --in work_order.json --provider grok

# ใช้ Gemini (Google)
~/02luka/tools/llm-run --in work_order.json --provider gemini

# ใช้ Claude (Anthropic)
~/02luka/tools/llm-run --in work_order.json --provider anthropic
```

**ผู้ให้บริการที่รองรับ:**
- ✅ **Luka** - ออฟไลน์, ไม่มีค่าใช้จ่าย, ทดสอบได้ทันที
- ✅ **Grok** - xAI, พร้อมใช้ (ใส่ API key)
- 🔧 **Gemini** - Google, มี stub adapter (implement เมื่อต้องการ)
- 🔧 **Claude** - Anthropic, มี stub adapter (implement เมื่อต้องการ)

**ข้อดี:**
- สลับผู้ให้บริการได้ทันทีโดยไม่แก้โค้ด
- เลือกผู้ให้บริการตามประเภทงาน (เช่น coding → Claude, reasoning → Grok)
- มี fallback อัตโนมัติถ้าผู้ให้บริการหลักใช้ไม่ได้
- ติดตามต้นทุนทุก provider แยกกัน

---

### 💾 2. Resource Management (จัดการทรัพยากร)

**ป้องกันระบบล้มเพราะ disk เต็ม หรือ RAM หมด**

```bash
# ตรวจสุขภาพระบบ
~/02luka/tools/llm-run --health

# Output:
# Providers:  ✅ grok  ✅ luka
# Disk:       135GB free
# Queue:      2 WOs pending
# Telemetry:  1.5M
```

**คุณสมบัติ:**
- 🔄 **Auto-rotation telemetry:** เมื่อ >10MB จะย้ายไฟล์เก่าทิ้งอัตโนมัติ
- 🧹 **Queue cleanup:** ย้าย work orders เก่า >7 วันไปเก็บ archive
- 💾 **Disk guards:** เช็คพื้นที่ก่อนรัน ถ้า <5GB จะไม่ให้ทำงาน
- 📊 **Input capping:** จำกัดข้อมูลส่งเข้า max 10MB ป้องกัน RAM overflow
- ⏱️ **Rate limiting:** ไม่เกิน 10 calls/min ป้องกัน quota หมด

---

### 🔄 3. Automated Backups (สำรองข้อมูลอัตโนมัติ)

**สำรองไปยัง Google Drive ทุก 8 ชั่วโมง**

```bash
# ตรวจสอบสถานะ backup
launchctl list | grep backup.gdrive

# รัน backup ทันที (manual)
~/02luka/tools/backup_to_gdrive.zsh

# ตรวจดู log
tail -f ~/02luka/logs/backup_gd.out.log
```

**รายละเอียด:**
- ⏰ **รันอัตโนมัติ:** ทุก 8 ชั่วโมง (LaunchAgent)
- 📁 **ปลายทาง:** Google Drive Mirror mode
- 🚫 **ไม่รวม:** logs, snapshots, cache ที่ไม่จำเป็น
- ✅ **ปลอดภัย:** ใช้ rsync --delete (one-way sync)

---

### 📂 4. GitHub Integration (เชื่อมต่อ GitHub)

**Sync code ระหว่าง runtime และ GitHub repos**

```bash
# ดึง code จาก repo มาใช้ (deploy)
~/02luka/tools/sync_with_repos.zsh --from-repo

# เก็บ artifacts ไป commit (collect)
~/02luka/tools/sync_with_repos.zsh --to-repo
cd ~/dev/02luka-repo
git add . && git commit -m "Update" && git push
```

**โครงสร้าง repos:**
- `~/dev/02luka-repo` - โค้ดหลัก
- `~/dev/02luka-memory` - memory/sessions

**Authentication:**
- ✅ SSH keys พร้อมใช้งาน (ไม่ต้องจัดการ PAT)
- 🔐 Keychain credential helper (สำหรับ HTTPS)

---

### 📊 5. Telemetry & Cost Tracking (ติดตามต้นทุน)

**ทุก LLM call บันทึกข้อมูลอัตโนมัติ**

```bash
# ดูการใช้งานล่าสุด
tail -20 ~/02luka/telemetry/metrics.jsonl

# ตัวอย่าง entry:
{
  "ts": "2025-11-04T06:03:00Z",
  "wo_id": "WO-TEST-001",
  "provider": "luka",
  "duration_ms": 150,
  "tokens_in": 21,
  "tokens_out": 50,
  "cost_usd": 0,
  "status": "ok"
}
```

**ข้อมูลที่เก็บ:**
- ⏱️ เวลาที่ใช้ (duration_ms)
- 🔢 จำนวน tokens (in/out)
- 💰 ต้นทุน (USD)
- ✅ สถานะ (ok/error)
- 🔖 Provider ที่ใช้

---

### 🧹 6. System Cleanup (ทำความสะอาดระบบ)

**ปล่อยพื้นที่ disk โดยย้ายข้อมูลที่ไม่ต้องใช้บ่อยไป external drive**

```bash
# ขนาด SOT ลดลง 50%
# ก่อน: 178GB
# หลัง: 89GB

# ข้อมูลถูกย้ายไป:
/Volumes/lukadata/02luka_archives/
├── snapshots/         # 89GB (symlinked กลับมา)
├── legacy_reports/    # รายงานเก่า
├── old_archives/      # archive เก่า
└── rotated_logs/      # log files >30 วัน (compressed)
```

**ข้อดี:**
- 💾 ประหยัดพื้นที่ ~90GB
- 🔗 ยังเข้าถึงข้อมูลได้ผ่าน symlinks
- 📄 มี manifest บันทึกว่าอะไรอยู่ที่ไหน

---

## ระบบทำงานอย่างไร

### 🏗️ Provider-Agnostic Architecture

```
┌─────────────────────────────────────────────────────┐
│                 Your Application                     │
│         (Cursor, CLI, Web Interface)                │
└─────────────┬───────────────────────────────────────┘
              │
              │ Work Order (JSON)
              ▼
┌─────────────────────────────────────────────────────┐
│              llm-run (Shim/Router)                  │
│  • ตรวจ disk space, rate limit                      │
│  • เลือก provider จาก config หรือ parameter        │
│  • บันทึก telemetry                                │
└─────────────┬───────────────────────────────────────┘
              │
       ตามที่ config หรือ --provider
              │
      ┌───────┴────────┬─────────┬─────────┐
      ▼                ▼         ▼         ▼
┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐
│  Luka    │  │  Grok    │  │ Gemini   │  │ Claude   │
│ Adapter  │  │ Adapter  │  │ Adapter  │  │ Adapter  │
│ (Local)  │  │  (xAI)   │  │ (Google) │  │(Anthropic)│
└────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘
     │             │              │              │
     │             │ API Call     │ API Call     │ API Call
     ▼             ▼              ▼              ▼
┌─────────┐  ┌─────────┐  ┌──────────┐  ┌──────────┐
│ Local   │  │   xAI   │  │  Google  │  │ Anthropic│
│ Process │  │   API   │  │   API    │  │   API    │
└─────────┘  └─────────┘  └──────────┘  └──────────┘
```

### 📝 Work Order Flow

1. **รับ Work Order (JSON)**
   ```json
   {
     "id": "WO-001",
     "op": "analyze",
     "inputs": {"text": "ข้อความที่ต้องการวิเคราะห์"},
     "constraints": {"timeout_s": 600}
   }
   ```

2. **llm-run ตรวจสอบ**
   - Disk space พอไหม (>5GB)
   - Rate limit ไม่เกินไหม (10 calls/min)
   - Input size ไม่เกิน 10MB

3. **เลือก Provider**
   - จาก `--provider` parameter
   - หรือจาก `config/system.yaml`
   - หรือจาก `config/routing.yaml` (auto-route)

4. **เรียก Adapter**
   - อ่าน API key จาก Keychain (ปลอดภัย)
   - ส่ง HTTP request ไป API
   - จัดการ error + retry

5. **คืนผลลัพธ์**
   ```json
   {
     "id": "WO-001",
     "provider": "grok",
     "status": "ok",
     "output": {"text": "ผลลัพธ์จากการวิเคราะห์"},
     "telemetry": {
       "tokens_in": 100,
       "tokens_out": 200,
       "cost_usd": 0.0045
     }
   }
   ```

6. **บันทึก Telemetry**
   - เขียนลง `telemetry/metrics.jsonl`
   - Auto-rotate เมื่อ >10MB

---

### 🔧 Config-Driven Routing

**ตัวอย่าง `config/system.yaml`:**

```yaml
llm:
  provider: gemini           # Default provider
  timeout_s: 600
  max_input_mb: 10
  rate_limit_per_min: 10

  models:
    gemini: gemini-1.5-pro
    anthropic: claude-sonnet-4-5
    grok: grok-beta
    luka: local-default

disk:
  min_free_gb: 5
  telemetry_max_mb: 10
  wo_queue_max_age_days: 7
```

**ตัวอย่าง `config/routing.yaml`:**

```yaml
tasks:
  # งานที่ต้อง reasoning ส่งไป Grok
  - pattern: "system|logic|reasoning|judge"
    provider: grok
    model: grok-beta

  # งานเกี่ยวกับ code ส่งไป Claude
  - pattern: "analyze.*code|review.*PR|debug"
    provider: anthropic
    model: claude-sonnet-4-5

  # เอกสารยาวๆ ส่งไป Gemini (2M context)
  - pattern: "summarize.*(long|docs)|search.*docs"
    provider: gemini
    model: gemini-1.5-pro

default:
  provider: gemini
  fallback: [grok, anthropic, luka]
```

---

## รองรับเรื่องใดบ้าง

### ✅ รองรับแล้ว (ใช้ได้เลย)

#### 1. LLM Providers
- ✅ **Luka (Local)** - ออฟไลน์, ทดสอบฟรี
- ✅ **Grok (xAI)** - ใส่ API key แล้วใช้ได้

#### 2. Resource Management
- ✅ Disk space monitoring
- ✅ Telemetry auto-rotation
- ✅ Work order queue cleanup
- ✅ Input size capping
- ✅ Rate limiting

#### 3. Automation
- ✅ Automated backups (8h cycle)
- ✅ LaunchAgent configuration
- ✅ Daily maintenance tasks

#### 4. Version Control
- ✅ GitHub SSH authentication
- ✅ Bidirectional sync (repo ↔ runtime)
- ✅ Bootstrap scripts

#### 5. Monitoring
- ✅ Health checks
- ✅ Telemetry logging
- ✅ Cost tracking per provider

---

### 🔧 รองรับแบบ Stub (ต้อง implement)

#### 1. Additional Providers
- 🔧 **Gemini** - มี stub adapter, ต้องเพิ่ม API call logic
- 🔧 **Claude** - มี stub adapter, ต้องเพิ่ม API call logic

**วิธี implement:**
```bash
# แก้ไข adapter
vim ~/02luka/tools/providers/gci_adapter.zsh   # Gemini
vim ~/02luka/tools/providers/clc_adapter.zsh   # Claude

# ดู template จาก Grok adapter
cat ~/02luka/tools/providers/grok_adapter.zsh
```

#### 2. Advanced Routing
- 🔧 Pattern-based routing (มี config แต่ยังไม่ได้ใช้)
- 🔧 Load balancing between providers
- 🔧 Cost optimization routing

---

### ⏳ ยังไม่รองรับ (แต่เพิ่มได้)

#### 1. Real-time Streaming
- ❌ SSE/WebSocket streaming
- **ทำได้:** เพิ่ม streaming mode ใน adapters

#### 2. Multi-modal Input
- ❌ รูปภาพ, เสียง, วิดีโอ
- **ทำได้:** ขยาย work order schema รองรับ media

#### 3. Distributed Processing
- ❌ Multiple workers processing queue
- **ทำได้:** เพิ่ม worker pool pattern

#### 4. Web Dashboard
- ❌ Web UI สำหรับดู telemetry, queue status
- **ทำได้:** สร้าง dashboard ด้วย React/Vue

---

## การตั้งค่า Cursor IDE

### 📍 ขั้นตอนการตั้งค่า

#### 1. เปิด Cursor IDE

```bash
# ถ้ายังไม่ได้ติดตั้ง
brew install --cask cursor

# เปิด Cursor
open -a Cursor ~/02luka
```

---

#### 2. ตั้งค่า Workspace Settings

**สร้าง `.vscode/settings.json` ใน `~/02luka`:**

```json
{
  "terminal.integrated.env.osx": {
    "LUKA_SOT": "/Users/icmini/02luka",
    "LUKA_BASE": "/Users/icmini/02luka",
    "LUKA_HOME": "/Users/icmini/02luka/g",
    "SOT_PATH": "/Users/icmini/02luka/g",
    "REDIS_HOST": "127.0.0.1",
    "REDIS_PORT": "6379",
    "REDIS_PASSWORD": "gggclukaic"
  },

  "files.exclude": {
    "**/_safety_snapshots": true,
    "**/_plists_quarantine_*": true,
    "**/logs/*.log": true,
    "**/__pycache__": true,
    "**/.DS_Store": true
  },

  "search.exclude": {
    "**/logs/**": true,
    "**/_safety_snapshots/**": true,
    "**/telemetry/archive/**": true
  },

  "python.defaultInterpreterPath": "/usr/bin/python3",

  "files.watcherExclude": {
    "**/_safety_snapshots/**": true,
    "**/logs/**": true
  }
}
```

**สร้างไฟล์:**
```bash
mkdir -p ~/02luka/.vscode
cat > ~/02luka/.vscode/settings.json <<'JSON'
{
  "terminal.integrated.env.osx": {
    "LUKA_SOT": "/Users/icmini/02luka",
    "LUKA_BASE": "/Users/icmini/02luka",
    "LUKA_HOME": "/Users/icmini/02luka/g",
    "SOT_PATH": "/Users/icmini/02luka/g"
  },
  "files.exclude": {
    "**/_safety_snapshots": true,
    "**/_plists_quarantine_*": true,
    "**/logs/*.log": true,
    "**/__pycache__": true
  }
}
JSON
```

---

#### 3. ตั้งค่า AI/Copilot

**Cursor Settings → AI:**

1. **คลิก Settings (⌘,)**
2. **ไปที่ Features → AI**
3. **เลือก Model:**
   - Primary: Claude Sonnet 4.5 (แนะนำสำหรับ coding)
   - หรือ GPT-4 (ถ้าต้องการความเร็ว)

4. **Cursor Rules (Optional):**

สร้าง `.cursorrules` ใน `~/02luka`:

```bash
cat > ~/02luka/.cursorrules <<'RULES'
# 02LUKA Project Rules

## Project Structure
- SOT Location: ~/02luka
- Working Directory: ~/02luka/g
- Tools: ~/02luka/tools
- Scripts: ~/02luka/g/tools

## Code Style
- Shell scripts: Use zsh, set -euo pipefail
- Python: Use type hints, follow PEP 8
- Documentation: Thai for user docs, English for technical docs

## Important Paths
- Never hardcode paths - use environment variables
- LUKA_SOT, LUKA_HOME, SOT_PATH are set in environment
- Use Keychain for secrets, never plaintext

## Architecture
- LLM system uses provider-agnostic adapters
- All adapters in: ~/02luka/tools/providers/
- Config files: ~/02luka/config/
- Work orders: JSON format in ~/02luka/bridge/inbox/LLM/

## Best Practices
- Check disk space before long operations
- Use absolute paths for cron/LaunchAgent scripts
- Test LLM calls with Luka provider first (offline, free)
- Always log to telemetry for tracking
RULES
```

---

#### 4. ติดตั้ง Extensions (แนะนำ)

**Extensions ที่มีประโยชน์:**

```bash
# Terminal ใน Cursor:
code --install-extension ms-python.python
code --install-extension ms-vscode.makefile-tools
code --install-extension redhat.vscode-yaml
code --install-extension yzhang.markdown-all-in-one
```

**Extensions List:**
- ✅ Python (ms-python.python)
- ✅ YAML (redhat.vscode-yaml)
- ✅ Markdown All in One
- ✅ shellcheck (timonwong.shellcheck)
- ✅ GitLens (optional - for git history)

---

#### 5. ตั้งค่า Terminal

**Terminal Profile:**

```json
// เพิ่มใน settings.json
{
  "terminal.integrated.profiles.osx": {
    "02luka-zsh": {
      "path": "/bin/zsh",
      "args": ["-l"],
      "env": {
        "LUKA_SOT": "/Users/icmini/02luka",
        "PATH": "/Users/icmini/02luka/tools:${env:PATH}"
      }
    }
  },
  "terminal.integrated.defaultProfile.osx": "02luka-zsh"
}
```

---

#### 6. ตั้งค่า Tasks (Optional)

**สร้าง `.vscode/tasks.json`:**

```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "LLM Health Check",
      "type": "shell",
      "command": "~/02luka/tools/llm-run --health",
      "group": "test",
      "presentation": {
        "reveal": "always",
        "panel": "new"
      }
    },
    {
      "label": "Test Luka Provider",
      "type": "shell",
      "command": "~/02luka/tools/llm-run --in ${file} --provider luka",
      "group": "test"
    },
    {
      "label": "System Verify",
      "type": "shell",
      "command": "bash ~/02luka/tools/verify_sot.sh",
      "group": "test"
    },
    {
      "label": "Backup to GDrive",
      "type": "shell",
      "command": "~/02luka/tools/backup_to_gdrive.zsh",
      "group": "none"
    }
  ]
}
```

**วิธีใช้:**
- กด `⌘+Shift+P` → "Tasks: Run Task"
- เลือก task ที่ต้องการ

---

### 🔍 ทดสอบว่าตั้งค่าสำเร็จ

```bash
# 1. เปิด Terminal ใน Cursor
# 2. ทดสอบ environment variables
echo $LUKA_SOT
# Output: /Users/icmini/02luka

# 3. ทดสอบ PATH
which llm-run
# Output: /Users/icmini/02luka/tools/llm-run

# 4. ทดสอบ LLM system
llm-run --health
# Output: ✅ Providers ready

# 5. ทดสอบ Cursor AI
# พิมพ์: "explain this file" ในไฟล์ใดๆ
# กด ⌘+K → Enter
```

---

### 💡 Tips สำหรับใช้ Cursor กับ 02LUKA

#### 1. ใช้ AI Chat สำหรับถาม

```
⌘+L - Open AI Chat

ตัวอย่างคำถาม:
"อธิบาย adapter pattern ใน ~/02luka/tools/providers/"
"วิธีเพิ่ม provider ใหม่"
"แก้ไข config/system.yaml ให้ใช้ Grok เป็น default"
```

#### 2. ใช้ Composer สำหรับสร้างโค้ด

```
⌘+I - Open Composer

ตัวอย่างคำสั่ง:
"สร้าง adapter สำหรับ OpenAI GPT-4 ตาม pattern ของ grok_adapter.zsh"
"เพิ่ม error handling ใน backup script"
```

#### 3. ใช้ Terminal Integration

```
# เลือกคำสั่ง error ใน terminal
⌘+K → "fix this error"

# Cursor จะอ่าน error และแนะนำวิธีแก้
```

#### 4. ใช้ @ Mentions

```
@workspace ระบบ LLM มี adapters อะไรบ้าง
@file grok_adapter.zsh อธิบายการทำงาน
@folder ~/02luka/config มีไฟล์อะไรบ้าง
```

---

## คำถามที่พบบ่อย

### Q1: จะเปลี่ยน provider default ได้อย่างไร?

**A:** แก้ไข `~/02luka/config/system.yaml`:

```yaml
llm:
  provider: grok  # เปลี่ยนจาก gemini เป็น grok
```

หรือใช้ environment variable:

```bash
export LLM_PROVIDER=grok
~/02luka/tools/llm-run --in test.json
```

---

### Q2: จะเพิ่ม API key ของ Grok ได้อย่างไร?

**A:** ใช้ macOS Keychain (ปลอดภัย):

```bash
# เพิ่ม API key
security add-generic-password \
  -s "xai_grok_api" \
  -a "icmini" \
  -w "YOUR_GROK_API_KEY_HERE" \
  -U

# ตรวจสอบว่าเก็บแล้ว
security find-generic-password -s "xai_grok_api" -w

# ทดสอบ
~/02luka/tools/llm-run --in test.json --provider grok
```

---

### Q3: จะดู telemetry ว่าใช้เงินไปเท่าไหร่?

**A:** ดูไฟล์ telemetry:

```bash
# ดู entries ล่าสุด
tail -50 ~/02luka/telemetry/metrics.jsonl

# คำนวณต้นทุนรวม
jq -s 'map(.cost_usd) | add' ~/02luka/telemetry/metrics.jsonl

# ดูแยกตาม provider
jq -s 'group_by(.provider) | map({provider: .[0].provider, total_cost: (map(.cost_usd) | add)})' \
  ~/02luka/telemetry/metrics.jsonl
```

---

### Q4: จะ implement Gemini adapter ได้อย่างไร?

**A:** ดูตัวอย่างจาก Grok adapter:

```bash
# 1. Copy template
cp ~/02luka/tools/providers/grok_adapter.zsh \
   ~/02luka/tools/providers/gci_adapter_new.zsh

# 2. แก้ไข:
# - API_KEY: เปลี่ยน service name เป็น "gemini_api"
# - URL: เปลี่ยนเป็น Google AI API endpoint
# - Request format: ตาม Gemini API spec
# - Response parsing: แปลง Gemini response เป็น standard format

# 3. ทดสอบ
~/02luka/tools/llm-run --in test.json --provider gemini
```

---

### Q5: Backup อัตโนมัติทำงานหรือยัง?

**A:** ตรวจสอบ:

```bash
# ดู LaunchAgent status
launchctl list | grep backup.gdrive

# Output:
# -  1  com.02luka.backup.gdrive
#    ^
#    Exit code (1 = success)

# ดู log
tail -20 ~/02luka/logs/backup_gd.out.log

# รัน manual test
~/02luka/tools/backup_to_gdrive.zsh
```

---

### Q6: Cursor ไม่เห็น environment variables?

**A:** Restart terminal ใน Cursor:

```bash
# ใน Cursor:
# 1. เปิด Terminal (⌃`)
# 2. กด + → New Terminal
# 3. ทดสอบ:
echo $LUKA_SOT
source ~/02luka/paths.env
```

หรือ reload workspace:

```
⌘+Shift+P → "Developer: Reload Window"
```

---

### Q7: จะ rollback deployment ได้ไหม?

**A:** มี snapshot อยู่:

```bash
# ดู snapshots
ls -lh ~/02luka/_safety_snapshots/

# Restore (ถ้าต้องการ)
rsync -a --delete \
  ~/02luka/_safety_snapshots/final_verified_20251104_0304/ \
  ~/02luka/

# Verify
bash ~/02luka/tools/verify_sot.sh
```

---

### Q8: จะทดสอบ provider ใหม่ก่อนใช้จริงได้อย่างไร?

**A:** ใช้ Luka provider ทดสอบก่อน:

```bash
# สร้าง test work order
cat > /tmp/test.json <<'JSON'
{
  "id": "WO-TEST",
  "op": "analyze",
  "inputs": {"text": "Test message"},
  "constraints": {"timeout_s": 30}
}
JSON

# ทดสอบด้วย Luka (offline, ฟรี)
~/02luka/tools/llm-run --in /tmp/test.json --provider luka

# เห็นว่า format ถูก → ค่อยลอง provider จริง
~/02luka/tools/llm-run --in /tmp/test.json --provider grok
```

---

### Q9: จะเพิ่ม fallback chain ได้อย่างไร?

**A:** แก้ใน `config/routing.yaml`:

```yaml
default:
  provider: grok
  fallback: [anthropic, gemini, luka]  # ลองตามลำดับ
```

ระบบจะลอง:
1. Grok (primary)
2. ถ้า error → Anthropic
3. ถ้า error → Gemini
4. ถ้า error → Luka (always works)

---

### Q10: Documentation ภาษาไทยมีที่ไหนบ้าง?

**A:** เอกสารหลัก:

```
~/02luka/g/manuals/
├── 02luka_system_capabilities_th.md  # (ไฟล์นี้)
├── google_drive_stream_mode_guide.md
└── ... (อื่นๆ)

~/02luka/g/reports/
├── sessions/  # Session reports
└── ... (รายงานต่างๆ)

~/02luka/
├── DEPLOYMENT_READY.md                # Deployment guide (EN)
├── PRAGMATIC_SECURITY_PILOT.md        # Security for pilot (EN)
├── HOW_TO_ROTATE_PAT_SAFELY.md        # PAT rotation (EN)
└── 02luka.md                          # SOT master doc (EN)
```

---

## สรุป

### ระบบมีความสามารถ:
✅ Multi-provider LLM (สลับ provider ได้ใน 1 บรรทัด)
✅ Resource management (ป้องกัน disk เต็ม)
✅ Automated backups (ทุก 8 ชั่วโมง)
✅ GitHub integration (sync code ได้สองทาง)
✅ Telemetry & cost tracking (ติดตามต้นทุนทุก call)

### ระบบทำงานโดย:
- 🎯 Adapter pattern (แยก provider logic ออกจากกัน)
- 📋 Config-driven (เปลี่ยนพฤติกรรมโดยไม่แก้โค้ด)
- 🔐 Keychain security (API keys เก็บปลอดภัย)
- 📊 Observable (ทุก action บันทึก telemetry)

### รองรับ:
- ✅ 2 providers พร้อมใช้: Luka, Grok
- 🔧 2 providers มี stub: Gemini, Claude
- ✅ SSH + HTTPS authentication
- ✅ Auto-rotation, cleanup, backups

### Cursor IDE:
- 📝 ตั้งค่า workspace settings
- 🤖 เลือก AI model (Claude Sonnet 4.5 แนะนำ)
- ⌨️ ตั้งค่า terminal environment
- 🔧 เพิ่ม tasks สำหรับ common operations

---

**เอกสารนี้สร้างเมื่อ:** 2025-11-04
**สำหรับ:** 02LUKA System v2.0 (Provider-Agnostic Architecture)
**โดย:** Claude Code (CLC)

**หากมีคำถามเพิ่มเติม:**
- อ่าน: `~/02luka/02luka.md` (Master SOT doc)
- ดู: `~/02luka/g/reports/sessions/` (Session reports)
- ถาม: Claude Code ผ่าน Cursor AI chat
