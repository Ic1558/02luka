# 02LUKA Quick Start Guide (ฉบับย่อ)

**เวอร์ชัน:** 2.0
**อัปเดต:** 2025-11-04

---

## 🚀 เริ่มต้นใช้งาน 3 คำสั่ง

```bash
# 1. ตรวจสุขภาพระบบ
~/02luka/tools/llm-run --health

# 2. ทดสอบ LLM (ออฟไลน์)
echo '{"id":"TEST","op":"analyze","inputs":{"text":"Hello"}}' > /tmp/test.json
~/02luka/tools/llm-run --in /tmp/test.json --provider luka

# 3. ดูผลลัพธ์
cat /tmp/test.json.result | jq .
```

---

## 💡 คำสั่งที่ใช้บ่อย

### LLM Operations
```bash
# เปลี่ยน provider
~/02luka/tools/llm-run --in wo.json --provider grok
~/02luka/tools/llm-run --in wo.json --provider luka

# Health check
~/02luka/tools/llm-run --health

# ดู telemetry
tail -20 ~/02luka/telemetry/metrics.jsonl
```

### System Operations
```bash
# Backup ทันที
~/02luka/tools/backup_to_gdrive.zsh

# ตรวจสอบ disk
df -h ~
du -sh ~/02luka

# ดู LaunchAgents
launchctl list | grep 02luka
```

### GitHub Operations
```bash
# ดึง code จาก repo
~/02luka/tools/sync_with_repos.zsh --from-repo

# เก็บ artifacts ไป commit
~/02luka/tools/sync_with_repos.zsh --to-repo

# Test SSH connection
ssh -T git@github.com
```

---

## 🔑 API Keys (เก็บใน Keychain)

```bash
# เพิ่ม Grok API key
security add-generic-password -s xai_grok_api -a icmini -w 'YOUR_KEY' -U

# ตรวจสอบว่ามี key
security find-generic-password -s xai_grok_api -w

# เพิ่ม Gemini API key (ถ้าจะใช้)
security add-generic-password -s gemini_api -a icmini -w 'YOUR_KEY' -U
```

---

## 📂 โครงสร้างไฟล์สำคัญ

```
~/02luka/
├── tools/
│   ├── llm-run                    # Main LLM runner
│   ├── providers/                 # Provider adapters
│   │   ├── luka_adapter.zsh      # ออฟไลน์ (พร้อมใช้)
│   │   ├── grok_adapter.zsh      # xAI (พร้อมใช้)
│   │   ├── gci_adapter.zsh       # Gemini (stub)
│   │   └── clc_adapter.zsh       # Claude (stub)
│   ├── backup_to_gdrive.zsh      # Backup script
│   └── sync_with_repos.zsh       # GitHub sync
├── config/
│   ├── system.yaml                # Global config
│   └── routing.yaml               # Provider routing
├── bridge/
│   └── inbox/LLM/                 # Work order queue
├── telemetry/
│   └── metrics.jsonl              # Usage logs
└── g/
    ├── manuals/                   # คู่มือ (ไฟล์นี้อยู่ที่นี่)
    └── reports/                   # รายงาน
```

---

## ⚙️ Config Files

### `~/02luka/config/system.yaml`
```yaml
llm:
  provider: gemini          # Default: luka, grok, gemini, anthropic
  timeout_s: 600
  max_input_mb: 10
  rate_limit_per_min: 10

disk:
  min_free_gb: 5
  telemetry_max_mb: 10
```

**แก้ไข:**
```bash
vim ~/02luka/config/system.yaml
# เปลี่ยน provider: gemini → provider: grok
```

---

## 🎯 ตั้งค่า Cursor IDE (ย่อ)

### 1. Workspace Settings
```bash
mkdir -p ~/02luka/.vscode
cat > ~/02luka/.vscode/settings.json <<'JSON'
{
  "terminal.integrated.env.osx": {
    "LUKA_SOT": "/Users/icmini/02luka",
    "PATH": "/Users/icmini/02luka/tools:${env:PATH}"
  }
}
JSON
```

### 2. Cursor Rules (Optional)
```bash
cat > ~/02luka/.cursorrules <<'RULES'
# 02LUKA Project
- SOT: ~/02luka
- Use zsh for scripts
- Store secrets in Keychain
- Test with luka provider first
RULES
```

### 3. เปิด Cursor
```bash
open -a Cursor ~/02luka
```

### 4. ทดสอบ
```bash
# ใน Cursor Terminal (⌃`):
echo $LUKA_SOT
llm-run --health
```

---

## 🔍 Troubleshooting

### Environment Variables ไม่โหลด
```bash
source ~/02luka/paths.env
echo $LUKA_SOT
```

### llm-run: command not found
```bash
export PATH="$HOME/02luka/tools:$PATH"
chmod +x ~/02luka/tools/llm-run
```

### Adapter returns error
```bash
# ดู log
cat /tmp/test.json.result | jq .error

# ตรวจ API key
security find-generic-password -s xai_grok_api -w
```

### Backup ไม่ทำงาน
```bash
# ตรวจ LaunchAgent
launchctl list | grep backup

# รัน manual
~/02luka/tools/backup_to_gdrive.zsh
```

---

## 📚 เอกสารเพิ่มเติม

**คู่มือเต็ม (ภาษาไทย):**
```bash
cat ~/02luka/g/manuals/02luka_system_capabilities_th.md
```

**คู่มืออื่นๆ:**
- `~/02luka/02luka.md` - Master SOT document
- `~/DEPLOYMENT_READY.md` - Deployment guide
- `~/02luka/PRAGMATIC_SECURITY_PILOT.md` - Security guide

**Session Reports:**
```bash
ls -lt ~/02luka/g/reports/sessions/
```

---

## 💰 ดูต้นทุนการใช้งาน

```bash
# ดูรายละเอียดการใช้งาน
tail -50 ~/02luka/telemetry/metrics.jsonl | jq .

# คำนวณต้นทุนรวม
jq -s 'map(.cost_usd) | add' ~/02luka/telemetry/metrics.jsonl

# แยกตาม provider
jq -s 'group_by(.provider) |
  map({
    provider: .[0].provider,
    calls: length,
    total_cost: (map(.cost_usd) | add)
  })' ~/02luka/telemetry/metrics.jsonl
```

---

## ⚡ Tips

### 1. ทดสอบด้วย Luka ก่อน
```bash
# Luka = ออฟไลน์, ฟรี, ทำงานเสมอ
~/02luka/tools/llm-run --in test.json --provider luka
```

### 2. ใช้ Auto-routing
```bash
# ระบบเลือก provider ตาม routing.yaml
~/02luka/tools/llm-run --in wo.json --auto-route
```

### 3. Monitor Disk Space
```bash
# ถ้า disk <5GB จะไม่ให้ run
df -h ~ | grep -E "Avail|disk3s1"
```

### 4. Cursor AI Chat
```
⌘+L - เปิด chat
"อธิบายไฟล์นี้"
"วิธีเพิ่ม provider ใหม่"
```

---

## 🎯 สรุปสั้นๆ

```
✅ Multi-provider LLM     → เปลี่ยนใน 1 บรรทัด
✅ Resource management    → Auto-cleanup disk
✅ Automated backups      → ทุก 8 ชั่วโมง
✅ GitHub integration     → SSH auth พร้อม
✅ Cost tracking          → บันทึกทุก call
```

**เริ่มใช้งาน:**
1. `llm-run --health` - ตรวจระบบ
2. ทดสอบด้วย `luka` provider
3. เพิ่ม Grok API key เมื่อพร้อม
4. เปิด Cursor IDE ใช้งานได้เลย

**พร้อมใช้งาน! 🚀**

---

**คู่มือฉบับเต็ม:** `02luka_system_capabilities_th.md`
**สร้างโดย:** Claude Code (CLC)
**วันที่:** 2025-11-04
