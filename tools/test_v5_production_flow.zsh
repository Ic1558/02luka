#!/usr/bin/env zsh
# ═══════════════════════════════════════════════════════════════════════
# Test v5 Production Flow
# ═══════════════════════════════════════════════════════════════════════
# Creates test Work Orders and drops them to MAIN inbox to verify v5 stack.
# ═══════════════════════════════════════════════════════════════════════

set -euo pipefail

ROOT="${LUKA_SOT:-${HOME}/02luka}"
MAIN_INBOX="${ROOT}/bridge/inbox/main"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# ═══════════════════════════════════════════
# Test WO Creation
# ═══════════════════════════════════════════

create_fast_lane_wo() {
    local wo_id="TEST-V5-FAST-${TIMESTAMP}"
    local wo_file="${MAIN_INBOX}/${wo_id}.yaml"
    
    cat > "$wo_file" <<EOF
wo_id: ${wo_id}
created_at: $(date -u +"%Y-%m-%dT%H:%M:%S+00:00")
origin:
  world: CLI
  actor: CLS
  trigger: cursor
desired_state: |
  Test file for v5 FAST lane verification
operations:
  - path: g/reports/test_v5_fast_${TIMESTAMP}.md
    operation: write
    content: |
      # v5 FAST Lane Test
      
      This file was created via v5 stack (FAST lane → LOCAL execution).
      
      Timestamp: ${TIMESTAMP}
      WO ID: ${wo_id}
change_type: ADD
EOF
    
    echo "✅ Created FAST lane WO: $wo_id"
    echo "   Path: $wo_file"
    echo "   Expected: FAST lane → LOCAL execution"
}

create_strict_lane_wo() {
    local wo_id="TEST-V5-STRICT-${TIMESTAMP}"
    local wo_file="${MAIN_INBOX}/${wo_id}.yaml"
    
    cat > "$wo_file" <<EOF
wo_id: ${wo_id}
created_at: $(date -u +"%Y-%m-%dT%H:%M:%S+00:00")
origin:
  world: BACKGROUND
  actor: CLC
  trigger: cron
desired_state: |
  Test file for v5 STRICT lane verification
operations:
  - path: bridge/core/test_v5_strict_${TIMESTAMP}.md
    operation: write
    content: |
      # v5 STRICT Lane Test
      
      This file was created via v5 stack (STRICT lane → CLC execution).
      
      Timestamp: ${TIMESTAMP}
      WO ID: ${wo_id}
change_type: ADD
risk_level: MEDIUM
rollback_strategy: git_revert
EOF
    
    echo "✅ Created STRICT lane WO: $wo_id"
    echo "   Path: $wo_file"
    echo "   Expected: STRICT lane → CLC inbox"
}

# ═══════════════════════════════════════════
# Main
# ═══════════════════════════════════════════

main() {
    local test_type="${1:-both}"
    
    if [[ ! -d "$MAIN_INBOX" ]]; then
        echo "❌ MAIN inbox not found: $MAIN_INBOX"
        exit 1
    fi
    
    echo "🧪 Creating test Work Orders for v5 production flow"
    echo "📁 MAIN inbox: $MAIN_INBOX"
    echo ""
    
    case "$test_type" in
        fast)
            create_fast_lane_wo
            ;;
        strict)
            create_strict_lane_wo
            ;;
        both)
            create_fast_lane_wo
            echo ""
            create_strict_lane_wo
            ;;
        *)
            echo "❌ Unknown test type: $test_type"
            echo "Usage: $0 [fast|strict|both]"
            exit 1
            ;;
    esac
    
    echo ""
    echo "✅ Test Work Orders created"
    echo ""
    echo "📊 Next steps:"
    echo "   1. Monitor with: zsh ~/02luka/tools/monitor_v5_production.zsh json"
    echo "   2. Check Gateway v3 Router logs: g/telemetry/gateway_v3_router.log"
    echo "   3. Verify lane routing in logs"
}

main "${@}"

