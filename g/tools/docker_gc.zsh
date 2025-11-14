#!/usr/bin/env zsh
set -euo pipefail

# -------- Config --------
KEEP_TAGS=2                     # keep last N tags per repo
DRY_RUN=${DRY_RUN:-false}       # set true to preview
ALLOWLIST_PATTERNS=("02luka/" "mcp/")  # repos subject to rotation (prefix match)
LOG="${HOME}/02luka/g/logs/docker_gc.log"

say(){ print -r -- "[$(date '+%F %T')] $*"; }
run(){ say "$@"; eval "$@"; }

# Collect image IDs used by *any* container (running or exited)
used_ids=()
if docker ps -a --format '{{.ImageID}}' >/dev/null 2>&1; then
  used_ids=("${(@f)$(docker ps -a --format '{{.ImageID}}' | sort -u)}")
fi
is_used() {
  local id="$1"
  [[ " ${used_ids[*]} " == *" ${id} "* ]]
}

# Return 0 if repo matches allowlist (prefix)
in_allowlist() {
  local repo="$1"
  for p in "${ALLOWLIST_PATTERNS[@]}"; do
    [[ "$repo" == ${p}* ]] && return 0
  done
  return 1
}

rotate_repo() {
  local repo="$1"
  # list tags for repo, newest first (CreatedAt is lexicographically sortable here)
  local rows=("${(@f)$(docker images --format '{{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.CreatedAt}}' \
                  | awk -v R="$repo" -F'\t' '$1==R && $2!="<none>"' \
                  | sort -k4r)}")
  (( ${#rows} <= KEEP_TAGS )) && return 0
  local keep=(${rows[1,KEEP_TAGS]})
  local drop=(${rows[KEEP_TAGS+1,-1]})

  for line in "${drop[@]}"; do
    local tag id
    tag=$(print -r -- "$line" | awk -F'\t' '{print $2}')
    id=$(print -r -- "$line" | awk -F'\t' '{print $3}')
    if is_used "$id"; then
      say "SKIP in-use: ${repo}:${tag} (${id})"
      continue
    fi
    if [[ "$DRY_RUN" == true ]]; then
      say "DRY-RUN would remove ${repo}:${tag} (${id})"
    else
      run "docker rmi ${repo}:${tag} || true"
    fi
  done
}

{
  say "=== Docker GC start (KEEP_TAGS=${KEEP_TAGS}, DRY_RUN=${DRY_RUN}) ==="

  # Phase A: remove truly dangling <none> images & build cache
  run "docker image prune -a -f || true"
  run "docker builder prune -a -f || true"

  # Phase B: remove stopped containers safely
  run "docker container prune -f || true"

  # Phase C: tag rotation per allowlisted repo (keep last N)
  repos=("${(@f)$(docker images --format '{{.Repository}}' | sort -u)}")
  for r in "${repos[@]}"; do
    [[ -z "$r" || "$r" == "<none>" ]] && continue
    if in_allowlist "$r"; then
      say "Rotate: $r (keep ${KEEP_TAGS})"
      rotate_repo "$r"
    fi
  done

  # Phase D: orphaned volumes (optional)
  run "docker volume prune -f || true"

  say "=== Docker GC done ==="
} | tee -a "$LOG"
