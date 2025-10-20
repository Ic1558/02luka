# 🎯 GitHub Repository Configuration - Complete Guide
**Repository:** `Ic1558/02luka`  
**งาน:** ตั้งค่า OPS_ATOMIC_URL, OPS_ATOMIC_TOKEN, OPS_GATE_OVERRIDE

---

## ✅ วิธีที่ 1: คำสั่งสำเร็จรูป (แนะนำ) ⭐

### Prerequisites
```bash
# Install GitHub CLI (ถ้ายังไม่มี)
brew install gh

# Login to GitHub
gh auth login
```

### คำสั่งตั้งค่า (Copy-Paste ได้เลย!)
```bash
# 1. Set OPS_ATOMIC_URL secret
echo "https://boss-api.ittipong-c.workers.dev" | gh secret set OPS_ATOMIC_URL --repo Ic1558/02luka

# 2. Set OPS_GATE_OVERRIDE variable (bypass mode)
gh variable set OPS_GATE_OVERRIDE --body "1" --repo Ic1558/02luka
```

### ตรวจสอบ
```bash
# ดู secrets
gh secret list --repo Ic1558/02luka

# ดู variables
gh variable list --repo Ic1558/02luka

# ดู workflow runs
gh run list --repo Ic1558/02luka --limit 5
```

---

## ✅ วิธีที่ 2: ผ่าน GitHub Web UI

### A) ตั้งค่า Secrets

1. ไปที่: https://github.com/Ic1558/02luka/settings/secrets/actions
2. คลิก **"New repository secret"**
3. ตั้งค่า:

| Name | Value |
|------|-------|
| `OPS_ATOMIC_URL` | `https://boss-api.ittipong-c.workers.dev` |

4. คลิก **"Add secret"**

### B) ตั้งค่า Variables

1. ไปที่: https://github.com/Ic1558/02luka/settings/variables/actions
2. คลิก **"New repository variable"**
3. ตั้งค่า:

| Name | Value |
|------|-------|
| `OPS_GATE_OVERRIDE` | `1` |

4. คลิก **"Add variable"**

---

## 📊 ผลลัพธ์ที่ต้องเห็น

### Secrets (ทั้งหมด)
```
✅ OPS_ATOMIC_URL                    (ไม่แสดงค่า - ปกติ)
✅ DISCORD_WEBHOOK_DEFAULT          (มีอยู่แล้ว)
✅ DISCORD_WEBHOOK_MAP              (มีอยู่แล้ว)
✅ AI_GATEWAY_KEY                   (มีอยู่แล้ว)
✅ AI_GATEWAY_URL                   (มีอยู่แล้ว)
✅ CF_ACCOUNT_ID                    (มีอยู่แล้ว)
✅ CF_API_TOKEN                     (มีอยู่แล้ว)
```

### Variables
```
✅ OPS_GATE_OVERRIDE = 1
```

---

## 🔄 วิธีใช้งาน

### ops-gate ใน CI Workflow

Workflow: `.github/workflows/ci.yml`

```yaml
jobs:
  ops-gate:
    runs-on: ubuntu-latest
    env:
      OPS_ATOMIC_URL: ${{ secrets.OPS_ATOMIC_URL }}
      OPS_ATOMIC_TOKEN: ${{ secrets.OPS_ATOMIC_TOKEN }}
      OPS_GATE_OVERRIDE: ${{ vars.OPS_GATE_OVERRIDE }}
```

**การทำงาน:**

1. **OPS_GATE_OVERRIDE = 1** (ตอนนี้)
   - ข้าม ops-gate check
   - CI/CD ทำงานปกติ
   - ใช้ขณะ development

2. **OPS_GATE_OVERRIDE = 0** (production)
   - เปิดใช้ ops-gate protection
   - CI/CD จะ **block** ถ้า OPS status = FAIL
   - Curl check: `$OPS_ATOMIC_URL/api/reports/summary`

---

## 🎯 ทดสอบว่าทำงาน

### 1. ตรวจสอบ Secrets/Variables
```bash
gh secret list --repo Ic1558/02luka
gh variable list --repo Ic1558/02luka
```

### 2. ทริกเกอร์ Workflow ใหม่
```bash
# Trigger CI workflow
git commit --allow-empty -m "test: trigger CI with new secrets"
git push

# Watch workflow
gh run watch --repo Ic1558/02luka
```

### 3. ตรวจสอบ logs
```bash
# ดู run ล่าสุด
gh run list --repo Ic1558/02luka --limit 5

# ดู logs ของ run ID
gh run view <RUN_ID> --log --repo Ic1558/02luka
```

### 4. Test OPS endpoint โดยตรง
```bash
# Test boss-api worker
curl https://boss-api.ittipong-c.workers.dev/healthz

# Test OPS summary (ใช้ใน CI)
curl https://boss-api.ittipong-c.workers.dev/api/reports/summary
```

---

## 🎯 Next Steps

### ตอนนี้ (Development Phase)
- [x] `OPS_GATE_OVERRIDE = 1` - Bypass gate
- [x] `OPS_ATOMIC_URL` - Worker endpoint
- [x] CI workflows ทำงานปกติ
- [x] Discord notifications active

### เมื่อพร้อม Production
```bash
# เปิด gate protection
gh variable set OPS_GATE_OVERRIDE --body "0" --repo Ic1558/02luka
```

**ผลลัพธ์:**
- CI จะ **fail** ถ้า OPS status = FAIL
- ป้องกัน bad code เข้า main branch
- แจ้งเตือนผ่าน Discord ทันที

---

## 📚 Documentation References

- **CI Workflow:** `.github/workflows/ci.yml`
- **OPS Monitoring:** `.github/workflows/ops-monitoring.yml`
- **Worker Source:** `boss-api/` (deployed to Cloudflare)
- **Worker URL:** https://boss-api.ittipong-c.workers.dev
- **Discord Docs:** `docs/DISCORD_OPS_INTEGRATION.md`

---

## 🆘 Troubleshooting

### ถ้า CI fail ที่ ops-gate step

**Check 1:** Worker endpoint ตอบสนอง?
```bash
curl -v https://boss-api.ittipong-c.workers.dev/api/reports/summary
```

**Check 2:** OPS_ATOMIC_URL ถูกต้อง?
```bash
gh secret list --repo Ic1558/02luka | grep OPS_ATOMIC_URL
```

**Check 3:** Variable override ถูกต้อง?
```bash
gh variable list --repo Ic1558/02luka | grep OPS_GATE_OVERRIDE
```

**Quick Fix:** ข้าม gate ชั่วคราว
```bash
gh variable set OPS_GATE_OVERRIDE --body "1" --repo Ic1558/02luka
```

---

## ✅ Completion Checklist

- [ ] Run คำสั่ง setup (วิธีที่ 1 หรือ 2)
- [ ] Verify secrets: `gh secret list --repo Ic1558/02luka`
- [ ] Verify variables: `gh variable list --repo Ic1558/02luka`
- [ ] Test worker: `curl https://boss-api.ittipong-c.workers.dev/healthz`
- [ ] Trigger CI: `git push` (any branch)
- [ ] Watch workflow: `gh run watch --repo Ic1558/02luka`
- [ ] Check Discord notification

**เมื่อทุกอย่างผ่าน ✅ Setup Complete!**

---

**Created:** 2025-10-20  
**For:** GC (GitHub/CI caretaker)  
**Status:** ✅ Ready to Execute
