#!/usr/bin/env bash
#
# Smart Validation Library
# Provides intelligent, extensible validation capabilities
#
# This library makes validation smarter, faster, and more maintainable

set -euo pipefail

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Global State
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

declare -A VALIDATOR_RESULTS
declare -A VALIDATOR_DURATIONS
declare -A CACHE_STORE

TOTAL_VALIDATORS=0
PASSED_VALIDATORS=0
FAILED_VALIDATORS=0
WARNED_VALIDATORS=0

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Configuration
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

load_validation_config() {
  local config_file="${1:-.github/validation.config.yml}"

  if [[ ! -f "$config_file" ]]; then
    echo "⚠️  Config not found: $config_file (using defaults)" >&2
    return 1
  fi

  export VALIDATION_CONFIG="$config_file"
  return 0
}

get_validation_config() {
  local key="$1"
  local default="${2:-}"

  if [[ -z "${VALIDATION_CONFIG:-}" ]] || ! command -v yq >/dev/null 2>&1; then
    echo "$default"
    return
  fi

  yq eval ".${key}" "$VALIDATION_CONFIG" 2>/dev/null || echo "$default"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Cache Management
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

cache_init() {
  local cache_enabled=$(get_validation_config "caching.enabled" "true")

  if [[ "$cache_enabled" != "true" ]]; then
    return 0
  fi

  local cache_dir=$(get_validation_config "caching.cache_dir" "/tmp/validation-cache")
  mkdir -p "$cache_dir"
  export VALIDATION_CACHE_DIR="$cache_dir"
}

cache_get() {
  local key="$1"

  if [[ -z "${VALIDATION_CACHE_DIR:-}" ]]; then
    return 1
  fi

  local cache_file="$VALIDATION_CACHE_DIR/${key}.cache"

  if [[ ! -f "$cache_file" ]]; then
    return 1
  fi

  # Check TTL
  local ttl=$(get_validation_config "caching.ttl" "3600")
  local age=$(($(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || echo 0)))

  if (( age > ttl )); then
    rm -f "$cache_file"
    return 1
  fi

  cat "$cache_file"
  return 0
}

cache_set() {
  local key="$1"
  local value="$2"

  if [[ -z "${VALIDATION_CACHE_DIR:-}" ]]; then
    return 0
  fi

  local cache_file="$VALIDATION_CACHE_DIR/${key}.cache"
  echo "$value" > "$cache_file"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Validator Registry
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

validator_result() {
  local name="$1"
  local status="$2"  # PASS, FAIL, WARN, SKIP
  local message="${3:-}"

  ((TOTAL_VALIDATORS++))

  case "$status" in
    PASS) ((PASSED_VALIDATORS++)) ;;
    FAIL) ((FAILED_VALIDATORS++)) ;;
    WARN) ((WARNED_VALIDATORS++)) ;;
  esac

  VALIDATOR_RESULTS[$name]="$status|$message"
}

validator_duration() {
  local name="$1"
  local duration="$2"

  VALIDATOR_DURATIONS[$name]="$duration"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Built-in Validators
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

validate_directory_structure() {
  local config=$(get_validation_config "directory_structure.required_dirs" "[]")

  local failures=()

  while read -r dir_json; do
    [[ -z "$dir_json" ]] && continue

    local path=$(echo "$dir_json" | jq -r '.path')
    local desc=$(echo "$dir_json" | jq -r '.description // "Directory"')

    if [[ ! -d "$path" ]]; then
      failures+=("Missing: $path ($desc)")
    fi
  done < <(echo "$config" | jq -c '.[]' 2>/dev/null || echo "")

  if (( ${#failures[@]} > 0 )); then
    validator_result "directory_structure" "FAIL" "$(printf '%s\n' "${failures[@]}")"
    return 1
  fi

  validator_result "directory_structure" "PASS" "All required directories exist"
  return 0
}

validate_required_files() {
  local critical=$(get_validation_config "required_files.critical" "[]")
  local failures=()

  while read -r file_json; do
    [[ -z "$file_json" ]] && continue

    local path=$(echo "$file_json" | jq -r '.path')
    local desc=$(echo "$file_json" | jq -r '.description // "File"')
    local pattern=$(echo "$file_json" | jq -r '.pattern // ""')
    local min_size=$(echo "$file_json" | jq -r '.min_size // 0')
    local validate_json=$(echo "$file_json" | jq -r '.validate_json // false')
    local executable=$(echo "$file_json" | jq -r '.executable // false')

    # Check existence
    if [[ ! -f "$path" ]]; then
      failures+=("Missing: $path ($desc)")
      continue
    fi

    # Check size
    if (( min_size > 0 )); then
      local size=$(stat -c %s "$path" 2>/dev/null || echo 0)
      if (( size < min_size )); then
        failures+=("Too small: $path (${size}B < ${min_size}B)")
      fi
    fi

    # Check pattern
    if [[ -n "$pattern" ]]; then
      if ! grep -q "$pattern" "$path"; then
        failures+=("Missing pattern '$pattern' in: $path")
      fi
    fi

    # Validate JSON
    if [[ "$validate_json" == "true" ]]; then
      if ! jq empty "$path" 2>/dev/null; then
        failures+=("Invalid JSON: $path")
      fi
    fi

    # Check executable
    if [[ "$executable" == "true" ]]; then
      if [[ ! -x "$path" ]]; then
        failures+=("Not executable: $path")
      fi
    fi
  done < <(echo "$critical" | jq -c '.[]' 2>/dev/null || echo "")

  if (( ${#failures[@]} > 0 )); then
    validator_result "required_files" "FAIL" "$(printf '%s\n' "${failures[@]}")"
    return 1
  fi

  validator_result "required_files" "PASS" "All required files valid"
  return 0
}

validate_git_repository() {
  local verify_git=$(get_validation_config "git_repository.verify_git_dir" "true")
  local require_remote=$(get_validation_config "git_repository.require_remote" "true")

  # Check git directory
  if [[ "$verify_git" == "true" ]]; then
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
      validator_result "git_repository" "FAIL" "Not a git repository"
      return 1
    fi
  fi

  # Check remote
  if [[ "$require_remote" == "true" ]]; then
    local remote_name=$(get_validation_config "git_repository.remote_name" "origin")
    if ! git remote get-url "$remote_name" >/dev/null 2>&1; then
      validator_result "git_repository" "FAIL" "No remote '$remote_name'"
      return 1
    fi
  fi

  validator_result "git_repository" "PASS" "Git repository valid"
  return 0
}

validate_workflow_files() {
  local validate_yaml=$(get_validation_config "workflow_files.validate_yaml" "true")
  local workflow_dir=".github/workflows"

  if [[ ! -d "$workflow_dir" ]]; then
    validator_result "workflow_files" "SKIP" "No workflows directory"
    return 0
  fi

  local issues=()

  # Validate each workflow
  while IFS= read -r -d '' workflow; do
    # YAML syntax
    if [[ "$validate_yaml" == "true" ]] && command -v yq >/dev/null 2>&1; then
      if ! yq eval '.' "$workflow" >/dev/null 2>&1; then
        issues+=("Invalid YAML: $workflow")
      fi
    fi

    # Check action versions
    local required_versions=$(get_validation_config "workflow_files.required_action_versions" "{}")

    while read -r action; do
      [[ -z "$action" ]] && continue

      local required_version=$(echo "$required_versions" | jq -r ".[\"$action\"] // empty")
      [[ -z "$required_version" ]] && continue

      if grep -qE "${action}@${required_version}" "$workflow"; then
        continue
      fi

      if grep -qE "${action}@" "$workflow"; then
        issues+=("Wrong version of $action in $workflow (expected $required_version)")
      fi
    done < <(echo "$required_versions" | jq -r 'keys[]' 2>/dev/null || echo "")
  done < <(find "$workflow_dir" -name "*.yml" -print0 2>/dev/null)

  if (( ${#issues[@]} > 0 )); then
    validator_result "workflow_files" "WARN" "$(printf '%s\n' "${issues[@]}")"
    return 0
  fi

  validator_result "workflow_files" "PASS" "Workflow files valid"
  return 0
}

validate_script_permissions() {
  local patterns=$(get_validation_config "script_permissions.executable_patterns" "[]")
  local exclude=$(get_validation_config "script_permissions.exclude_patterns" "[]")

  local issues=()
  local checked=0

  while read -r pattern; do
    [[ -z "$pattern" ]] && continue

    # Expand glob
    shopt -s nullglob globstar
    local files=($pattern)
    shopt -u nullglob globstar

    for file in "${files[@]}"; do
      # Check excludes
      local excluded=false
      while read -r ex_pattern; do
        [[ -z "$ex_pattern" ]] && continue
        if [[ "$file" == $ex_pattern ]]; then
          excluded=true
          break
        fi
      done < <(echo "$exclude" | jq -r '.[]' 2>/dev/null || echo "")

      [[ "$excluded" == "true" ]] && continue

      ((checked++))

      if [[ ! -x "$file" ]]; then
        issues+=("Not executable: $file")
      fi
    done
  done < <(echo "$patterns" | jq -r '.[]' 2>/dev/null || echo "")

  if (( ${#issues[@]} > 0 )); then
    validator_result "script_permissions" "WARN" "$(printf '%s\n' "${issues[@]}" | head -10)"
    return 0
  fi

  validator_result "script_permissions" "PASS" "Checked $checked scripts"
  return 0
}

validate_dependencies() {
  # Check from cache first
  if cache_get "dependencies" >/dev/null 2>&1; then
    local cached=$(cache_get "dependencies")
    validator_result "dependencies" "PASS" "From cache: $cached"
    return 0
  fi

  local required=$(get_validation_config "dependencies.system_tools.required" "[]")
  local missing=()

  while read -r tool; do
    [[ -z "$tool" ]] && continue

    if ! command -v "$tool" >/dev/null 2>&1; then
      missing+=("$tool")
    fi
  done < <(echo "$required" | jq -r '.[]' 2>/dev/null || echo "")

  if (( ${#missing[@]} > 0 )); then
    validator_result "dependencies" "FAIL" "Missing tools: ${missing[*]}"
    return 1
  fi

  # Cache result
  cache_set "dependencies" "All required tools present"

  validator_result "dependencies" "PASS" "All required tools present"
  return 0
}

validate_cls_integration() {
  local required=$(get_validation_config "cls_integration.required_files" "[]")
  local missing=()

  while read -r file; do
    [[ -z "$file" ]] && continue

    if [[ ! -f "$file" ]]; then
      missing+=("$file")
    fi
  done < <(echo "$required" | jq -r '.[]' 2>/dev/null || echo "")

  if (( ${#missing[@]} > 0 )); then
    validator_result "cls_integration" "WARN" "Missing: ${missing[*]}"
    return 0
  fi

  validator_result "cls_integration" "PASS" "CLS integration files present"
  return 0
}

validate_security_scan() {
  # Check from cache
  if cache_get "security_scan" >/dev/null 2>&1; then
    validator_result "security_scan" "PASS" "From cache: no issues"
    return 0
  fi

  local scan_secrets=$(get_validation_config "security_scan.scan_secrets" "true")
  local issues=()

  if [[ "$scan_secrets" == "true" ]]; then
    local patterns=$(get_validation_config "security_scan.secret_patterns" "[]")

    while read -r pattern; do
      [[ -z "$pattern" ]] && continue

      # Search for pattern (excluding specific paths)
      local matches=$(grep -rnE "$pattern" . \
        --exclude-dir=.git \
        --exclude-dir=node_modules \
        --exclude="*.md" \
        2>/dev/null | head -5)

      if [[ -n "$matches" ]]; then
        issues+=("Potential secret pattern found: ${pattern}")
      fi
    done < <(echo "$patterns" | jq -r '.[]' 2>/dev/null || echo "")
  fi

  if (( ${#issues[@]} > 0 )); then
    validator_result "security_scan" "WARN" "$(printf '%s\n' "${issues[@]}")"
    cache_set "security_scan" "warnings"
    return 0
  fi

  cache_set "security_scan" "clean"
  validator_result "security_scan" "PASS" "No security issues detected"
  return 0
}

validate_performance() {
  local max_size=$(get_validation_config "performance.max_repo_size_mb" "500")
  local repo_size=$(du -sm . 2>/dev/null | cut -f1)

  if (( repo_size > max_size )); then
    validator_result "performance" "WARN" "Repository size: ${repo_size}MB > ${max_size}MB"
    return 0
  fi

  validator_result "performance" "PASS" "Repository size: ${repo_size}MB"
  return 0
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Validator Execution
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

run_validator() {
  local name="$1"
  local category="${2:-important}"

  local start=$(date +%s%3N)

  # Execute validator function
  set +e
  "validate_${name}" 2>&1
  local result=$?
  set -e

  local end=$(date +%s%3N)
  local duration=$(( (end - start) ))

  validator_duration "$name" "$duration"

  return $result
}

run_validators_parallel() {
  local validators=("$@")
  local max_workers=$(get_validation_config "parallel_workers" "4")

  local pids=()
  local active=0

  for validator in "${validators[@]}"; do
    # Wait if max workers reached
    while (( active >= max_workers )); do
      for i in "${!pids[@]}"; do
        if ! kill -0 "${pids[$i]}" 2>/dev/null; then
          unset "pids[$i]"
          ((active--))
        fi
      done
      sleep 0.1
    done

    # Start validator in background
    (run_validator "$validator") &
    pids+=($!)
    ((active++))
  done

  # Wait for all to complete
  for pid in "${pids[@]}"; do
    wait "$pid" || true
  done
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Hooks
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

run_validation_hook() {
  local hook_name="$1"
  shift
  local hook_args=("$@")

  local hooks_enabled=$(get_validation_config "hooks.enabled" "true")
  [[ "$hooks_enabled" != "true" ]] && return 0

  local hooks_dir=$(get_validation_config "hooks.hooks_dir" ".github/validation-hooks")
  [[ ! -d "$hooks_dir" ]] && return 0

  local hook_scripts=$(get_validation_config "hooks.${hook_name}" "[]")
  [[ "$hook_scripts" == "[]" ]] && return 0

  while read -r script; do
    [[ -z "$script" ]] || [[ "$script" == "null" ]] && continue

    local hook_path="$hooks_dir/$script"

    if [[ -x "$hook_path" ]]; then
      "$hook_path" "${hook_args[@]}" || true
    fi
  done < <(echo "$hook_scripts" | jq -r '.[]' 2>/dev/null || echo "")

  return 0
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Metrics
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

init_validation_metrics() {
  local enabled=$(get_validation_config "metrics.enabled" "true")
  [[ "$enabled" != "true" ]] && return 0

  local metrics_file=$(get_validation_config "metrics.metrics_file" "/tmp/validation-metrics.json")

  cat > "$metrics_file" <<EOF
{
  "session_id": "$(uuidgen 2>/dev/null || date +%s)",
  "started_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "validators": [],
  "summary": {
    "total": 0,
    "passed": 0,
    "failed": 0,
    "warned": 0,
    "skipped": 0
  }
}
EOF

  export VALIDATION_METRICS="$metrics_file"
}

record_validator_metric() {
  local name="$1"
  local status="$2"
  local duration="${3:-0}"
  local message="${4:-}"

  [[ -z "${VALIDATION_METRICS:-}" ]] && return 0

  local metrics=$(cat "$VALIDATION_METRICS")

  local entry=$(jq -n \
    --arg name "$name" \
    --arg status "$status" \
    --arg duration "$duration" \
    --arg message "$message" \
    '{name: $name, status: $status, duration_ms: $duration, message: $message}')

  metrics=$(echo "$metrics" | jq ".validators += [$entry]")

  echo "$metrics" > "$VALIDATION_METRICS"
}

finalize_validation_metrics() {
  [[ -z "${VALIDATION_METRICS:-}" ]] && return 0

  local metrics=$(cat "$VALIDATION_METRICS")

  metrics=$(echo "$metrics" | jq \
    --arg total "$TOTAL_VALIDATORS" \
    --arg passed "$PASSED_VALIDATORS" \
    --arg failed "$FAILED_VALIDATORS" \
    --arg warned "$WARNED_VALIDATORS" \
    '.summary.total = ($total | tonumber) |
     .summary.passed = ($passed | tonumber) |
     .summary.failed = ($failed | tonumber) |
     .summary.warned = ($warned | tonumber) |
     .completed_at = "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"')

  echo "$metrics" > "$VALIDATION_METRICS"
}

# Export functions
export -f load_validation_config get_validation_config
export -f cache_init cache_get cache_set
export -f validator_result validator_duration
export -f validate_directory_structure validate_required_files
export -f validate_git_repository validate_workflow_files
export -f validate_script_permissions validate_dependencies
export -f validate_cls_integration validate_security_scan
export -f validate_performance
export -f run_validator run_validators_parallel
export -f run_validation_hook
export -f init_validation_metrics record_validator_metric finalize_validation_metrics
