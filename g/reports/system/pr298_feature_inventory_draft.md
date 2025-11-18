# PR #298 Feature Verification Draft

**Date:** 2025-11-18T05:03:48+0700  
**Branches:** main = main, PR = codex/add-trading-journal-csv-importer  

---

## 1. Feature Verification (Condition #1)

### 1.1 Files Changed (high level)

```bash
git diff --stat origin/main...origin/codex/add-trading-journal-csv-importer
```

(ให้รันเองใน Terminal แล้วคัดลอกผลตรงนี้)

### 1.2 Dashboard.js Signals (from diff)

**Search: "csv"**

```
<no matches>
```

**Search: "followup"**

```
<no matches>
```

**Search: "trade"**

```
<no matches>
```

**Search: "journal"**

```
<no matches>
```

➡ TODO (คน): สรุปรายการ feature จริงจาก diff:
- [ ] CSV import / trading journal UI components:
- [ ] API / data handlers:
- [ ] Timeline / follow-up widgets:
- [ ] อื่น ๆ:

---

## 2. Feature Inventory (Condition #2)

> ให้เปิดไฟล์เหล่านี้ใน Cursor แล้วเติมด้วยมือ:
>
> - g/apps/dashboard/dashboard.js (ดู diff คู่กับ main)
> - g/apps/dashboard/data/followup.json (ดู /Users/icmini/02luka/g/reports/system/pr298_followup_json_raw.json ถ้าไฟล์ใหม่)
>
> แนะนำให้ทำตารางแบบนี้:

| Feature | File / Function | Description | Notes |
|--------|-----------------|-------------|-------|
|        |                 |             |       |
|        |                 |             |       |

---

## 3. Dashboard Integration Plan (Condition #3)

> ใช้ข้อมูลจาก diff ใน /Users/icmini/02luka/g/reports/system/pr298_dashboard_diff_raw.txt แล้วเติมแผนรวมโค้ดจริง:

### 3.1 Integration Strategy

- Base SOT: main (dashboard v2.2.0)
- PR adds:
  - [ ] New components:
  - [ ] New state / hooks:
  - [ ] New API calls:
  - [ ] New DOM hooks:

### 3.2 Integration Steps (suggested)

1. [ ] แยก block ที่เกี่ยวกับ CSV importer ออกจาก diff
2. [ ] แยก block ที่เกี่ยวกับ followup timeline / metrics
3. [ ] Merge ทีละ feature เข้า main dashboard.js:
   - [ ] Feature A:
   - [ ] Feature B:
4. [ ] ลบ/ลด duplication ที่ซ้ำกับ main (ถ้ามี)

---

## 4. Testing Strategy (Condition #4)

### 4.1 Automated (ถ้ามี test suite)

> แทนคำสั่งด้านล่างด้วยของจริงของโปรเจกต์นี้ (เช่น `npm test`, `pnpm test` ฯลฯ)

```bash
# Example only – เปลี่ยนเป็นของจริงในโปรเจกต์
# npm test
# npm run lint
# npm run build
```

Checklist:
- [ ] Test suite ผ่านทั้งหมด
- [ ] ไม่มี warning ใหม่ใน CI

### 4.2 Manual QA Checklist

- [ ] Dashboard load ได้ (ไม่มี error ใน console)
- [ ] CSV import flow:
  - [ ] เลือกไฟล์ CSV แล้ว parse ถูก
  - [ ] แสดงรายการ trade ถูกต้อง
- [ ] Follow-up / timeline:
  - [ ] Data load ถูกต้องจาก followup.json
  - [ ] Filter / sort ทำงานได้
- [ ] ไม่มี regression กับ feature เดิม (service cards, health view ฯลฯ)

---

## 5. Verdict After Verification

(ให้ Boss / reviewer เติมเอง)

- [ ] ✅ Features verified against PR #298
- [ ] ✅ Integration plan confirmed
- [ ] ✅ Tests (auto/manual) ผ่าน
- [ ] 🧾 Ready to proceed with migration branch (PR #298 successor)

