#!/usr/bin/env zsh
set -euo pipefail

# Phase 5: Certificate Validator
# Validate deployment certificates are current and valid

REPO="$HOME/02luka"
TODAY=$(date +%Y%m%d)
OUTPUT="$REPO/g/reports/certificate_validation_${TODAY}.json"
VALID_DAYS=${GOVERNANCE_CERT_VALID_DAYS:-30}

mkdir -p "$(dirname "$OUTPUT")"

# Find latest certificate
LATEST_CERT=$(ls -1t "$REPO/g/reports/DEPLOYMENT_CERTIFICATE_"*.md 2>/dev/null | head -1 || echo "")

valid_count=0
invalid_count=0
total_count=0

# Initialize JSON output
cat > "$OUTPUT" <<JSON
{
  "date": "${TODAY}",
  "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "valid_certificates": [],
  "invalid_certificates": [],
  "summary": {
    "total": 0,
    "valid": 0,
    "invalid": 0
  }
}
JSON

if [[ -z "$LATEST_CERT" ]]; then
  echo "⚠️  No deployment certificates found"
  exit 0
fi

# Validate each certificate
for cert in "$REPO/g/reports/DEPLOYMENT_CERTIFICATE_"*.md; do
  [[ ! -f "$cert" ]] && continue
  
  total_count=$((total_count + 1))
  cert_name=$(basename "$cert")
  
  # Check if certificate is readable
  if [[ ! -r "$cert" ]]; then
    invalid_count=$((invalid_count + 1))
    echo "❌ $cert_name: Not readable"
    continue
  fi
  
  # Check certificate age (within VALID_DAYS)
  cert_date=$(grep -i "date\|generated" "$cert" | head -1 | grep -oE "[0-9]{8}" || echo "")
  if [[ -n "$cert_date" ]]; then
    cert_timestamp=$(date -j -f "%Y%m%d" "$cert_date" +%s 2>/dev/null || date -d "$cert_date" +%s 2>/dev/null || echo "0")
    now_timestamp=$(date +%s)
    age_days=$(( (now_timestamp - cert_timestamp) / 86400 ))
    
    if [[ $age_days -gt $VALID_DAYS ]]; then
      invalid_count=$((invalid_count + 1))
      echo "❌ $cert_name: Expired (${age_days} days old, max: ${VALID_DAYS})"
      continue
    fi
  fi
  
  # Check for required sections
  has_summary=false
  has_artifacts=false
  
  if grep -q "Deployment Summary\|Summary" "$cert" 2>/dev/null; then
    has_summary=true
  fi
  
  if grep -q "Artifacts\|Components" "$cert" 2>/dev/null; then
    has_artifacts=true
  fi
  
  if [[ "$has_summary" == "true" && "$has_artifacts" == "true" ]]; then
    valid_count=$((valid_count + 1))
    echo "✅ $cert_name: Valid"
  else
    invalid_count=$((invalid_count + 1))
    echo "❌ $cert_name: Missing required sections"
  fi
done

# Update JSON output
tmp_file=$(mktemp)
jq --argjson total $total_count --argjson valid $valid_count --argjson invalid $invalid_count \
  '.summary.total = $total | .summary.valid = $valid | .summary.invalid = $invalid' \
  "$OUTPUT" > "$tmp_file" && mv "$tmp_file" "$OUTPUT" 2>/dev/null || rm -f "$tmp_file"

# Claude Code component validation
echo "Validating Claude Code components..."

claude_ok=0
claude_total=0

# Check .claude/settings.json
claude_total=$((claude_total+1))
if [[ -f "$REPO/.claude/settings.json" ]]; then
  echo "  ✅ .claude/settings.json exists"
  claude_ok=$((claude_ok+1))
else
  echo "  ❌ .claude/settings.json missing"
fi

# Check hooks
for hook in pre_commit.zsh quality_gate.zsh verify_deployment.zsh; do
  claude_total=$((claude_total+1))
  if [[ -f "$REPO/tools/claude_hooks/$hook" && -x "$REPO/tools/claude_hooks/$hook" ]]; then
    echo "  ✅ $hook exists and executable"
    claude_ok=$((claude_ok+1))
  else
    echo "  ❌ $hook missing or not executable"
  fi
done

# Check metrics collector
claude_total=$((claude_total+1))
if [[ -f "$REPO/tools/claude_tools/metrics_collector.zsh" && -x "$REPO/tools/claude_tools/metrics_collector.zsh" ]]; then
  echo "  ✅ metrics_collector.zsh exists and executable"
  claude_ok=$((claude_ok+1))
else
  echo "  ❌ metrics_collector.zsh missing or not executable"
fi

# Check dependencies
for dep in shellcheck pylint jq gh git; do
  claude_total=$((claude_total+1))
  if command -v "$dep" >/dev/null 2>&1; then
    echo "  ✅ $dep available"
    claude_ok=$((claude_ok+1))
  else
    echo "  ❌ $dep missing"
  fi
done

# Guard against division by zero
if [[ $claude_total -gt 0 ]]; then
  claude_score=$((claude_ok * 100 / claude_total))
else
  claude_score=0
fi

echo "Claude Code Validation Score: ${claude_score}% (${claude_ok}/${claude_total})"

# Update JSON with Claude Code score
tmp_file=$(mktemp)
jq --argjson score $claude_score '.claude_code_score = $score' "$OUTPUT" > "$tmp_file" && mv "$tmp_file" "$OUTPUT" 2>/dev/null || rm -f "$tmp_file"

echo ""
echo "✅ Certificate validation complete: $OUTPUT"
echo "   Valid: $valid_count, Invalid: $invalid_count, Total: $total_count"
