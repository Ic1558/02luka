#!/usr/bin/env zsh
# ======================================================================
# 🧩 WO-251031-GHA-ALL-IN-ONE-EXTENDED-R2
# 🎯 Fix CI end-to-end even if .github/workflows is missing locally:
#     - gh install+auth
#     - discover workflows from GitHub API
#     - restore any missing workflow files to working copy
#     - patch v3→v4 + add permissions/concurrency
#     - enable DEBUG, trigger each, watch, cleanup backups (passed only)
# ======================================================================
set -euo pipefail

log() { print -P "%F{cyan}[$(date +'%H:%M:%S')]%f $*"; }
ok()  { print -P "%F{green}✅%f $*"; }
warn(){ print -P "%F{yellow}⚠️ %f $*"; }
err() { print -P "%F{red}❌%f $*"; }

REPO_DIR="${HOME}/02luka"
[[ -d "${REPO_DIR}" ]] || { err "Missing repo dir: ${REPO_DIR}"; exit 2; }

# --- 1) Ensure Homebrew & gh
if ! command -v brew >/dev/null 2>&1; then
  warn "Homebrew not found. Installing… (may ask for password)"
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  [[ -d /opt/homebrew/bin ]] && export PATH="/opt/homebrew/bin:$PATH"
  [[ -d /usr/local/bin   ]] && export PATH="/usr/local/bin:$PATH"
fi
if command -v gh >/dev/null 2>&1; then
  log "gh present: $(gh --version | head -n1)"
  brew upgrade gh || true
else
  log "Installing gh via Homebrew…"
  brew install gh
fi
ok "gh ready: $(gh --version | head -n1)"

# --- 2) Authenticate gh
TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
if [[ -n "${TOKEN}" ]]; then
  log "Authenticating gh with token (non-interactive)…"
  printf "%s" "${TOKEN}" | gh auth login --with-token >/dev/null 2>&1 || true
fi
if gh auth status >/dev/null 2>&1; then
  ok "gh authenticated."
else
  warn "gh not authenticated. Starting interactive device login…"
  gh auth login -s "repo,read:org,workflow" -w || { err "Interactive login failed"; exit 3; }
  ok "gh authenticated (interactive)."
fi

# --- 3) Resolve repo slug & branch
get_repo_slug() {
  if command -v gh >/dev/null 2>&1; then
    gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null && return 0
  fi
  local url
  url="$(git -C "${REPO_DIR}" config --get remote.origin.url)"
  print -r -- "${url}" | sed -E 's#(git@github\.com:|https?://github\.com/)([^/]+/[^.]+)(\.git)?#\2#'
}
REPO_SLUG="$(get_repo_slug)"
[[ -n "${REPO_SLUG}" ]] || { err "Cannot resolve repo slug"; exit 4; }
BRANCH="$(git -C "${REPO_DIR}" rev-parse --abbrev-ref HEAD 2>/dev/null || echo main)"
DEFBR="$(gh repo view -R "${REPO_SLUG}" --json defaultBranchRef -q .defaultBranchRef.name || echo main)"
log "Repo: ${REPO_SLUG} | Branch: ${BRANCH} (default: ${DEFBR})"

WF_DIR="${REPO_DIR}/.github/workflows"
mkdir -p "${WF_DIR}"

# --- 4) Discover workflows from GitHub (API)
log "Fetching workflow list from GitHub…"
WORKFLOWS_JSON="$(gh api -X GET "repos/${REPO_SLUG}/actions/workflows" 2>/dev/null)"
if [[ -z "${WORKFLOWS_JSON}" ]]; then
  err "Cannot fetch workflows from GitHub API."
  exit 5
fi

# Extract 'path' fields (e.g. .github/workflows/ops_phase4.yml)
WF_PATHS=("${(@f)$(print -r -- "${WORKFLOWS_JSON}" | jq -r '.workflows[].path' | sort)}")
(( ${#WF_PATHS[@]} )) || { warn "No workflows found on remote."; exit 0; }

log "Found ${#WF_PATHS[@]} workflow(s) in remote."

# --- 5) Ensure each workflow file exists locally; if missing, restore from remote
for WFP in "${WF_PATHS[@]}"; do
  LOCAL="${REPO_DIR}/${WFP}"
  if [[ ! -f "${LOCAL}" ]]; then
    log "Restoring missing workflow: ${WFP}"
    # Fetch file content (base64) from GitHub Contents API at default branch
    CONTENT_JSON="$(gh api -X GET "repos/${REPO_SLUG}/contents/${WFP}?ref=${DEFBR}")"
    ENC="$(print -r -- "${CONTENT_JSON}" | jq -r '.content // empty')"
    if [[ -z "${ENC}" || "${ENC}" == "null" ]]; then
      err "Cannot retrieve content for ${WFP}"
      continue
    fi
    mkdir -p "$(dirname "${LOCAL}")"
    print -r -- "${ENC}" | base64 --decode > "${LOCAL}"
    git -C "${REPO_DIR}" add "${WFP}"
    log "Restored: ${WFP}"
  fi
done
# Commit restoration if any
git -C "${REPO_DIR}" commit -m "ci: restore missing workflow files from remote [R2]" || true
git -C "${REPO_DIR}" push || true

# --- 6) Patch each workflow: v3→v4 + permissions + concurrency
ts="$(date +%Y%m%d%H%M%S)"
PATCHED=0
for WFP in "${WF_PATHS[@]}"; do
  LOCAL="${REPO_DIR}/${WFP}"
  [[ -f "${LOCAL}" ]] || continue
  BACKUP="${LOCAL}.bak.${ts}"
  cp "${LOCAL}" "${BACKUP}"

  # Replace artifact actions
  sed -i '' \
    -e 's|actions/upload-artifact@v3|actions/upload-artifact@v4|g' \
    -e 's|actions/download-artifact@v3|actions/download-artifact@v4|g' \
    "${LOCAL}"

  # Add least-privilege permissions + concurrency once if missing
  python3 - "${LOCAL}" <<'PY'
import re,sys
p=sys.argv[1]
y=open(p,'r',encoding='utf-8').read()
lines=y.splitlines()
ins=[]
if not re.search(r'^permissions:\s*$',y,re.M):
  ins.append("permissions:\n  contents: read\n  actions: read")
if not re.search(r'^concurrency:\s*$',y,re.M):
  ins.append("concurrency:\n  group: ${{ github.workflow }}-${{ github.ref }}\n  cancel-in-progress: true")
if ins:
  if lines and lines[0].startswith("name:"):
    lines=[lines[0],*ins,*lines[1:]]
  else:
    lines=[*ins,*lines]
open(p,'w',encoding='utf-8').write("\n".join(lines))
PY

  git -C "${REPO_DIR}" add "${WFP}"
  PATCHED=$((PATCHED+1))
done

if (( PATCHED > 0 )); then
  git -C "${REPO_DIR}" commit -m "ci(opt): migrate artifact to v4 + add concurrency/permissions [R2]" || true
  git -C "${REPO_DIR}" push || { err "git push failed after patching"; exit 6; }
  ok "Pushed patched workflows (${PATCHED})."
else
  log "No changes to patch."
fi

# --- 7) Enable one-shot DEBUG (repo-level)
log "Enable DEBUG secrets (one-shot)…"
gh secret set ACTIONS_STEP_DEBUG   -R "${REPO_SLUG}" -b true
gh secret set ACTIONS_RUNNER_DEBUG -R "${REPO_SLUG}" -b true

# --- 8) Trigger & watch each workflow sequentially
ALL_PASS=1
typeset -a PASSED_FILES FAILED_FILES
PASSED_FILES=()
FAILED_FILES=()

for WFP in "${WF_PATHS[@]}"; do
  BASE="$(basename "${WFP}")"
  log "Dispatch ${BASE}…"
  if gh workflow run "${BASE}" -R "${REPO_SLUG}" -r "${BRANCH}"; then
    ok "Dispatched ${BASE}"
  else
    # Retry on default branch
    if gh workflow run "${BASE}" -R "${REPO_SLUG}" -r "${DEFBR}"; then
      ok "Dispatched ${BASE} on ${DEFBR}"
    else
      err "Failed to dispatch ${BASE}"
      ALL_PASS=0
      FAILED_FILES+=("${WFP}")
      continue
    fi
  fi

  # Watch latest run
  sleep 3
  RID="$(gh run list -R "${REPO_SLUG}" --workflow "${BASE}" --limit 1 --json databaseId -q '.[0].databaseId' 2>/dev/null || true)"
  if [[ -n "${RID}" ]]; then
    log "Watching ${BASE} run ${RID} …"
    if gh run watch -R "${REPO_SLUG}" "${RID}" --interval 5 --exit-status; then
      ok "CI PASSED: https://github.com/${REPO_SLUG}/actions/runs/${RID}"
      PASSED_FILES+=("${WFP}")
    else
      err "CI FAILED: https://github.com/${REPO_SLUG}/actions/runs/${RID}"
      ALL_PASS=0
      FAILED_FILES+=("${WFP}")
    fi
  else
    err "No RUN_ID for ${BASE}; cannot watch."
    ALL_PASS=0
    FAILED_FILES+=("${WFP}")
  fi
done

# --- 9) Cleanup DEBUG flags
log "Cleanup DEBUG secrets…"
gh secret delete ACTIONS_STEP_DEBUG   -R "${REPO_SLUG}" -y || true
gh secret delete ACTIONS_RUNNER_DEBUG -R "${REPO_SLUG}" -y || true
ok "DEBUG disabled."

# --- 10) Remove backups only for PASSED workflows (+commit)
CLEANED=0
for WFP in "${PASSED_FILES[@]}"; do
  LOCAL="${REPO_DIR}/${WFP}"
  for B in "${LOCAL}".bak.*; do
    [[ -f "$B" ]] || continue
    rm -f "$B"
    CLEANED=$((CLEANED+1))
  done
done
if (( CLEANED > 0 )); then
  git -C "${REPO_DIR}" add -A
  git -C "${REPO_DIR}" commit -m "ci(clean): remove .bak backups for successful workflows [R2]" || true
  git -C "${REPO_DIR}" push || warn "git push (cleanup) failed — non-fatal"
  ok "Removed ${CLEANED} backup file(s) for PASSED workflows."
else
  log "No backups to remove (or no workflows passed)."
fi

# --- 11) Summary & exit
log "Summary:"
print "  PASSED: ${#PASSED_FILES[@]} file(s)"
for f in "${PASSED_FILES[@]}"; do print "    - ${f}"; done
print "  FAILED: ${#FAILED_FILES[@]} file(s)"
for f in "${FAILED_FILES[@]}"; do print "    - ${f}"; done

if (( ALL_PASS == 1 )); then
  ok "ALL workflows passed. Completed successfully."
  exit 0
else
  err "Some workflows failed. Backups kept for those files."
  exit 6
fi
