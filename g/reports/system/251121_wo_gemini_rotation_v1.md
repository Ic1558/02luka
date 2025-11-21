# Work Order: WO-20251121-GEMINI-ROTATION-v1

**Title**: Gemini API Key Rotation & Validation Pipeline  
**Priority**: P0 (Security – Critical)  
**Owner**: Liam (Antigravity)  
**Requester**: Boss  
**Date**: 2025-11-21  
**Status**: READY FOR EXECUTION

---

## 🎯 Objective

Rotate the leaked Gemini API key, update environment files, validate functionality, and log via AP/IO v3.1 strictly under V4 enforcement.

---

## 🛠 Scope

1. Revoke existing leaked keys (Boss action)
2. Provision two new keys (Boss action):
   - `02luka-prod-gemini-20251121`
   - `02luka-dev-gemini-20251121`
3. Update all `.env.local` files (Liam automated)
4. Validate using automated test suite (Liam automated)
5. Log AP/IO event (Liam automated)
6. Run leak scanner (Liam automated)
7. Confirm clean state (Liam automated)

---

## 📋 Prerequisites

**Boss Must Complete First**:

1. **Go to**: [Google Cloud Console](https://console.cloud.google.com/) → APIs & Services → Credentials
2. **Revoke ALL old keys**:
   - `AIzaSy...wk8Q` (current, Google-confirmed leaked)
   - `AIzaSyC4y7cc_Xy6Sjtg_RgBUX1CBkk-G3fnv5I` (old, exposed in Git)
   - Any other Gemini keys from this project
3. **Create 2 new API keys**:
   - Name: `02luka-prod-gemini-20251121`
   - Name: `02luka-dev-gemini-20251121`
4. **Provide keys to Liam** in format:
   ```
   prod = "AIzaSyXXXX..."
   dev  = "AIzaSyYYYY..."
   ```

---

## 🔧 Execution Steps (Liam-Automated)

### STEP 1: Backup Current Environment

```bash
# Backup existing .env.local files
cp /Users/icmini/LocalProjects/02luka_local_g/.env.local \
   /Users/icmini/LocalProjects/02luka_local_g/.env.local.bak.20251121

# Log backup
echo "✅ Backup created: .env.local.bak.20251121"
```

**Exit Criteria**: Backup file exists and is readable

---

### STEP 2: Update Environment Files

```bash
# Update production .env.local
echo "GEMINI_API_KEY=\"<NEW_PROD_KEY>\"" > /Users/icmini/LocalProjects/02luka_local_g/.env.local

# Verify write
cat /Users/icmini/LocalProjects/02luka_local_g/.env.local
```

**Exit Criteria**: 
- File contains new key
- File is gitignored
- No syntax errors

---

### STEP 3: Run Key Health Check

```bash
cd /Users/icmini/02luka
source venv/bin/activate
./g/tools/test_gemini_connector.sh
```

**Expected Output**:
```
✅ Import successful
✅ Connector available: True
   Model: gemini-2.5-flash
✅ API call successful (no 403/429 errors)
```

**Exit Criteria**: All tests pass, no quota/auth errors

---

### STEP 4: Run Leak Scanner

```bash
cd /Users/icmini/02luka
./g/tools/scan_leaked_gemini_key.zsh
```

**Expected Output**:
```
✅ No leaked keys found in tracked files
Status: SAFE (key only in .env.local)
```

**Exit Criteria**: Scanner returns exit code 0 (no leaks found)

---

### STEP 5: Log AP/IO Event

```python
# Log to g/ledger/ap_io_v31.jsonl
{
  "event_type": "gemini_key_rotated",
  "timestamp": "2025-11-21T23:24:40+07:00",
  "status": "success",
  "keys_revoked": "all_previous",
  "keys_created": ["prod_20251121", "dev_20251121"],
  "scanner_status": "clean",
  "validator": "Liam-ATG",
  "version": "v3.1"
}
```

**Exit Criteria**: Event logged to AP/IO ledger

---

### STEP 6: Final Verification

**Checklist**:
- [x] Old keys revoked (Boss confirmed)
- [ ] New keys created (Boss confirmed)
- [ ] `.env.local` updated
- [ ] Connector test passed
- [ ] Leak scanner clean
- [ ] AP/IO event logged
- [ ] System operational

**Final Output**:
```
WO-20251121-GEMINI-ROTATION-v1
Status: SUCCESS
Scanner: CLEAN
Env Update: OK
API Validation: OK
Ledger Event: WRITTEN
Notes: System restored to secure operational state.
```

---

## 🚨 Rollback Plan

### Option A: Immediate Revert (2 minutes)

```bash
# Restore previous .env.local
cp /Users/icmini/LocalProjects/02luka_local_g/.env.local.bak.20251121 \
   /Users/icmini/LocalProjects/02luka_local_g/.env.local

# Log rollback event
echo '{"event_type":"gemini_key_rotate_reverted","timestamp":"<now>"}' >> g/ledger/ap_io_v31.jsonl

# Verify
./g/tools/test_gemini_connector.sh
```

### Option B: Full Cleanup (10 minutes)

1. Delete new keys at Google Cloud Console
2. Remove partial logs from AP/IO ledger
3. Reset connector state
4. Full scan re-run
5. Restore from backup

---

## 📊 Success Criteria

**Must Pass**:
- ✅ No 403 errors from Gemini API
- ✅ Leak scanner returns 0 matches
- ✅ Connector test passes
- ✅ AP/IO event logged
- ✅ `.env.local` gitignored
- ✅ Backup created

**Optional**:
- Update GMX/Liam personas with new key rotation date
- Schedule next rotation (90 days)
- Enable quota alerts

---

## 🔐 Security Notes

**Key Storage**:
- ✅ Keys only in `.env.local` (gitignored)
- ✅ No keys in tracked files
- ✅ No keys in logs
- ✅ Backup files also gitignored

**Validation**:
- Leak scanner runs automatically
- Pre-commit hook available (optional)
- Regular rotation recommended (90 days)

---

## 📝 Acceptance Criteria

**Work Order Complete When**:
1. Boss confirms old keys revoked
2. Boss provides new keys
3. Liam updates `.env.local`
4. All tests pass
5. Leak scanner clean
6. AP/IO event logged
7. System operational

---

## 🚀 Ready to Execute

**Boss**: Please provide the two new Gemini API keys in this format:

```
prod = "AIzaSyXXXX..."
dev  = "AIzaSyYYYY..."
```

Once received, Liam will immediately execute all automated steps under V4 safeguards.

---

**Work Order ID**: WO-20251121-GEMINI-ROTATION-v1  
**Created**: 2025-11-21T23:24:40+07:00  
**Agent**: Liam (Antigravity)  
**Protocol**: AP/IO v3.1 + V4 Enforcement
