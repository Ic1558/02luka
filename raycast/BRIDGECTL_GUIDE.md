# bridgectl.zsh - Gemini Bridge Controller

## 🎯 Purpose
**Authoritative lifecycle manager** สำหรับ Gemini Bridge service  
ควบคุมทุกอย่างผ่าน macOS LaunchAgent (`com.02luka.gemini_bridge`)

---

## 🔧 Commands & Use Cases

### 1️⃣ `start` - Start Bridge Service
**ทำอะไร**:
- Bootstrap LaunchAgent ใน macOS
- Kickstart service (restart ถ้ารันอยู่แล้ว)
- **3-way verification**: ตรวจสอบว่า PID match กันใน:
  - `launchctl` (macOS service manager)
  - `pgrep` (actual running process)
  - `health file` (bridge's own health marker)
- รอ 5 วินาทีเพื่อ verify ให้แน่ใจ

**เมื่อไหร่ใช้**:
- หลังจาก reboot เครื่อง (ถ้า launchd ไม่ auto-start)
- Bridge crash แล้วต้องการ restart
- หลังจากแก้ code `gemini_bridge.py` แล้วต้องการ reload

**Example**:
```bash
./tools/bridgectl.zsh start
# Output: "start ok (pid 12345)"
```

**Success**: Exit 0 + แสดง PID  
**Failure**: Exit 1 + แสดง logs จาก `/tmp/com.antigravity.bridge.*.log`

---

### 2️⃣ `stop` - Stop Bridge Service
**ทำอะไร**:
- Bootout LaunchAgent (unload from launchd)
- ส่ง SIGTERM ให้ processes ทั้งหมด
- รอ 1 วินาที
- Force kill ด้วย SIGKILL ถ้าจำเป็น

**เมื่อไหร่ใช้**:
- ก่อนแก้ code (เพื่อไม่ให้ bridge ทำงานระหว่าง debug)
- ต้องการ clean shutdown
- Bridge hang หรือ stuck

**Example**:
```bash
./tools/bridgectl.zsh stop
# (no output if success)
```

**Note**: ไม่ใช่แค่ kill process แต่ unload จาก launchd ด้วย → prevent auto-restart

---

### 3️⃣ `status` - Check Current State
**ทำอะไร**:
- แสดง LaunchAgent state (`state = running/exited`, PID)
- แสดง `pgrep` results (actual processes)
- อ่าน health file:
  - PID, timestamp, last output file
  - **Match verification**: เช็คว่า launchctl PID = pgrep PID = health PID หรือไม่

**เมื่อไหร่ใช้**:
- เช็คว่า bridge รันอยู่หรือเปล่า
- Debug PID mismatch (e.g., stale health file)
- Quick health check

**Example**:
```bash
./tools/bridgectl.zsh status

# Output:
# -- launchctl --
# state = running
# pid = 26126
# -- pgrep --
# 26126 /opt/homebrew/.../Python .../gemini_bridge.py
# -- health -- pid=26126 ts=2026-01-07T... match=yes last_output=test.md.summary.txt
```

**Match=yes** = ทุกอย่างสอดคล้องกัน ✅  
**Match=no** = มีปัญหา (e.g., stale lock, crashed process) ⚠️

---

### 4️⃣ `verify` - Full Verification Suite
**ทำอะไร**:
1. **Self-check**: รัน `gemini_bridge.py --self-check` (ตรวจ imports, configs)
2. **Smoke test**: 
   - สร้างไฟล์ test ใน `magic_bridge/inbox/`
   - รอ 30 วินาที
   - ตรวจว่ามี summary file ใน `outbox/` หรือไม่
3. **Git hygiene check**:
   - ตรวจว่า spool artifacts (inbox/outbox/processed) ไม่ได้ถูก track ใน git
   - ตรวจว่าไม่มี volatile artifacts (save_last.txt, hub/index.json) ใน index
   - ตรวจ `git status --porcelain` สำหรับ magic_bridge/

**เมื่อไหร่ใช้**:
- **ก่อน commit code** (เพื่อให้แน่ใจว่า bridge ทำงาน + repo clean)
- หลัง deploy เวอร์ชันใหม่
- CI/CD verification
- Debug ว่าทำไม bridge ไม่ process files

**Example**:
```bash
./tools/bridgectl.zsh verify

# Output:
# smoke ok: test_bridge_launchd_1767731572.md.summary.txt
# verify complete
```

**Exit 0** = ทุกอย่าง OK (self-check pass + smoke test pass + git clean)  
**Exit 1** = มีปัญหา (แสดง error + logs)

---

### 5️⃣ `ops-status` - Generate Ops Report
**ทำอะไร**:
- รัน `verify` command ก่อน (capture output + exit code)
- เช็ค git status (CLEAN/DIRTY)
- รันสคริปต์ Python inline ที่:
  - อ่าน health file
  - วิเคราะห์ telemetry (success/fail counts, latency stats)
  - นับไฟล์ใน spool directories
  - สร้าง Markdown report ที่ `g/reports/ops/ops_status.md`

**เมื่อไหร่ใช้**:
- **Production monitoring**: ต้องการ overview แบบครบถ้วน
- Debugging performance issues (ดู latency p95)
- ตรวจสอบ spool buildup (files stuck in inbox/outbox)
- CI/CD health checks (ดู exit code)

**Example**:
```bash
./tools/bridgectl.zsh ops-status

# Output: Markdown report แสดงทุกอย่าง (health, verify, telemetry, spool)
# Exit code: 0=✅, 1=❌verify, 2=❌dirty, 3=⚠️spool
```

**Machine-readable** = ใช้ exit code ใน automation ได้ (e.g., Telegram alerts)

---

### 6️⃣ `doctor` - Deep Diagnostics
**ทำอะไร**:
- วิเคราะห์ `atg_runner.jsonl` (Last 100 events) สรุป success/fail
- ตรวจสอบ Staleness ของ heartbeat ใน `bridge_health.json`
- นับจำนวนไฟล์ใน Inbox/Outbox
- **ให้ Verdict**: รายงานสถานะภาพรวม (Stable/Warning/Critical)

**เมื่อไหร่ใช้**:
- เมื่อต้องการรู้ว่า "ทำไม" bridge ถึงไม่ทำงาน (หา root cause)
- ตรวจสอบว่า telemetry ยังบันทึกข้อมูลอยู่ไหม
- เช็คสุขภาพแบบละเอียดกว่า `status` แต่ไม่ต้องรัน `verify` นวนๆ

**Example**:
```bash
./tools/bridgectl.zsh doctor

# Output:
# Service Mode:   Daemon (LaunchAgent)
# Health File:    Found
# Last Heartbeat: 2026-01-10T...
# Telemetry:      31 success, 0 failed (last 100 events)
# Spool Status:   Inbox=15, Outbox=39
# ---------------------------------------------------
# VERDICT:        ✅ STABLE
```

---

## 🚦 Service Modes: Ephemeral vs. Daemon

เพื่อให้เข้าใจความแตกต่างในการรัน bridge:

| Mode | Command | Persistence | Use Case |
|------|---------|-------------|----------|
| **Ephemeral** | `verify` | ชั่วคราว (รันเสร็จปิด) | ทดสอบ logic, Smoke test ก่อน commit |
| **Daemon** | `start` | ถาวร (LaunchAgent) | รันเป็นเบื้องหลังตลอดเวลาเพื่อประมวลผลจริง |

> [!IMPORTANT]
> - `verify` จะ spawn process ขึ้นมาทดสอบแล้ว **shutdown** เองเมื่อจบงาน (Behavior ปกติ)
> - `status` อาจรายงานว่า `pid=missing` หากคุณไม่ได้สั่ง `start` ไว้ แต่ `verify` ยังทำงานได้ปกติ

---

## 🎯 ประโยชน์หลัก

### 1. **Single point of control**
ไม่ต้องจำว่าจะ start/stop ยังไง  
→ แค่ `./tools/bridgectl.zsh start|stop`

### 2. **Three-way PID verification**
ป้องกัน:
- Stale lock files (PID in health file แต่ process ตายแล้ว)
- Multiple instances (launchd PID ≠ pgrep PID)
- Ghost processes

### 3. **Git hygiene enforcement**
ป้องกัน:
- Commit transient files (test files, summaries) โดยไม่ตั้งใจ
- Track volatile artifacts (save_last.txt, hub/index.json)
- Dirty repo state

### 4. **Smoke test automation**
แทนที่การ manual test:
```bash
# ❌ แบบเก่า (manual)
echo "test" > magic_bridge/inbox/test.md
sleep 30
ls magic_bridge/outbox/

# ✅ แบบใหม่ (automated)
./tools/bridgectl.zsh verify
```

### 5. **Ops-grade observability**
ได้ comprehensive report ที่รวม:
- Health metrics
- Verification status
- Telemetry stats (avg/p95 latency)
- Spool monitoring
→ **ไม่ต้อง manually เช็คหลายที่**

---

## 🔗 Relationship กับ Raycast Scripts

```
bridgectl.zsh (Backend Logic)
    ↓
bridge-status.sh (Raycast Wrapper)
    ├─→ Calls: bridgectl.zsh start
    ├─→ Calls: bridgectl.zsh stop
    ├─→ Calls: bridgectl.zsh status
    ├─→ Calls: bridgectl.zsh verify
    └─→ Calls: bridgectl.zsh ops-status
```

**Raycast scripts = UI layer**  
**bridgectl.zsh = Core logic**

---

## 📊 Comparison: bridgectl.zsh vs Raycast Scripts

| Feature | bridgectl.zsh | Raycast Scripts |
|---------|---------------|-----------------|
| **Purpose** | Bridge lifecycle control | Quick access shortcuts |
| **Use in** | Terminal, CI/CD, automation | Raycast hotkeys |
| **Exit codes** | ✅ Machine-readable | ✅ (ops-status.sh only) |
| **Service control** | ✅ Full control (start/stop/verify) | Via wrapper (bridge-status.sh) |
| **Ops reporting** | ✅ Generate + exit codes | Display only |
| **Standalone** | ✅ Complete | Depends on bridgectl/tools |

---

## 🎓 When to Use What?

| Scenario | Use This |
|----------|----------|
| Start/stop bridge service | `bridgectl.zsh start/stop` |
| Quick health check | `bridgectl.zsh status` OR Raycast hotkey |
| Pre-commit verification | `bridgectl.zsh verify` |
| Production monitoring | `bridgectl.zsh ops-status` |
| CI/CD automation | `bridgectl.zsh verify && bridgectl.zsh ops-status` |
| Quick snapshot for AI | Raycast `atg-snapshot.command` |
| Hotkey access | Raycast scripts (Ctrl+A, Ctrl+B, Ctrl+O) |

---

## 💡 Pro Tips

1. **Alias for convenience**:
   ```bash
   alias bctl='~/02luka/tools/bridgectl.zsh'
   bctl status
   bctl verify
   ```

2. **CI/CD integration**:
   ```bash
   # In GitHub Actions / Jenkins
   ./tools/bridgectl.zsh verify || exit 1
   ./tools/bridgectl.zsh ops-status
   ```

3. **Monitoring script**:
   ```bash
   # Cron job every 5 min
   */5 * * * * cd ~/02luka && ./tools/bridgectl.zsh ops-status | grep "❌" && notify-send "Bridge alert"
   ```

4. **Debug workflow**:
   ```bash
   # 1. Stop bridge
   ./tools/bridgectl.zsh stop
   
   # 2. Edit code
   vim gemini_bridge.py
   
   # 3. Start + verify
   ./tools/bridgectl.zsh start
   ./tools/bridgectl.zsh verify
   ```

---

## Summary

**bridgectl.zsh = Swiss Army Knife for Gemini Bridge**

✅ Lifecycle management (start/stop)  
✅ Health verification (3-way PID check)  
✅ Smoke testing (automated file processing test)  
✅ Git hygiene enforcement (prevent dirty commits)  
✅ Ops-grade reporting (health + telemetry + spool)  
✅ Machine-readable exit codes (automation-friendly)

**คิดง่ายๆ**: ถ้า Gemini Bridge เป็นรถ → `bridgectl.zsh` คือ dashboard + control panel ที่มีครบทุกอย่าง (สตาร์ท, ดับ, เช็คสภาพ, วิ่งทดสอบ, ดู metrics) 🚗📊
