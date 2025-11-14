#!/usr/bin/env zsh
# WO: WO-251107-PHASE-14-RAG-UNIFICATION
# Task: Phase 14.2 – Unified SOT Telemetry Schema
# Classification: Safe Idempotent Patch (SIP)
# Deployed by: CLS (Cognitive Local System Orchestrator)
# Maintainer: GG Core (02LUKA Automation)
# Version: v1.2-telemetry
# Revision: r1
# Timestamp: $(date +%Y-%m-%dT%H:%M:%S%z)
# Author: cls
# Identity: CLS
# Created: 2025-11-07
set -euo pipefail

BASE="$HOME/02luka"
CFG="$BASE/config/telemetry_unified.yaml"
IN_DIR="$BASE/g/telemetry"        # source events here (json/jsonl/yaml/md headers)
OUT_DIR="$BASE/g/telemetry_unified"
LOG="$BASE/logs/telemetry_sync.$(date +%Y%m%d_%H%M%S).log"

mkdir -p "$OUT_DIR" "$BASE/logs"

exec > >(tee -a "$LOG") 2>&1

need() { command -v "$1" >/dev/null || { echo "Missing $1"; exit 1; }; }
need jq; need yq || true

echo "== telemetry_sync start =="

# Safe defaults if yq is absent
parse_yaml_header() {
  # Extract simple 'Key: Value' from top md header block
  awk '
    BEGIN{in=0}
    NR==1 && $0 ~ /^---/ {in=1; next}
    in && $0 ~ /^---/ {exit}
    in && match($0,/^([A-Za-z0-9 _-]+):[[:space:]]*(.*)$/,a){ 
      gsub(/[[:space:]]+$/,"",a[1]); 
      print a[1] ":" a[2]
    }
  '
}

stamp() { date +"%Y-%m-%d %H:%M:%S %z"; }

# Load mapping from config
SRC=$(yq -o=json '.sources' "$CFG" 2>/dev/null || cat "$CFG" | awk '1') # fallback raw
CAN_KEYS=("classification" "deployed_by" "maintainer" "version" "revision" "phase" "timestamp" "wo_id" "verified_by" "status" "evidence_hash" "component" "pid")

normalize_status() {
  local v="$1"
  case "$v" in
    OK|Ok|ok) echo "Production ready" ;;
    Planned|Active|"Production ready"|Closed|Complete) echo "$v" ;;
    *) echo "$v" ;;
  esac
}

norm_rev() {
  local r="$1"
  [[ "$r" =~ ^r[0-9]+$ ]] && echo "$r" || echo "r1"
}

emit_json() {
  local src="$1"
  local kv="$2"  # newline-separated key: value
  local mapjson
  mapjson=$(yq -o=json ".sources.${src}.map" "$CFG" 2>/dev/null || echo "{}")
  # Build canonical json
  local out="{}"
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local k="${line%%:*}"
    local v="${line#*:}"; v="${v## }"
    # find canonical key
    local canon=$(echo "$mapjson" | jq -r --arg k "$k" 'to_entries[]|select(.key==$k)|.value' 2>/dev/null || echo "")
    [[ -z "$canon" || "$canon" == "null" ]] && continue
    out=$(echo "$out" | jq --arg key "$canon" --arg val "$v" '. + {($key): $val}' 2>/dev/null || echo "$out")
  done <<< "$kv"

  # post-normalize (only if we have mappings)
  if echo "$out" | jq -e '.status' >/dev/null 2>&1; then
    local st=$(echo "$out" | jq -r '.status // ""' 2>/dev/null || echo "")
    [[ -n "$st" && "$st" != "null" ]] && out=$(echo "$out" | jq --arg v "$(normalize_status "$st")" '.status=$v' 2>/dev/null || echo "$out")
  fi
  if echo "$out" | jq -e '.revision' >/dev/null 2>&1; then
    local rv=$(echo "$out" | jq -r '.revision // ""' 2>/dev/null || echo "")
    [[ -n "$rv" ]] && out=$(echo "$out" | jq --arg v "$(norm_rev "$rv")" '.revision=$v' 2>/dev/null || echo "$out")
  fi
  # timestamp fallback
  if ! echo "$out" | jq -e '.timestamp' >/dev/null 2>&1; then
    out=$(echo "$out" | jq --arg v "$(stamp)" '.timestamp=$v' 2>/dev/null || echo "$out")
  fi

  echo "$out"
}

count=0
: > "$OUT_DIR/unified.jsonl"

for f in "$IN_DIR"/*; do
  [[ ! -e "$f" ]] && continue
  ext="${f##*.}"
  src="cls"; [[ "$f" == *"/gg/"* ]] && src="gg"; [[ "$f" == *"/cdc/"* || "$f" == *"/codex/"* ]] && src="cdc"
  case "$ext" in
    json|jsonl)
      while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        # flatten keys to k: v lines
        kv=$(echo "$line" | jq -r 'to_entries[]|"\(.key): \(.value)"' 2>/dev/null || true)
        [[ -z "$kv" ]] && continue
        emit_json "$src" "$kv" >> "$OUT_DIR/unified.jsonl" 2>/dev/null || true
        ((count++))
      done < "$f"
      ;;
    yaml|yml)
      # convert yaml → kv lines
      kv=$(yq -o=json '.' "$f" 2>/dev/null | jq -r 'to_entries[]|"\(.key): \(.value)"' || true)
      [[ -n "$kv" ]] && { emit_json "$src" "$kv" >> "$OUT_DIR/unified.jsonl"; ((count++)); }
      ;;
    md)
      kv=$(parse_yaml_header < "$f")
      [[ -n "$kv" ]] && { emit_json "$src" "$kv" >> "$OUT_DIR/unified.jsonl"; ((count++)); }
      ;;
    *) : ;;
  esac
done

# manifest
jq -n --arg ts "$(stamp)" --arg count "$count" \
  '{schema:"telemetry_unified", items:($count|tonumber), timestamp:$ts}' \
  > "$OUT_DIR/manifest.json"

echo "Processed $count items → $OUT_DIR/unified.jsonl"
echo "== telemetry_sync done =="

