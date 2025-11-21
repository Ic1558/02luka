# Gemini Rotation Executor Manual

**Script**: `g/tools/gemini_rotate_key.zsh`  
**Purpose**: Safely rotate Gemini API keys with automatic backup and rollback  
**Created**: 2025-11-21  
**Agent**: Liam (Antigravity)

---

## Overview

The Gemini Rotation Executor automates the process of rotating API keys while ensuring safety through:
- Automatic backup before changes
- Validation of new key format
- Connector testing after rotation
- Automatic rollback on failure
- Detailed logging

---

## Prerequisites

1. **New API Key**: Boss must create new key at [Google Cloud Console](https://console.cloud.google.com/)
2. **Virtual Environment**: `venv` must be set up in `/Users/icmini/02luka`
3. **Permissions**: Write access to `.env.local` and ledger files

---

## Usage

### Basic Usage

```bash
cd /Users/icmini/02luka
GEMINI_API_KEY_NEW="AIzaSy..." ./g/tools/gemini_rotate_key.zsh
```

### With Rotation Reason

```bash
ROTATION_REASON="leak_detected" GEMINI_API_KEY_NEW="AIzaSy..." ./g/tools/gemini_rotate_key.zsh
```

### Keep Backup File

```bash
KEEP_BACKUP=true GEMINI_API_KEY_NEW="AIzaSy..." ./g/tools/gemini_rotate_key.zsh
```

---

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `GEMINI_API_KEY_NEW` | **Yes** | - | New API key to install |
| `ROTATION_REASON` | No | `manual_rotation` | Reason for rotation: `manual_rotation`, `leak_detected`, `scheduled_90d` |
| `KEEP_BACKUP` | No | `false` | Set to `true` to keep backup file |

---

## Execution Flow

### Step 1: Validation
- Check `GEMINI_API_KEY_NEW` is set
- Validate key format (must start with "AIza")

### Step 2: Backup
- Create timestamped backup: `.env.local.bak.YYYYMMDD_HHMMSS`
- Extract old key fingerprint (first 6 + last 4 chars)

### Step 3: Key Replacement
- Write new key to `.env.local`
- Extract new key fingerprint

### Step 4: Testing
- Run `./g/tools/test_gemini_connector.sh`
- Run `python g/tools/check_quota.py` (optional)
- If either fails → **ROLLBACK**

### Step 5: Logging
- Append entry to `g/ledger/gemini_rotation_log.jsonl`
- Log format:
  ```json
  {
    "timestamp": "2025-11-21T23:46:36Z",
    "old_key_fingerprint": "AIzaSy...wk8Q",
    "new_key_fingerprint": "AIzaSy...n0lA",
    "reason": "manual_rotation",
    "status": "success",
    "validator": "Liam-ATG"
  }
  ```

### Step 6: Cleanup
- Remove backup file (unless `KEEP_BACKUP=true`)

---

## Error Handling

### Validation Errors

**Error**: `GEMINI_API_KEY_NEW environment variable not set`  
**Solution**: Set the variable before running

**Error**: `Invalid API key format`  
**Solution**: Ensure key starts with "AIza"

### Test Failures

**Error**: `Connector test FAILED`  
**Action**: Automatic rollback to previous key  
**Log**: Test output saved to `/tmp/gemini_test.log`

### Rollback Process

1. Copy backup file back to `.env.local`
2. Display error message
3. Exit with non-zero code
4. Backup file preserved for investigation

---

## Integration with GMX/Liam

### GMX Role

GMX detects when rotation is needed:
1. **Leak Detection**: AP/IO event `gemini_key_leaked`
2. **Age Policy**: Last rotation > 90 days
3. **Auth Failures**: Persistent 403 errors

GMX creates Work Order: `g/wo_specs/WO-YYYYMMDD-GEMINI-ROTATION.json`

### Liam Role

Liam executes rotation:
1. Receives WO from GMX
2. Waits for Boss to provide `GEMINI_API_KEY_NEW`
3. Calls `gemini_rotate_key.zsh`
4. Logs result to:
   - `g/ledger/gemini_rotation_log.jsonl`
   - `g/reports/system/GEMINI_KEY_ROTATION_<timestamp>.md`
5. Notifies Boss of success/failure

### Boss Role

Boss controls key creation:
1. Go to Google Cloud Console
2. Create new Gemini API key
3. Provide key to Liam (via secure channel)
4. Wait for rotation confirmation
5. Delete old key from Google Cloud Console

---

## Log Files

### Rotation Log
**Path**: `g/ledger/gemini_rotation_log.jsonl`  
**Format**: JSONL (one entry per rotation)  
**Retention**: Permanent (for audit trail)

### Test Logs
**Path**: `/tmp/gemini_test.log` (temporary)  
**Purpose**: Debugging failed rotations

---

## Security Notes

1. **No Full Keys in Logs**: Only fingerprints logged (first 6 + last 4 chars)
2. **Backup Files**: Contain full keys, must be gitignored
3. **Environment Variables**: Keys passed via env vars, not command line args
4. **Automatic Cleanup**: Backups deleted by default (unless `KEEP_BACKUP=true`)

---

## Troubleshooting

### Issue: Rotation fails but rollback works
**Cause**: New key may be invalid or not activated yet  
**Solution**: Wait a few minutes, verify key in Google Cloud Console, try again

### Issue: Connector test passes but quota check fails
**Cause**: Model name mismatch in `check_quota.py`  
**Impact**: Not critical, rotation still succeeds  
**Solution**: Update `check_quota.py` to use `gemini-2.5-flash`

### Issue: Backup file not deleted
**Cause**: `KEEP_BACKUP=true` was set  
**Solution**: Manually delete: `rm /Users/icmini/LocalProjects/02luka_local_g/.env.local.bak.*`

---

## Examples

### Example 1: Manual Rotation

```bash
# Boss creates new key at Google Cloud Console
# Boss provides key to Liam

cd /Users/icmini/02luka
GEMINI_API_KEY_NEW="AIzaSyNEWKEY123..." ./g/tools/gemini_rotate_key.zsh
```

**Output**:
```
=== Gemini API Key Rotation Executor ===

✅ New API key validated

📦 Backing up current .env.local...
✅ Backup created: .env.local.bak.20251121_234636

🔄 Rotating key...
  Old: AIzaSy...n0lA (len=39)
  New: AIzaSy...KEY1 (len=39)

✅ Key updated in .env.local

🧪 Testing connector...
✅ Connector test passed

🧪 Testing quota (optional)...
⚠️  Quota check failed (may be model mismatch, not critical)

📝 Logging rotation...
✅ Rotation logged to: g/ledger/gemini_rotation_log.jsonl

🧹 Cleaning up backup...
✅ Backup removed

=== Rotation Complete ===

✅ SUCCESS
```

### Example 2: Leak-Triggered Rotation

```bash
ROTATION_REASON="leak_detected" \
KEEP_BACKUP=true \
GEMINI_API_KEY_NEW="AIzaSyNEWKEY123..." \
./g/tools/gemini_rotate_key.zsh
```

### Example 3: Scheduled 90-Day Rotation

```bash
ROTATION_REASON="scheduled_90d" \
GEMINI_API_KEY_NEW="AIzaSyNEWKEY123..." \
./g/tools/gemini_rotate_key.zsh
```

---

## Related Documentation

- **Health Check**: `g/reports/system/GEMINI_HEALTH_20251121.md`
- **Leak Scanner**: `g/tools/scan_leaked_gemini_key.zsh`
- **Quota Check**: `g/tools/check_quota.py`
- **Rotation Status**: `g/tools/gemini_rotation_status.py`

---

**Last Updated**: 2025-11-21  
**Maintainer**: Liam (Antigravity)
