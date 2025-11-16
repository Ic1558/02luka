#!/usr/bin/env zsh
set -euo pipefail
log(){ print -P "%F{cyan}[$(date +'%H:%M:%S')]%f $*"; }; ok(){ print -P "%F{green}✅%f $*"; }; warn(){ print -P "%F{yellow}⚠️ %f $*"; }; err(){ print -P "%F{red}❌%f $*"; }

REPO_DIR="${HOME}/02luka"; WF_DIR="${REPO_DIR}/.github/workflows"
[[ -d "$REPO_DIR" ]] || { err "Missing repo dir: $REPO_DIR"; exit 2; }
cd "$REPO_DIR"

# 1) Ensure gh and auth
if ! command -v gh >/dev/null; then
  warn "Installing gh…"; NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; brew install gh
fi
ok "gh: $(gh --version | head -n1)"
TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
[[ -n "$TOKEN" ]] && { printf "%s" "$TOKEN" | gh auth login --with-token >/dev/null 2>&1 || true; }
gh auth status >/dev/null 2>&1 || { warn "Interactive login…"; gh auth login -s "repo,read:org,workflow" -w; }
ok "gh authenticated"

# 2) Resolve slug & branches (NO -R here)
get_repo_slug() {
  local slug
  slug="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)"
  if [[ -n "$slug" ]]; then print -r -- "$slug"; return 0; fi
  local url; url="$(git config --get remote.origin.url 2>/dev/null || true)"
  [[ -n "$url" ]] && print -r -- "$url" | sed -E 's#(git@github\.com:|https?://github\.com/)([^/]+/[^.]+)(\.git)?#\2#' && return 0
  print -r -- "Ic1558/02luka"; return 0
}
REPO_SLUG="$(get_repo_slug)"; [[ -n "$REPO_SLUG" ]] || { err "Cannot resolve repo slug"; exit 4; }
BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo main)"
DEFBR="$(gh repo view "$REPO_SLUG" --json defaultBranchRef -q .defaultBranchRef.name || echo main)"
log "Repo: $REPO_SLUG | Branch: $BRANCH (default: $DEFBR)"

mkdir -p "$WF_DIR"

# 3) Fetch remote workflow list
log "Fetching remote workflows…"
WORKFLOWS_JSON="$(gh api -X GET "repos/${REPO_SLUG}/actions/workflows" 2>/dev/null)"
WF_PATHS=("${(@f)$(print -r -- "$WORKFLOWS_JSON" | jq -r '.workflows[].path' | sort)}")
(( ${#WF_PATHS[@]} )) || { warn "No workflows on remote."; exit 0; }
ok "Found ${#WF_PATHS[@]} workflows"

# 4) Restore missing workflow files (tolerate 404; try DEFBR then BRANCH)
restore_one() {
  local path="$1" ref="$2" out
  set +e
  out="$(gh api -X GET "repos/${REPO_SLUG}/contents/${path}?ref=${ref}" 2>&1)"
  local rc=$?
  set -e
  if (( rc != 0 )) || ! print -r -- "$out" | jq -e '.content' >/dev/null 2>&1; then
    return 1
  fi
  print -r -- "$out" | jq -r '.content' | base64 --decode
  return 0
}

for WFP in "${WF_PATHS[@]}"; do
  LOCAL="${REPO_DIR}/${WFP}"
  if [[ ! -f "$LOCAL" ]]; then
    log "Restoring $WFP"
    mkdir -p "$(dirname "$LOCAL")"
    if restore_one "$WFP" "$DEFBR" > "$LOCAL" 2>/dev/null; then
      :
    elif restore_one "$WFP" "$BRANCH" > "$LOCAL" 2>/dev/null; then
      :
    else
      warn "Skip restore (404 on $DEFBR and $BRANCH): $WFP"
      rm -f "$LOCAL" || true
      continue
    fi
    git add "$WFP"
  fi
done
git commit -m "ci: restore missing workflows [R3b]" >/dev/null 2>&1 || true
git push >/dev/null 2>&1 || true

# 5) Patch all: v3→v4 + permissions + concurrency
ts="$(date +%Y%m%d%H%M%S)"; PATCHED=0; ACTUAL_WFS=()
for WFP in "${WF_PATHS[@]}"; do
  LOCAL="${REPO_DIR}/${WFP}"
  [[ -f "$LOCAL" ]] || { warn "Skip patch (not present): $WFP"; continue; }
  ACTUAL_WFS+=("$WFP")
  cp "$LOCAL" "${LOCAL}.bak.${ts}"
  sed -i '' -e 's|actions/upload-artifact@v3|actions/upload-artifact@v4|g' \
            -e 's|actions/download-artifact@v3|actions/download-artifact@v4|g' "$LOCAL"
  python3 - "$LOCAL" <<'PY'
import re,sys
p=sys.argv[1]; y=open(p,'r',encoding='utf-8').read(); lines=y.splitlines(); ins=[]
if not re.search(r'^permissions:\s*$',y,re.M): ins.append("permissions:\n  contents: read\n  actions: read")
if not re.search(r'^concurrency:\s*$',y,re.M): ins.append("concurrency:\n  group: ${{ github.workflow }}-${{ github.ref }}\n  cancel-in-progress: true")
if ins:
  if lines and lines[0].startswith("name:"): lines=[lines[0],*ins,*lines[1:]]
  else: lines=[*ins,*lines]
open(p,'w',encoding='utf-8').write("\n".join(lines))
PY
  git add "$WFP"; PATCHED=$((PATCHED+1))
done
(( PATCHED > 0 )) && { git commit -m "ci(opt): artifact v4 + concurrency/permissions [R3b]" || true; git push || { err "git push failed"; exit 6; } }
ok "Patched ${PATCHED} workflow(s)"

# 6) Enable one-shot DEBUG
gh secret set ACTIONS_STEP_DEBUG   "$REPO_SLUG" -b true >/dev/null 2>&1 || gh secret set ACTIONS_STEP_DEBUG   -R "$REPO_SLUG" -b true
gh secret set ACTIONS_RUNNER_DEBUG "$REPO_SLUG" -b true >/dev/null 2>&1 || gh secret set ACTIONS_RUNNER_DEBUG -R "$REPO_SLUG" -b true
ok "DEBUG enabled"

# 7) Trigger & watch only workflows that exist locally
ALL_PASS=1; PASSED_FILES=(); FAILED_FILES=()
for WFP in "${ACTUAL_WFS[@]}"; do
  BASE="$(basename "$WFP")"; log "Dispatch $BASE …"
  gh workflow run "$BASE" "$REPO_SLUG" -r "$BRANCH" >/dev/null 2>&1 || gh workflow run "$BASE" "$REPO_SLUG" -r "$DEFBR" >/dev/null 2>&1 || { err "Dispatch failed: $BASE"; ALL_PASS=0; FAILED_FILES+=("$WFP"); continue; }
  sleep 3
  RID="$(gh run list "$REPO_SLUG" --workflow "$BASE" --limit 1 --json databaseId -q '.[0].databaseId' 2>/dev/null || true)"
  if [[ -n "$RID" ]]; then
    if gh run watch "$REPO_SLUG" "$RID" --interval 5 --exit-status; then
      ok "PASS: https://github.com/$REPO_SLUG/actions/runs/$RID"; PASSED_FILES+=("$WFP")
    else
      err "FAIL: https://github.com/$REPO_SLUG/actions/runs/$RID"; ALL_PASS=0; FAILED_FILES+=("$WFP")
    fi
  else
    err "No RUN_ID: $BASE"; ALL_PASS=0; FAILED_FILES+=("$WFP")
  fi
done

# 8) Cleanup DEBUG
gh secret delete ACTIONS_STEP_DEBUG   "$REPO_SLUG" -y >/dev/null 2>&1 || gh secret delete ACTIONS_STEP_DEBUG   -R "$REPO_SLUG" -y || true
gh secret delete ACTIONS_RUNNER_DEBUG "$REPO_SLUG" -y >/dev/null 2>&1 || gh secret delete ACTIONS_RUNNER_DEBUG -R "$REPO_SLUG" -y || true
ok "DEBUG disabled"

# 9) Remove backups for PASSED workflows
CLEANED=0
for WFP in "${PASSED_FILES[@]}"; do
  for B in "${REPO_DIR}/${WFP}".bak.*; do [[ -f "$B" ]] || continue; rm -f "$B"; CLEANED=$((CLEANED+1)); done
done
if (( CLEANED > 0 )); then git add -A; git commit -m "ci(clean): remove workflow .bak after success [R3b]" || true; git push || warn "cleanup push failed (non-fatal)"; fi

# 10) Summary & exit
log "Summary:"; print "  PASSED: ${#PASSED_FILES[@]}"; for f in "${PASSED_FILES[@]}"; do print "    - $f"; done
print "  FAILED: ${#FAILED_FILES[@]}"; for f in "${FAILED_FILES[@]}"; do print "    - $f"; done
(( ALL_PASS == 1 )) && { ok "ALL workflows passed"; exit 0; } || { err "Some workflows failed (backups kept)"; exit 6; }
