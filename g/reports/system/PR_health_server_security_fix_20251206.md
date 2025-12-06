# PR: Security - Health Server RELAY_KEY Master Switch + Strict Localhost Validation

**Branch:** `fix/health-server-relay-key`  
**Base:** `main`  
**Type:** Security Hotfix (P1)

---

## Summary

Hardens `misc/health_server.cjs` with two critical security fixes:

1. **RELAY_KEY Master Switch** - No localhost bypass when key is set
2. **Strict Localhost Validation** - Exact hostname match prevents suffix spoofing

---

## Vulnerabilities Fixed

### 1. Localhost Bypass (RELAY_KEY)

**Before:**
- Localhost requests could bypass RELAY_KEY check
- Attackers could send `Host: localhost:4000` through tunnel to bypass auth

**After:**
- RELAY_KEY acts as master switch
- If `RELAY_KEY` is set → **ALL requests** must provide valid key (no localhost bypass)
- If `RELAY_KEY` is not set → dev mode, only true localhost allowed

### 2. Host Header Suffix Spoofing

**Before:**
```javascript
host.startsWith('localhost') → matches 'localhost.attacker.com' ❌
```

**After:**
```javascript
hostname === 'localhost' → only matches 'localhost' ✅
```

**Attack vectors blocked:**
- `localhost.attacker.com` → rejected
- `127.0.0.1.evil.com` → rejected
- Any suffix-based spoofing → rejected

---

## Implementation Details

### RELAY_KEY Master Switch

```javascript
// If RELAY_KEY is set → enforce on ALL requests
// If RELAY_KEY is not set → dev mode (localhost only)
const isRelayKeyValid = (req) => {
  if (!RELAY_KEY) {
    return isTrueLocalhost(req); // Dev mode
  }
  // Prod mode: require key on ALL requests
  return fromHeader === RELAY_KEY || fromQuery === RELAY_KEY;
};
```

### Strict Localhost Validation

```javascript
// Parse hostname (remove port)
const hostname = hostHeader.split(':')[0].toLowerCase();

// Exact match only (not startsWith)
const isLocalHostHeader =
  hostname === 'localhost' || hostname === '127.0.0.1';
```

---

## Behavior

### Production Mode (RELAY_KEY set)

- ✅ 200 OK: Valid `x-relay-key` header or `?relay_key` query
- ❌ 401 Unauthorized: Missing or invalid key (even from localhost)

### Development Mode (RELAY_KEY not set)

- ✅ 200 OK: True localhost (loopback IP + exact hostname match)
- ❌ 403 Forbidden: Non-localhost requests

---

## Tests

### Production Mode Tests

```bash
# Test 1: No key (should 401)
export RELAY_KEY="test123"
curl http://127.0.0.1:4000/ping
# Expected: 401 Unauthorized

# Test 2: Wrong key (should 401)
curl -H "x-relay-key: wrong" http://127.0.0.1:4000/ping
# Expected: 401 Unauthorized

# Test 3: Correct key (should 200)
curl -H "x-relay-key: test123" http://127.0.0.1:4000/ping
# Expected: 200 OK
```

### Development Mode Tests

```bash
# Test 4: Localhost (should 200)
unset RELAY_KEY
curl http://127.0.0.1:4000/ping
# Expected: 200 OK

# Test 5: Via tunnel with fake Host (should 403)
# (Tested via cloudflared tunnel)
# Expected: 403 Forbidden
```

### Host Header Spoofing Tests

```bash
# Test 6: Valid localhost (should pass)
curl -H "Host: localhost:4000" http://127.0.0.1:4000/ping
# Expected: 200 OK (dev mode) or 401 (prod mode, no key)

# Test 7: Spoofed hostname (should reject)
curl -H "Host: localhost.attacker.com:4000" http://127.0.0.1:4000/ping
# Expected: 403 Forbidden (dev mode) or 401 (prod mode)
```

---

## Security Improvements

✅ **No localhost bypass** when RELAY_KEY is set  
✅ **No Host header spoofing** via suffix domains  
✅ **Connection-based validation** using `socket.remoteAddress`  
✅ **Exact hostname matching** prevents domain spoofing  
✅ **Clear dev/prod separation** via RELAY_KEY presence

---

## Checklist

- [x] RELAY_KEY master switch implemented
- [x] Localhost bypass removed
- [x] Host header suffix spoofing fixed
- [x] Port parsing implemented
- [x] Exact hostname validation
- [x] Production mode tests passed
- [x] Development mode tests passed
- [x] Host spoofing tests passed

---

## Related

- Original hardening: WO-20251204-HEALTH-SERVER-RELAY-KEY-HARDENING
- Environment config: `.env.local` (gitignored)
- Cloudflare tunnel: `~/.cloudflared/dashboard.yml`

---

**Status:** ✅ Ready for merge (security hotfix)
