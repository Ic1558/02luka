#!/usr/bin/env zsh
set -euo pipefail
log(){ print -P "%F{cyan}[$(date +'%H:%M:%S')]%f $*"; }; ok(){ print -P "%F{green}✅%f $*"; }; warn(){ print -P "%F{yellow}⚠️ %f $*"; }; err(){ print -P "%F{red}❌%f $*"; }
REPO_DIR="${HOME}/02luka"; WF_DIR="${REPO_DIR}/.github/workflows"
[[ -d "$REPO_DIR" ]] || { err "Missing repo dir: $REPO_DIR"; exit 2; }
cd "$REPO_DIR"

# 1) gh ready
if ! command -v gh >/dev/null; then
  warn "Installing gh…"; NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; brew install gh
fi
ok "gh: $(gh --version | head -n1)"
# 2) auth
TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
[[ -n "$TOKEN" ]] && { printf "%s" "$TOKEN" | gh auth login --with-token >/dev/null 2>&1 || true; }
gh auth status >/dev/null 2>&1 || { warn "Interactive login…"; gh auth login -s "repo,read:org,workflow" -w; }
ok "gh authenticated"

# 3) resolve slug & branches (FIX: echo the slug)
get_repo_slug() {
  local slug
  slug="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)"
  if [[ -n "$slug" ]]; then print -r -- "$slug"; return 0; fi
  local url; url="$(git config --get remote.origin.url 2>/dev/null || true)"
  [[ -n "$url" ]] && print -r -- "$url" | sed -E 's#(git@github\.com:|https?://github\.com/)([^/]+/[^.]+)(\.git)?#\2#' && return 0
  # hard fallback (known public repo)
  print -r -- "Ic1558/02luka"; return 0
}
REPO_SLUG="$(get_repo_slug)"; [[ -n "$REPO_SLUG" ]] || { err "Cannot resolve repo slug"; exit 4; }
BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo main)"
DEFBR="$(gh repo view -R "$REPO_SLUG" --json defaultBranchRef -q .defaultBranchRef.name || echo main)"
log "Repo: $REPO_SLUG | Branch: $BRANCH (default: $DEFBR)"

mkdir -p "$WF_DIR"

# 4) fetch remote workflow list (needs jq)
log "Fetching remote workflows…"
WORKFLOWS_JSON="$(gh api -X GET "repos/${REPO_SLUG}/actions/workflows" 2>/dev/null)"
WF_PATHS=("${(@f)$(print -r -- "$WORKFLOWS_JSON" | jq -r '.workflows[].path' | sort)}")
(( ${#WF_PATHS[@]} )) || { warn "No workflows found on remote."; exit 0; }
ok "Found ${#WF_PATHS[@]} workflows"

# 5) restore any missing files
for WFP in "${WF_PATHS[@]}"; do
  LOCAL="${REPO_DIR}/${WFP}"
  if [[ ! -f "$LOCAL" ]]; then
    log "Restoring $WFP"
    CONTENT_JSON="$(gh api -X GET "repos/${REPO_SLUG}/contents/${WFP}?ref=${DEFBR}")"
    ENC="$(print -r -- "$CONTENT_JSON" | jq -r '.content // empty')"
    [[ -n "$ENC" && "$ENC" != "null" ]] || { err "Cannot fetch $WFP content"; continue; }
    mkdir -p "$(dirname "$LOCAL")"; print -r -- "$ENC" | base64 --decode > "$LOCAL"
    git add "$WFP"
  fi
done
git commit -m "ci: restore missing workflows [R3]" >/dev/null 2>&1 || true
git push >/dev/null 2>&1 || true

# 6) patch all: v3→v4 + permissions + concurrency
ts="$(date +%Y%m%d%H%M%S)"; PATCHED=0
for WFP in "${WF_PATHS[@]}"; do
  LOCAL="${REPO_DIR}/${WFP}"; [[ -f "$LOCAL" ]] || continue
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
(( PATCHED > 0 )) && { git commit -m "ci(opt): artifact v4 + concurrency/permissions [R3]" || true; git push || { err "git push failed"; exit 6; } }
ok "Patched ${PATCHED} workflow(s)"

# 7) enable one-shot debug
gh secret set ACTIONS_STEP_DEBUG   -R "$REPO_SLUG" -b true
gh secret set ACTIONS_RUNNER_DEBUG -R "$REPO_SLUG" -b true
ok "DEBUG enabled"

# 8) trigger & watch each sequentially
ALL_PASS=1; PASSED_FILES=(); FAILED_FILES=()
for WFP in "${WF_PATHS[@]}"; do
  BASE="$(basename "$WFP")"; log "Dispatch $BASE …"
  gh workflow run "$BASE" -R "$REPO_SLUG" -r "$BRANCH" || gh workflow run "$BASE" -R "$REPO_SLUG" -r "$DEFBR" || { err "Dispatch failed: $BASE"; ALL_PASS=0; FAILED_FILES+=("$WFP"); continue; }
  sleep 3
  RID="$(gh run list -R "$REPO_SLUG" --workflow "$BASE" --limit 1 --json databaseId -q '.[0].databaseId' 2>/dev/null || true)"
  if [[ -n "$RID" ]]; then
    if gh run watch -R "$REPO_SLUG" "$RID" --interval 5 --exit-status; then
      ok "PASS: https://github.com/$REPO_SLUG/actions/runs/$RID"; PASSED_FILES+=("$WFP")
    else
      err "FAIL: https://github.com/$REPO_SLUG/actions/runs/$RID"; ALL_PASS=0; FAILED_FILES+=("$WFP")
    fi
  else
    err "No RUN_ID: $BASE"; ALL_PASS=0; FAILED_FILES+=("$WFP")
  fi
done

# 9) cleanup debug
gh secret delete ACTIONS_STEP_DEBUG   -R "$REPO_SLUG" -y || true
gh secret delete ACTIONS_RUNNER_DEBUG -R "$REPO_SLUG" -y || true
ok "DEBUG disabled"

# 10) remove backups for passed workflows
CLEANED=0
for WFP in "${PASSED_FILES[@]}"; do
  for B in "${REPO_DIR}/${WFP}".bak.*; do [[ -f "$B" ]] || continue; rm -f "$B"; CLEANED=$((CLEANED+1)); done
done
if (( CLEANED > 0 )); then git add -A; git commit -m "ci(clean): remove workflow .bak after success [R3]" || true; git push || warn "cleanup push failed (non-fatal)"; fi
log "Summary:"; print "  PASSED: ${#PASSED_FILES[@]}"; for f in "${PASSED_FILES[@]}"; do print "    - $f"; done
print "  FAILED: ${#FAILED_FILES[@]}"; for f in "${FAILED_FILES[@]}"; do print "    - $f"; done
(( ALL_PASS == 1 )) && { ok "ALL workflows passed"; exit 0; } || { err "Some workflows failed (backups kept)"; exit 6; }
