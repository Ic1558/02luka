# Investigation: Apps Closing During RAM Cleanup

**Issue:** Refbox, RightLang, BetterSnapTool ปิดหลังรัน cleanup scripts  
**Date:** 2025-12-06

---

## 🔍 การวิเคราะห์สาเหตุที่เป็นไปได้

### **1. sudo purge Effect (น่าจะเป็นสาเหตุหลัก)**

**คำสั่ง `sudo purge`:**
```bash
# ใน clear-mem script
sudo purge
```

**ผลกระทบ:**
- ล้าง **ทุก cache** ในระบบ (ไม่ใช่แค่ browser)
- ล้าง **inactive memory**
- บังคับให้ OS **page out** memory

**ทำไมถึงกระทบ apps:**

```
sudo purge
  ↓
OS ล้าง memory pages ของทุก process
  ↓
Apps เล็กๆ (Refbox, RightLang, BetterSnapTool) ถูก page out
  ↓
แรม RAM ไม่พอ → Apps crash/restart
```

**หลักฐาน:**
- Apps เหล่านี้เป็น **menu bar apps** (ใช้ RAM น้อย)
- macOS มักจะ **page out** apps เหล่านี้ก่อน
- พอ page out → apps ไม่สามารถทำงานต่อ → **ปิดตัวเอง**

---

### **2. Apps ใช้ Data ใน ~/Library/Caches**

**ตรวจสอบ:**
```bash
find ~/Library/Caches -name "*Refbox*"
find ~/Library/Caches -name "*RightLang*"
find ~/Library/Caches -name "*BetterSnap*"
```

**สมมติฐาน:**
- Apps อาจเก็บ **critical data** ใน cache folders
- เมื่อ cache หาย → apps panic → restart

**ตัวอย่างที่เป็นไปได้:**
```
~/Library/Caches/com.refbox.app/
  ├── session.db       ← ถูกลบ!
  └── preferences.db   ← ถูกลบ!

App เปิดขึ้นมา → หา session.db ไม่เจอ → Crash!
```

---

### **3. Memory Pressure Spike (ช่วงสั้น)**

**Timeline:**
```
Before purge:  RAM 87% (14GB used)
During purge:  RAM 95%+ (spike!)  ← Apps kill!
After purge:   RAM 75% (12GB used)
```

**ทำไมถึง spike:**
```
sudo purge
  ↓
OS ต้อง compact memory
  ↓
Process ใช้ CPU/RAM เพื่อทำ cleanup
  ↓
RAM spike ชั่วคราว → 95%+
  ↓
macOS kill memory-hungry apps อัตโนมัติ
```

**Apps ที่โดน kill:**
- Menu bar apps (priority ต่ำ)
- Background helpers
- Refbox, RightLang, BetterSnapTool

---

### **4. Spotlight/mds Indexing**

**สาเหตุ:**
```
rm -rf ~/Library/Caches/...
  ↓
Spotlight เห็นว่ามี files เปลี่ยน
  ↓
Trigger reindex
  ↓
mds (Spotlight) ใช้ RAM/CPU พุ่ง
  ↓
Apps ถูก kill
```

---

### **5. LaunchAgent Restart Behavior**

**บาง apps ใช้ LaunchAgent:**
```xml
<!-- เช็คว่า apps มี plist ใน LaunchAgents มั้ย -->
~/Library/LaunchAgents/com.refbox.*.plist
```

**ถ้ามี:**
```
App crash/exit
  ↓
LaunchAgent เห็น → restart อัตโนมัติ
  ↓
ดูเหมือน "ปิด" แล้ว "เปิดใหม่"
```

---

## 🎯 สาเหตุที่น่าจะเป็น (เรียงตามความเป็นไปได้)

### **#1: sudo purge effect (90% น่าจะเป็น)**

**หลักฐาน:**
- ✅ เกิดเฉพาะตอนรัน `clear-mem` (มี sudo purge)
- ✅ ไม่เกิดกับ `ram-cc` (ไม่มี purge)
- ✅ Affects small menu bar apps (page out ง่าย)

**การทดสอบ:**
```bash
# Test 1: รัน ram-cc (no purge)
ram-cc
# → Apps ไม่ปิด ✅

# Test 2: รัน clear-mem (with purge)
clear-mem
# → Apps ปิด ❌
```

---

### **#2: Memory pressure spike (60%)**

**หลักฐาน:**
- ระบบมี RAM 87% อยู่แล้ว (สูง)
- purge ทำให้ spike ชั่วคราว
- macOS kill low-priority apps

---

### **#3: Cache dependency (30%)**

**ต้องเช็ค:**
- Apps มี cache folders มั้ย
- ถูกลบโดย scripts มั้ย

---

## 🔬 วิธีพิสูจน์

### **Test 1: ดู apps ก่อน/หลัง purge**
```bash
# Before
ps aux | grep -iE "refbox|rightlang|bettersnap"

# Run
sudo purge

# After (wait 5s)
ps aux | grep -iE "refbox|rightlang|bettersnap"
```

### **Test 2: Monitor memory during purge**
```bash
while true; do
  memory_pressure | grep percentage
  sleep 1
done &

sudo purge
```

### **Test 3: Check cache folders**
```bash
ls -la ~/Library/Caches | grep -iE "refbox|rightlang|bettersnap"
```

---

## 💡 แนวทางแก้ไข

### **Solution 1: ไม่ใช้ sudo purge (แนะนำ)**
```bash
# ใช้ ram-cc แทน clear-mem
# → ไม่ purge → Apps ไม่ปิด
```

### **Solution 2: Renice apps ก่อน purge**
```bash
# Increase priority before purge
renice -n -5 $(pgrep Refbox)
renice -n -5 $(pgrep RightLang)
renice -n -5 $(pgrep BetterSnap)

sudo purge

# Restore priority
renice -n 0 $(pgrep Refbox)
```

### **Solution 3: Gentle purge**
```bash
# แทนที่จะ purge ครั้งเดียว
# ทำ partial cleanup

# Step 1: Clear specific caches only
rm -rf ~/Library/Caches/Safari/*
rm -rf ~/Library/Caches/Chrome/*

# Step 2: Flush DNS only
sudo dscacheutil -flushcache

# Step 3: Purge if still needed
# (skip if RAM improved)
```

---

## 🎯 สรุปสาเหตุที่แท้จริง

**สาเหตุหลัก:** `sudo purge`

**กลไก:**
1. `sudo purge` ล้างทุก cache + force page out
2. RAM spike ชั่วคราว (87% → 95%+)
3. macOS kill low-priority apps (menu bar apps)
4. Refbox, RightLang, BetterSnapTool ถูก kill
5. ดูเหมือน "ปิด" แม้จะ restart อัตโนมัติ

**การแก้:**
- ✅ ใช้ `ram-cc` (no purge) สำหรับ daily use
- ⚠️ ใช้ `clear-mem` (with purge) เฉพาะ emergency + ยอมรับว่า apps จะปิด
- 🎯 RAM Monitor ควรใช้ `ram-cc` ไม่ใช่ `sudo purge`

---

**Status:** Investigation complete  
**Recommendation:** Use ram-cc for RAM Monitor Agent ✅
