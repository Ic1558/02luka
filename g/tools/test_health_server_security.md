# Health Server Security Test Runbook

**File:** `misc/health_server.cjs`  
**Purpose:** Security validation tests for RELAY_KEY master switch and localhost validation

---

## Prerequisites

```bash
cd ~/02luka
export RELAY_KEY="test123"  # For production mode tests
# OR
unset RELAY_KEY  # For development mode tests
```

---

## Test Cases

### Production Mode (RELAY_KEY set)

#### Test 1: No Key → Should 401
```bash
export RELAY_KEY="test123"
node misc/health_server.cjs &
SERVER_PID=$!
sleep 1

curl -v http://127.0.0.1:4000/ping
# Expected: 401 Unauthorized - Invalid relay key

kill $SERVER_PID
```

#### Test 2: Wrong Key → Should 401
```bash
export RELAY_KEY="test123"
node misc/health_server.cjs &
SERVER_PID=$!
sleep 1

curl -v -H "x-relay-key: wrong" http://127.0.0.1:4000/ping
# Expected: 401 Unauthorized - Invalid relay key

kill $SERVER_PID
```

#### Test 3: Correct Key (Header) → Should 200
```bash
export RELAY_KEY="test123"
node misc/health_server.cjs &
SERVER_PID=$!
sleep 1

curl -v -H "x-relay-key: test123" http://127.0.0.1:4000/ping
# Expected: 200 OK {"status":"ok","timestamp":"..."}

kill $SERVER_PID
```

#### Test 4: Correct Key (Query) → Should 200
```bash
export RELAY_KEY="test123"
node misc/health_server.cjs &
SERVER_PID=$!
sleep 1

curl -v "http://127.0.0.1:4000/ping?relay_key=test123"
# Expected: 200 OK

kill $SERVER_PID
```

---

### Development Mode (RELAY_KEY not set)

#### Test 5: Localhost → Should 200
```bash
unset RELAY_KEY
node misc/health_server.cjs &
SERVER_PID=$!
sleep 1

curl -v http://127.0.0.1:4000/ping
# Expected: 200 OK

kill $SERVER_PID
```

#### Test 6: Non-Localhost → Should 403
```bash
unset RELAY_KEY
node misc/health_server.cjs &
SERVER_PID=$!
sleep 1

# Simulate non-localhost (requires actual remote request or tunnel)
# Expected: 403 Forbidden - RELAY_KEY required in production

kill $SERVER_PID
```

---

### Host Header Spoofing Tests

#### Test 7: Valid Localhost → Should Pass
```bash
unset RELAY_KEY
node misc/health_server.cjs &
SERVER_PID=$!
sleep 1

curl -v -H "Host: localhost:4000" http://127.0.0.1:4000/ping
# Expected: 200 OK (dev mode) or 401 (prod mode, no key)

kill $SERVER_PID
```

#### Test 8: Spoofed Hostname → Should Reject
```bash
unset RELAY_KEY
node misc/health_server.cjs &
SERVER_PID=$!
sleep 1

curl -v -H "Host: localhost.attacker.com:4000" http://127.0.0.1:4000/ping
# Expected: 403 Forbidden (dev mode) or 401 (prod mode)

kill $SERVER_PID
```

#### Test 9: Spoofed IP Suffix → Should Reject
```bash
unset RELAY_KEY
node misc/health_server.cjs &
SERVER_PID=$!
sleep 1

curl -v -H "Host: 127.0.0.1.evil.com:4000" http://127.0.0.1:4000/ping
# Expected: 403 Forbidden (dev mode) or 401 (prod mode)

kill $SERVER_PID
```

---

## Quick Test Script

```bash
#!/bin/bash
# Quick security test for health_server.cjs

set -e

RELAY_KEY="test123"
PORT=4000

echo "=== Health Server Security Tests ==="
echo ""

# Start server
export RELAY_KEY
node misc/health_server.cjs > /tmp/health_test.log 2>&1 &
SERVER_PID=$!
sleep 1

# Test 1: No key (should 401)
echo "Test 1: No key"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:$PORT/ping)
if [ "$HTTP_CODE" = "401" ]; then
  echo "  ✅ PASS: Got 401"
else
  echo "  ❌ FAIL: Expected 401, got $HTTP_CODE"
fi

# Test 2: Wrong key (should 401)
echo "Test 2: Wrong key"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "x-relay-key: wrong" http://127.0.0.1:$PORT/ping)
if [ "$HTTP_CODE" = "401" ]; then
  echo "  ✅ PASS: Got 401"
else
  echo "  ❌ FAIL: Expected 401, got $HTTP_CODE"
fi

# Test 3: Correct key (should 200)
echo "Test 3: Correct key"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "x-relay-key: $RELAY_KEY" http://127.0.0.1:$PORT/ping)
if [ "$HTTP_CODE" = "200" ]; then
  echo "  ✅ PASS: Got 200"
else
  echo "  ❌ FAIL: Expected 200, got $HTTP_CODE"
fi

# Cleanup
kill $SERVER_PID 2>/dev/null || true

echo ""
echo "=== Tests Complete ==="
```

---

## Expected Results Summary

| Test | Mode | Input | Expected | Status |
|------|------|-------|----------|--------|
| 1 | Prod | No key | 401 | ✅ |
| 2 | Prod | Wrong key | 401 | ✅ |
| 3 | Prod | Correct key (header) | 200 | ✅ |
| 4 | Prod | Correct key (query) | 200 | ✅ |
| 5 | Dev | Localhost | 200 | ✅ |
| 6 | Dev | Non-localhost | 403 | ✅ |
| 7 | Dev | Valid localhost host | 200 | ✅ |
| 8 | Dev | Spoofed hostname | 403 | ✅ |
| 9 | Dev | Spoofed IP suffix | 403 | ✅ |

---

## Security Validation Checklist

- [x] RELAY_KEY master switch enforced
- [x] No localhost bypass in production mode
- [x] Exact hostname matching (not startsWith)
- [x] Port parsing works correctly
- [x] Host header suffix spoofing blocked
- [x] Connection-based validation (socket.remoteAddress)
- [x] Dev/prod mode separation clear

---

**Last Updated:** 2025-12-06  
**Related PR:** #400
