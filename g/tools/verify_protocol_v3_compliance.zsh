#!/usr/bin/env zsh
# verify_protocol_v3_compliance.zsh
# Verify Protocol v3.2 compliance in CI workflows
set -euo pipefail

SOT="${SOT:-$HOME/02luka}"
WORKFLOW_FILE="${1:-$SOT/.github/workflows/bridge-selfcheck.yml}"
PROTOCOL_FILE="$SOT/g/docs/CONTEXT_ENGINEERING_PROTOCOL_v3.md"

echo "[verify] Protocol v3.2 Compliance Verifier"
echo "[verify] Workflow: $WORKFLOW_FILE"
echo "[verify] Protocol: $PROTOCOL_FILE"

if [[ ! -f "$WORKFLOW_FILE" ]]; then
  echo "[verify] ERROR: Workflow file not found: $WORKFLOW_FILE" >&2
  exit 1
fi

if [[ ! -f "$PROTOCOL_FILE" ]]; then
  echo "[verify] ERROR: Protocol file not found: $PROTOCOL_FILE" >&2
  exit 1
fi

# Check 1: Governance header comment
if ! grep -q "Context Engineering Protocol v3.2" "$WORKFLOW_FILE"; then
  echo "[verify] ❌ Missing Protocol v3.2 governance header"
  exit 1
fi
echo "[verify] ✅ Governance header present"

# Check 2: Escalation routing (Mary/GC)
if ! grep -q "Mary/GC" "$WORKFLOW_FILE"; then
  echo "[verify] ❌ Missing Mary/GC escalation routing"
  exit 1
fi
echo "[verify] ✅ Mary/GC escalation routing present"

# Check 3: MLS tag (context-protocol-v3.2)
if ! grep -q "context-protocol-v3.2" "$WORKFLOW_FILE"; then
  echo "[verify] ❌ Missing context-protocol-v3.2 tag in MLS logging"
  exit 1
fi
echo "[verify] ✅ MLS context-protocol-v3.2 tag present"

# Check 4: Critical issue routing
if ! grep -q "critical.*CLC\|Gemini" "$WORKFLOW_FILE"; then
  echo "[verify] ⚠️  Critical issue routing may be incomplete"
fi

echo "[verify] ✅ All compliance checks passed"
exit 0
