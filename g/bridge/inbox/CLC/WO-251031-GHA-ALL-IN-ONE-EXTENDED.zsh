#!/usr/bin/env zsh
# =========================================================
# 🧩 WO-251031-GHA-ALL-IN-ONE-EXTENDED
# 🎯 Patch ALL workflows (v3→v4 + hardening) → enable debug → trigger each → watch → cleanup
# 🗓️ 2025-10-31
# =========================================================
set -euo pipefail

log() { print -P "%F{cyan}[$(date +'%H:%M:%S')]%f $*"; }
ok()  { print -P "%F{green}✅%f $*"; }
warn(){ print -P "%F{yellow}⚠️ %f $*"; }
err() { print -P "%F{red}❌%f $*"; }

REPO_DIR="${HOME}/02luka"
WF_DIR="${REPO_DIR}/.github/workflows"
[[ -d "${REPO_DIR}" ]] || { err "Missing repo dir: ${REPO_DIR}"; exit 2; }
[[ -d "${WF_DIR}"  ]] || { err "Missing workflows dir: ${WF_DIR}"; exit 2; }

# --- 1) Ensure Homebrew & gh ---------------------------------------------------
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

# --- 2) Authenticate gh --------------------------------------------------------
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

# --- 3) Resolve repo slug & branch --------------------------------------------
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
log "Repo: ${REPO_SLUG} | Branch: ${BRANCH}"

# --- 4) Collect workflow files -------------------------------------------------
autoload -Uz bashcompinit 2>/dev/null || true
WF_FILES=()
while IFS= read -r f; do WF_FILES+=("$f"); done < <(find "${WF_DIR}" -type f \( -name "*.yml" -o -name "*.yaml" \) | sort)
(( ${#WF_FILES[@]} )) || { warn "No workflow files found."; exit 0; }
log "Found ${#WF_FILES[@]} workflow file(s)."

# --- 5) Patch each workflow: v3→v4 + permissions + concurrency ----------------
ts="$(date +%Y%m%d%H%M%S)"
PATCHED=0
for WF in "${WF_FILES[@]}"; do
  BACKUP="${WF}.bak.${ts}"
  cp "${WF}" "${BACKUP}"
  # Replace artifact actions
  sed -i '' \
    -e 's|actions/upload-artifact@v3|actions/upload-artifact@v4|g' \
    -e 's|actions/download-artifact@v3|actions/download-artifact@v4|g' \
    "${WF}"

  # Light hardening blocks (add once per file if missing)
  python3 - "${WF}" <<'PY'
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

  git -C "${REPO_DIR}" add "${WF#${REPO_DIR}/}"
  PATCHED=$((PATCHED+1))
done

if (( PATCHED > 0 )); then
  git -C "${REPO_DIR}" commit -m "ci(opt): migrate artifact to v4 + add concurrency/permissions to all workflows [WO-251031-GHA-ALL-IN-ONE-EXTENDED]" || true
  git -C "${REPO_DIR}" push || { err "git push failed"; exit 5; }
  ok "Pushed patched workflows (${PATCHED})."
fi

# --- 6) Enable one-shot DEBUG for repo ----------------------------------------
log "Enable DEBUG secrets (one-shot)…"
gh secret set ACTIONS_STEP_DEBUG   -R "${REPO_SLUG}" -b true
gh secret set ACTIONS_RUNNER_DEBUG -R "${REPO_SLUG}" -b true

# --- 7) Trigger & watch each workflow sequentially ----------------------------
ALL_PASS=1
PASSED_FILES=()
FAILED_FILES=()

for WF in "${WF_FILES[@]}"; do
  BASE="$(basename "$WF")"
  log "Dispatch workflow ${BASE} …"
  if gh workflow run "${BASE}" -R "${REPO_SLUG}" -r "${BRANCH}"; then
    ok "Dispatched ${BASE}"
  else
    # Retry on default branch
    DEF="$(gh repo view -R "${REPO_SLUG}" --json defaultBranchRef -q .defaultBranchRef.name || echo main)"
    if gh workflow run "${BASE}" -R "${REPO_SLUG}" -r "${DEF}"; then
      ok "Dispatched ${BASE} on ${DEF}"
    else
      err "Failed to dispatch ${BASE}"
      ALL_PASS=0
      FAILED_FILES+=("${WF}")
      continue
    fi
  fi

  # Watch latest run for that workflow
  sleep 3
  RID="$(gh run list -R "${REPO_SLUG}" --workflow "${BASE}" --limit 1 --json databaseId -q '.[0].databaseId' 2>/dev/null || true)"
  if [[ -n "${RID}" ]]; then
    log "Watching ${BASE} run ${RID} …"
    if gh run watch -R "${REPO_SLUG}" "${RID}" --interval 5 --exit-status; then
      ok "CI PASSED: https://github.com/${REPO_SLUG}/actions/runs/${RID}"
      PASSED_FILES+=("${WF}")
    else
      err "CI FAILED: https://github.com/${REPO_SLUG}/actions/runs/${RID}"
      ALL_PASS=0
      FAILED_FILES+=("${WF}")
    fi
  else
    err "No RUN_ID for ${BASE}; cannot watch."
    ALL_PASS=0
    FAILED_FILES+=("${WF}")
  fi
done

# --- 8) Cleanup DEBUG flags ----------------------------------------------------
log "Cleanup DEBUG secrets…"
gh secret delete ACTIONS_STEP_DEBUG   -R "${REPO_SLUG}" -y || true
gh secret delete ACTIONS_RUNNER_DEBUG -R "${REPO_SLUG}" -y || true
ok "DEBUG disabled."

# --- 9) Remove backups for PASSED workflows only (+commit) ---------------------
CLEANED=0
for WF in "${PASSED_FILES[@]}"; do
  for B in "${WF}".bak.*; do
    [[ -f "$B" ]] || continue
    rm -f "$B"
    CLEANED=$((CLEANED+1))
  done
done

if (( CLEANED > 0 )); then
  git -C "${REPO_DIR}" add -A
  git -C "${REPO_DIR}" commit -m "ci(clean): remove .bak backups for successful workflows" || true
  git -C "${REPO_DIR}" push || warn "git push (cleanup) failed — non-fatal"
  ok "Removed ${CLEANED} backup file(s) for PASSED workflows."
else
  log "No backups to remove (or no workflows passed)."
fi

# --- 10) Final summary & exit code --------------------------------------------
log "Summary:"
print "  PASSED: ${#PASSED_FILES[@]} file(s)"
for f in "${PASSED_FILES[@]}"; do print "    - ${f#${REPO_DIR}/}"; done
print "  FAILED: ${#FAILED_FILES[@]} file(s)"
for f in "${FAILED_FILES[@]}"; do print "    - ${f#${REPO_DIR}/}"; done

if (( ALL_PASS == 1 )); then
  ok "ALL workflows passed. Completed successfully."
  exit 0
else
  err "Some workflows failed. Backups kept for those files."
  exit 6
fi
