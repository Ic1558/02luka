# Security Fix: Path Traversal Vulnerability
**Date:** 2025-11-14  
**Severity:** CRITICAL  
**Status:** ✅ FIXED

---

## Vulnerability Summary

### Issue 1: Path Traversal via Unvalidated ID Parameter
**Location:** `g/apps/dashboard/wo_dashboard_server.js`

**Vulnerable Code:**
```javascript
// BEFORE (VULNERABLE)
async function readStateFile(woId) {
  const filePath = path.join(STATE_DIR, `${woId}.json`);
  // ...
}
```

**Attack Vector:**
- Attacker sends: `/api/wo/../../../../etc/shadow`
- `woId` = `../../../../etc/shadow`
- `path.join(STATE_DIR, '../../../../etc/shadow.json')` resolves to `/etc/shadow.json`
- **Result:** Arbitrary file read/write outside STATE_DIR

**Impact:**
- Read/write any `.json` file accessible by server process
- Potential full system compromise
- No confinement to STATE_DIR

### Issue 2: Auth Token Exposure
**Location:** `g/apps/dashboard/wo_dashboard_server.js` (line 86-87)

**Vulnerable Code:**
```javascript
// BEFORE (VULNERABLE)
if (req.method === 'GET' && pathname === '/api/auth-token') {
  return sendJSON(res, 200, { token: AUTH_TOKEN });
}
```

**Attack Vector:**
1. Attacker calls: `GET /api/auth-token`
2. Receives token in response
3. Uses token to exploit path traversal vulnerability
4. **Result:** Full API access + path traversal = complete compromise

**Impact:**
- Public exposure of authentication token
- Enables exploitation of other vulnerabilities
- No authentication required to get token

---

## Security Fixes Implemented

### Fix 1: WO ID Validation Module
**File:** `g/apps/dashboard/security/woId.js`

**Implementation:**
- **Allowlist approach:** Only `[A-Za-z0-9_-]` characters allowed
- **Double validation:**
  1. Regex check rejects `.` and `/` characters completely
  2. Path normalization + prefix check ensures path stays within STATE_DIR

**Code:**
```javascript
const WO_ID_REGEX = /^[A-Za-z0-9_-]+$/;

function assertValidWoId(id) {
  if (typeof id !== 'string' || !WO_ID_REGEX.test(id)) {
    const err = new Error('Invalid work-order id');
    err.statusCode = 400;
    throw err;
  }
}

function woStatePath(STATE_DIR, id) {
  assertValidWoId(id);
  const base = path.resolve(STATE_DIR);
  const full = path.resolve(path.join(base, id + '.json'));
  
  if (!full.startsWith(base + path.sep)) {
    const err = new Error('Invalid work-order path');
    err.statusCode = 400;
    throw err;
  }
  
  return full;
}
```

### Fix 2: Updated File Operations
**File:** `g/apps/dashboard/wo_dashboard_server.js`

**Changes:**
- `readStateFile()` now uses `woStatePath()` instead of `path.join()`
- `writeStateFile()` now uses `woStatePath()` instead of `path.join()`
- Both functions validate ID before file operations

**Before:**
```javascript
const filePath = path.join(STATE_DIR, `${woId}.json`);
```

**After:**
```javascript
const filePath = woStatePath(STATE_DIR, woId);
```

### Fix 3: Handler Validation
**File:** `g/apps/dashboard/wo_dashboard_server.js`

**Changes:**
- `GET /api/wo/:id` validates ID before processing
- `POST /api/wo/:id/action` validates ID before processing
- Returns 400 error for invalid IDs

**Code:**
```javascript
// GET /api/wo/:id
const woId = pathname.replace('/api/wo/', '');
assertValidWoId(woId);  // SECURITY: Validate before processing
const data = await readStateFile(woId);
```

### Fix 4: Auth Token Endpoint Removed
**File:** `g/apps/dashboard/wo_dashboard_server.js`

**Changes:**
- `/api/auth-token` endpoint completely removed
- Token must be configured via `DASHBOARD_AUTH_TOKEN` environment variable
- Only trusted agents with env var access can authenticate

**Before:**
```javascript
if (req.method === 'GET' && pathname === '/api/auth-token') {
  return sendJSON(res, 200, { token: AUTH_TOKEN });
}
```

**After:**
```javascript
// SECURITY FIX: /api/auth-token endpoint REMOVED
// Token should be configured via environment variables for trusted agents only
// Public exposure of auth token is a security vulnerability
```

---

## Security Improvements

### Defense in Depth
1. **Layer 1:** Regex allowlist prevents `../` and `/` characters
2. **Layer 2:** Path normalization + prefix check ensures containment
3. **Layer 3:** Handler-level validation catches issues early

### Attack Prevention
- ✅ Path traversal attacks blocked (regex rejects `../`)
- ✅ Auth token no longer exposed publicly
- ✅ All file operations validated before execution
- ✅ Clear error messages for invalid IDs (400 status)

---

## Testing Recommendations

### Test Cases
1. **Valid ID:**
   ```bash
   curl -H "Authorization: Bearer $TOKEN" \
     http://localhost:8765/api/wo/WO-20251114-TEST
   ```
   Expected: 200 OK or 404 Not Found

2. **Path Traversal Attempt:**
   ```bash
   curl -H "Authorization: Bearer $TOKEN" \
     http://localhost:8765/api/wo/../../../../etc/passwd
   ```
   Expected: 400 Bad Request - "Invalid work order id"

3. **Auth Token Endpoint:**
   ```bash
   curl http://localhost:8765/api/auth-token
   ```
   Expected: 404 Not Found (endpoint removed)

4. **Special Characters:**
   ```bash
   curl -H "Authorization: Bearer $TOKEN" \
     http://localhost:8765/api/wo/test@123
   ```
   Expected: 400 Bad Request - "Invalid work order id"

---

## Migration Notes

### For Existing Clients
- **Auth Token:** Must be configured via `DASHBOARD_AUTH_TOKEN` environment variable
- **WO IDs:** Must conform to `[A-Za-z0-9_-]+` pattern
- **Invalid IDs:** Will return 400 error (previously might have worked)

### Environment Variables
```bash
export DASHBOARD_AUTH_TOKEN="your-secure-token-here"
export DASHBOARD_PORT=8765
```

---

## Files Changed

1. **Created:**
   - `g/apps/dashboard/security/woId.js` - Security validation module

2. **Modified:**
   - `g/apps/dashboard/wo_dashboard_server.js` - Security fixes applied

---

## Verification

- [x] Security module created
- [x] Path traversal prevention implemented
- [x] Auth token endpoint removed
- [x] All handlers validate IDs
- [x] File operations use secure paths
- [x] No linter errors

---

**Status:** ✅ FIXED  
**Next Steps:** Test the fixes and deploy to production
