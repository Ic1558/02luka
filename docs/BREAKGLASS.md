# BREAKGLASS

## Emergency Bypass (ถ้า guard ขวางงานด่วน)

### ปิด Pre-push Hook ชั่วคราว
```bash
chmod -x .git/hooks/pre-push
```

**⚠️ สำคัญ:** บันทึกเหตุผลและสร้าง PR ล้างหนี้ตามหลัง

### เปิดใหม่หลังจบงาน
```bash
chmod +x .git/hooks/pre-push
make validate-zones
make proof
```

## Recovery (กรณีโครงสร้างเพี้ยน)

### 1. ตรวจสอบปัญหา
```bash
make validate-zones
make proof
```

### 2. แก้ไขตำแหน่งไฟล์
- Reports → ย้ายไป `g/reports/`
- Sessions → ย้ายไป `memory/<agent>/`

### 3. Refresh Catalogs
```bash
make boss-refresh
```

### 4. Verify
```bash
make validate-zones
make boss
```

## Rollback to v2.0
```bash
git checkout v2.0
make validate-zones
make boss-refresh
```
