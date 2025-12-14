# .env.local Secrets Restoration Guide
**Date:** 2025-12-14  
**Issue:** All secrets missing from `.env.local` except GEMINI_API_KEY

---

## Current State

**File:** `/Users/icmini/02luka/.env.local`  
**Current Content:**
```
GEMINI_API_KEY="AIzaSyDfiKYywcpgB1p_q0TTchBWFdH7z29wk8Q"
```

**Status:** Missing required secrets

---

## Required Secrets (from codebase analysis)

### 1. Redis Configuration
- **REDIS_HOST:** `127.0.0.1` (or `localhost`)
- **REDIS_PORT:** `6379`
- **REDIS_PASSWORD:** `gggclukaic` (from `.cursorrules` line 62)

**Used by:**
- `tools/adaptive_collector.zsh`
- `tools/redis_secret_migration.zsh`
- Various Redis operations

### 2. API Keys
- **GEMINI_API_KEY:** ✅ Present
- **ANTHROPIC_API_KEY:** ❌ Missing (required for local review)

**Used by:**
- `tools/lib/local_review_llm.py` (loads from .env.local)
- `tools/local_agent_review_git_hook.zsh` (checks for ANTHROPIC_API_KEY)

---

## Complete .env.local Template

```bash
# API Keys
GEMINI_API_KEY="AIzaSyDfiKYywcpgB1p_q0TTchBWFdH7z29wk8Q"
ANTHROPIC_API_KEY="<your-anthropic-api-key>"

# Redis Configuration
REDIS_HOST="127.0.0.1"
REDIS_PORT="6379"
REDIS_PASSWORD="gggclukaic"
```

---

## Restoration Steps

**⚠️ CRITICAL: Do NOT commit .env.local to git (it's gitignored for security)**

1. **Edit .env.local:**
   ```bash
   cd ~/02luka
   nano .env.local  # or use your preferred editor
   ```

2. **Add missing secrets:**
   - Add REDIS_HOST, REDIS_PORT, REDIS_PASSWORD
   - Add ANTHROPIC_API_KEY (get from Anthropic dashboard)

3. **Verify file:**
   ```bash
   cat .env.local
   ```

4. **Test Redis connection:**
   ```bash
   redis-cli -h 127.0.0.1 -p 6379 -a gggclukaic ping
   ```

5. **Test Anthropic (if needed):**
   ```bash
   python3 -c "import os; from dotenv import load_dotenv; load_dotenv('.env.local'); print('ANTHROPIC_API_KEY:', 'SET' if os.getenv('ANTHROPIC_API_KEY') else 'MISSING')"
   ```

---

## Security Notes

- ✅ `.env.local` is gitignored (not tracked)
- ✅ File was untracked from git in commit `a8c31206` for security
- ⚠️ Never commit secrets to git
- ⚠️ Keep `.env.local` local only

---

## References

- **Redis password source:** `.cursorrules` line 62
- **Redis migration script:** `tools/redis_secret_migration.zsh`
- **Anthropic usage:** `tools/lib/local_review_llm.py`
- **Git history:** File untracked in commit `a8c31206`

---

**Status:** Template ready for manual restoration  
**Action Required:** User must manually add ANTHROPIC_API_KEY (not available in codebase)
