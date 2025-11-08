# 02LUKA Puppeteer Tasks (GitHub UI)

ใช้ Chrome profile เดิมของเครื่อง (macOS) เพื่อกด GitHub UI โดยไม่ต้องใช้ PAT:
- เพิ่ม label `run-smoke`
- เติม prefix `[run-smoke]` ในชื่อ PR
- Re-run checks
- Create PR จากหน้า compare
- Close PR พร้อมคอมเมนต์

## ติดตั้ง

```bash
cd ~/02luka/tools/puppeteer
pnpm i || npm i
```

## ใช้งาน

```bash
# เพิ่ม label run-smoke
node run.mjs pr-label --url "https://github.com/<owner>/<repo>/pull/123" --label run-smoke

# เติม prefix [run-smoke] ที่หัวข้อ PR
node run.mjs pr-title-optin --url ".../pull/123" --prefix "[run-smoke]"

# Re-run checks
node run.mjs pr-rerun --url ".../pull/123"

# ปิด PR + คอมเมนต์
node run.mjs pr-close --url ".../pull/169" --comment "Closed in favor of #187"

# เปิด PR จาก compare URL
node run.mjs compare-open --compareUrl "https://github.com/<owner>/<repo>/compare/branchA...branchB" \
                          --title "ci: opt-in run-smoke" \
                          --body  "See CI_RELIABILITY_PACK.md"
```

## หมายเหตุ

- **macOS Chrome profile**: `~/Library/Application Support/Google/Chrome`
- ถ้าต้องการระบุเอง: เพิ่ม `--profile "/path/to/ChromeProfile"`
- ใช้ session ที่ login GitHub อยู่แล้ว (ไม่ต้อง PAT)

## ตัวอย่างกับ 02luka repo

```bash
# Re-run CI ของ PR #572 (lockfile fix)
node ~/02luka/tools/puppeteer/run.mjs pr-rerun --url "https://github.com/Ic1558/02luka/pull/572"

# เพิ่ม label run-smoke ให้ PR #197
node ~/02luka/tools/puppeteer/run.mjs pr-label --url "https://github.com/Ic1558/02luka/pull/197" --label run-smoke

# ปิด PR เก่า #169
node ~/02luka/tools/puppeteer/run.mjs pr-close --url "https://github.com/Ic1558/02luka/pull/169" \
  --comment "Closed in favor of #187"
```
