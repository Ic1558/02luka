#!/usr/bin/env bash
#
# Smart CI Rebase Library
# Provides intelligent conflict detection, dependency analysis, and ordering
#
# This library makes the CI rebase automation smarter and more maintainable
# for long-term use without causing conflicts.

set -euo pipefail

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Configuration Loading
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Load configuration from YAML file
load_config() {
  local config_file="${1:-.github/ci-rebase.config.yml}"

  if [[ ! -f "$config_file" ]]; then
    echo "⚠️  Config file not found: $config_file (using defaults)" >&2
    return 1
  fi

  # Export config file path for other functions
  export CI_REBASE_CONFIG="$config_file"
  return 0
}

# Get configuration value using yq (falls back to defaults if not available)
get_config() {
  local key="$1"
  local default="${2:-}"

  if [[ -z "${CI_REBASE_CONFIG:-}" ]] || ! command -v yq >/dev/null 2>&1; then
    echo "$default"
    return
  fi

  yq eval ".${key}" "$CI_REBASE_CONFIG" 2>/dev/null || echo "$default"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Pre-flight Conflict Detection
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Predict if a branch will have conflicts when rebased
# Returns: 0 = likely no conflict, 1 = likely conflict, 2 = cannot determine
predict_conflict() {
  local branch="$1"
  local base="${2:-origin/main}"
  local confidence=0
  local signals=0

  # Ensure we have the latest refs
  git fetch origin "$branch" >/dev/null 2>&1 || return 2
  git fetch "$(echo "$base" | cut -d/ -f1)" "$(echo "$base" | cut -d/ -f2-)" >/dev/null 2>&1 || return 2

  # Signal 1: Check if merge-base is recent
  local merge_base=$(git merge-base "origin/$branch" "$base" 2>/dev/null || echo "")
  if [[ -n "$merge_base" ]]; then
    local commits_behind=$(git rev-list --count "$merge_base..$base" 2>/dev/null || echo "999")
    ((signals++))

    # If branch is very far behind, higher risk
    if (( commits_behind > 50 )); then
      ((confidence += 30))
    elif (( commits_behind > 20 )); then
      ((confidence += 15))
    fi
  fi

  # Signal 2: Check for overlapping file changes
  local branch_files=$(git diff --name-only "$base...origin/$branch" 2>/dev/null || echo "")
  local base_files=$(git diff --name-only "$merge_base..$base" 2>/dev/null || echo "")

  if [[ -n "$branch_files" ]] && [[ -n "$base_files" ]]; then
    local overlap=$(comm -12 <(echo "$branch_files" | sort) <(echo "$base_files" | sort) | wc -l)
    local total_branch=$(echo "$branch_files" | wc -l)

    ((signals++))

    if (( total_branch > 0 )); then
      local overlap_pct=$((overlap * 100 / total_branch))

      if (( overlap_pct > 50 )); then
        ((confidence += 40))
      elif (( overlap_pct > 25 )); then
        ((confidence += 20))
      elif (( overlap_pct > 0 )); then
        ((confidence += 10))
      fi
    fi
  fi

  # Signal 3: Try a test merge (non-destructive)
  if git merge-tree "$merge_base" "$base" "origin/$branch" 2>/dev/null | grep -q "^<<<<<"; then
    ((confidence += 50))
    ((signals++))
  fi

  # Calculate final confidence
  if (( signals == 0 )); then
    return 2  # Cannot determine
  fi

  local threshold=$(get_config "conflict_threshold" "0.7")
  local threshold_pct=$(echo "$threshold * 100" | bc -l | cut -d. -f1)

  if (( confidence >= threshold_pct )); then
    return 1  # Likely conflict
  else
    return 0  # Likely no conflict
  fi
}

# Analyze conflict probability for a PR
analyze_conflict_risk() {
  local pr_num="$1"
  local branch="$2"
  local base="${3:-origin/main}"

  predict_conflict "$branch" "$base"
  local result=$?

  case $result in
    0) echo "LOW" ;;
    1) echo "HIGH" ;;
    2) echo "UNKNOWN" ;;
  esac
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# PR Dependency Detection
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Detect dependencies between PRs
# Returns: JSON array of PR dependencies
detect_dependencies() {
  local repo="$1"
  shift
  local pr_nums=("$@")

  local deps="[]"

  for pr in "${pr_nums[@]}"; do
    # Check PR description and comments for references
    local pr_body=$(gh pr view "$pr" --repo "$repo" --json body --jq '.body' 2>/dev/null || echo "")

    # Look for "depends on #123" or "blocks #123"
    local mentioned_prs=$(echo "$pr_body" | grep -oiE "(depends on|blocked by|requires) #([0-9]+)" | grep -oE "#[0-9]+" | tr -d '#' | sort -u)

    for dep in $mentioned_prs; do
      # Add to dependency graph
      deps=$(echo "$deps" | jq ". + [{\"pr\": $pr, \"depends_on\": $dep}]")
    done
  done

  echo "$deps"
}

# Topological sort of PRs based on dependencies
# Returns: Space-separated list of PR numbers in dependency order
order_by_dependencies() {
  local deps_json="$1"

  # Simple topological sort (Kahn's algorithm)
  # For now, just return PRs with no dependencies first

  local all_prs=$(echo "$deps_json" | jq -r '.[].pr' | sort -u)
  local dependent_prs=$(echo "$deps_json" | jq -r '.[].pr' | sort -u)
  local independent_prs=$(comm -13 <(echo "$dependent_prs") <(echo "$all_prs"))

  echo "$independent_prs $dependent_prs"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Smart Ordering
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Score a PR for ordering (lower score = higher priority)
score_pr() {
  local repo="$1"
  local pr_num="$2"
  local branch="$3"
  local base="${4:-origin/main}"

  local score=0

  # Get PR metadata
  local pr_json=$(gh pr view "$pr_num" --repo "$repo" \
    --json createdAt,additions,deletions,changedFiles 2>/dev/null || echo '{}')

  # Factor 1: Age (older PRs get lower score)
  local created=$(echo "$pr_json" | jq -r '.createdAt // "2024-01-01T00:00:00Z"')
  local age_days=$(( ($(date +%s) - $(date -d "$created" +%s)) / 86400 ))
  score=$((score - age_days))

  # Factor 2: Size (smaller PRs get lower score)
  local additions=$(echo "$pr_json" | jq -r '.additions // 0')
  local deletions=$(echo "$pr_json" | jq -r '.deletions // 0')
  local total_changes=$((additions + deletions))

  if (( total_changes < 100 )); then
    score=$((score - 50))
  elif (( total_changes < 500 )); then
    score=$((score - 20))
  fi

  # Factor 3: Conflict risk (low risk gets lower score)
  local risk=$(analyze_conflict_risk "$pr_num" "$branch" "$base")
  case "$risk" in
    LOW) score=$((score - 100)) ;;
    HIGH) score=$((score + 100)) ;;
  esac

  echo "$score"
}

# Order PRs intelligently
# Input: JSON array of PR objects with {number, branch}
# Output: Ordered array
smart_order_prs() {
  local prs_json="$1"
  local repo="$2"
  local base="${3:-origin/main}"

  # Create scored array
  local scored="[]"

  while read -r pr; do
    local pr_num=$(echo "$pr" | jq -r '.number')
    local branch=$(echo "$pr" | jq -r '.branch')

    local score=$(score_pr "$repo" "$pr_num" "$branch" "$base")

    scored=$(echo "$scored" | jq ". + [{\"pr\": $pr_num, \"branch\": \"$branch\", \"score\": $score}]")
  done < <(echo "$prs_json" | jq -c '.[]')

  # Sort by score (ascending)
  echo "$scored" | jq 'sort_by(.score) | map({number: .pr, branch: .branch})'
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Hook System
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Execute a hook if it exists
run_hook() {
  local hook_name="$1"
  shift
  local hook_args=("$@")

  local hooks_dir=$(get_config "hooks_dir" ".github/ci-rebase-hooks")

  if [[ ! -d "$hooks_dir" ]]; then
    return 0
  fi

  # Get configured hooks for this event
  local hook_scripts=$(get_config "hooks.${hook_name}" "[]")

  if [[ "$hook_scripts" == "[]" ]] || [[ -z "$hook_scripts" ]]; then
    return 0
  fi

  # Execute each hook script
  while read -r script; do
    if [[ -z "$script" ]] || [[ "$script" == "null" ]]; then
      continue
    fi

    local hook_path="$hooks_dir/$script"

    if [[ -x "$hook_path" ]]; then
      echo "🔌 Running hook: $hook_name ($script)" >&2
      "$hook_path" "${hook_args[@]}" || {
        echo "⚠️  Hook $script returned non-zero: $?" >&2
      }
    fi
  done < <(echo "$hook_scripts" | jq -r '.[]' 2>/dev/null || echo "")

  return 0
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Metrics and Telemetry
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Initialize metrics
init_metrics() {
  local metrics_file=$(get_config "metrics_file" "/tmp/ci-rebase-metrics.json")

  cat > "$metrics_file" <<EOF
{
  "session_id": "$(uuidgen || date +%s)",
  "started_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "prs_processed": 0,
  "prs_succeeded": 0,
  "prs_failed": 0,
  "prs_conflicts": 0,
  "total_duration_sec": 0,
  "operations": []
}
EOF

  export CI_REBASE_METRICS="$metrics_file"
}

# Record a metric
record_metric() {
  local pr_num="$1"
  local status="$2"  # SUCCESS, CONFLICT, FAIL
  local duration="$3"
  local details="${4:-}"

  if [[ -z "${CI_REBASE_METRICS:-}" ]]; then
    return 0
  fi

  local metrics=$(cat "$CI_REBASE_METRICS")

  # Update counters
  metrics=$(echo "$metrics" | jq ".prs_processed += 1")

  case "$status" in
    SUCCESS) metrics=$(echo "$metrics" | jq ".prs_succeeded += 1") ;;
    CONFLICT) metrics=$(echo "$metrics" | jq ".prs_conflicts += 1") ;;
    FAIL) metrics=$(echo "$metrics" | jq ".prs_failed += 1") ;;
  esac

  # Add operation record
  local operation=$(jq -n \
    --arg pr "$pr_num" \
    --arg status "$status" \
    --arg duration "$duration" \
    --arg details "$details" \
    --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
    '{pr: $pr, status: $status, duration_sec: $duration, details: $details, timestamp: $ts}')

  metrics=$(echo "$metrics" | jq ".operations += [$operation]")

  echo "$metrics" > "$CI_REBASE_METRICS"
}

# Finalize metrics
finalize_metrics() {
  if [[ -z "${CI_REBASE_METRICS:-}" ]]; then
    return 0
  fi

  local metrics=$(cat "$CI_REBASE_METRICS")

  metrics=$(echo "$metrics" | jq ".completed_at = \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"")

  # Calculate total duration
  local started=$(echo "$metrics" | jq -r '.started_at')
  local started_ts=$(date -d "$started" +%s 2>/dev/null || echo "0")
  local now_ts=$(date +%s)
  local duration=$((now_ts - started_ts))

  metrics=$(echo "$metrics" | jq ".total_duration_sec = $duration")

  echo "$metrics" > "$CI_REBASE_METRICS"

  # Print summary
  echo "📊 Metrics saved to: $CI_REBASE_METRICS" >&2
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# State Management with Recovery
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Save state snapshot
save_state_snapshot() {
  local state_file="${1:-/tmp/global-ci-rebase-state.json}"

  if [[ ! -f "$state_file" ]]; then
    return 0
  fi

  local keep_history=$(get_config "keep_state_history" "true")

  if [[ "$keep_history" != "true" ]]; then
    return 0
  fi

  # Create timestamped copy
  local snapshot="${state_file}.$(date +%Y%m%d_%H%M%S)"
  cp "$state_file" "$snapshot"

  # Clean old snapshots
  local max_history=$(get_config "max_state_history" "10")
  local existing=$(ls -1t "${state_file}."* 2>/dev/null | tail -n +$((max_history + 1)))

  if [[ -n "$existing" ]]; then
    echo "$existing" | xargs rm -f
  fi
}

# Check if we can resume from a previous run
can_resume() {
  local state_file="${1:-/tmp/global-ci-rebase-state.json}"

  if [[ ! -f "$state_file" ]]; then
    return 1
  fi

  # Check if state is recent (within last 24 hours)
  local age=$(($(date +%s) - $(stat -c %Y "$state_file" 2>/dev/null || echo 0)))

  if (( age > 86400 )); then
    return 1
  fi

  # Check if there are incomplete operations
  local incomplete=$(jq -r '.results | to_entries[] | select(.value.status != "OK") | .key' "$state_file" 2>/dev/null || echo "")

  if [[ -n "$incomplete" ]]; then
    return 0
  fi

  return 1
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Filter enhancements
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Check if PR should be skipped based on labels
should_skip_pr() {
  local repo="$1"
  local pr_num="$2"

  # Get PR labels
  local labels=$(gh pr view "$pr_num" --repo "$repo" --json labels --jq '.labels[].name' 2>/dev/null || echo "")

  # Check skip labels
  local skip_labels=$(get_config "default_filters.skip_labels" "[]")

  while read -r skip_label; do
    if [[ -z "$skip_label" ]] || [[ "$skip_label" == "null" ]]; then
      continue
    fi

    if echo "$labels" | grep -qx "$skip_label"; then
      return 0  # Should skip
    fi
  done < <(echo "$skip_labels" | jq -r '.[]' 2>/dev/null || echo "")

  # Check if draft
  local skip_drafts=$(get_config "default_filters.skip_drafts" "true")
  if [[ "$skip_drafts" == "true" ]]; then
    local is_draft=$(gh pr view "$pr_num" --repo "$repo" --json isDraft --jq '.isDraft' 2>/dev/null || echo "false")

    if [[ "$is_draft" == "true" ]]; then
      return 0  # Should skip
    fi
  fi

  return 1  # Should not skip
}

# Export functions for use in main script
export -f load_config get_config
export -f predict_conflict analyze_conflict_risk
export -f detect_dependencies order_by_dependencies
export -f score_pr smart_order_prs
export -f run_hook
export -f init_metrics record_metric finalize_metrics
export -f save_state_snapshot can_resume
export -f should_skip_pr
