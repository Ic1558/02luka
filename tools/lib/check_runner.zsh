#!/usr/bin/env zsh

set -u

autoload -Uz colors; colors

# --- Config ---
: ${CR_BASE:=${LUKA_SOT:-$HOME/02luka}}
: ${CR_OUTDIR:="$CR_BASE/g/reports/system"}
mkdir -p "$CR_OUTDIR"

typeset -gA CR_STATUS CR_STDOUT CR_STDERR
typeset -gi CR_FAILS=0 CR_PASSES=0

cr_ts() { print -r -- "$(date +'%Y-%m-%d %H:%M:%S')"; }

cr_run_check() {  # cr_run_check <id> -- <cmd...>
  local id="$1"; shift
  [[ "$1" == "--" ]] && shift
  local tmpo tmpe rc
  tmpo="$(mktemp)"; tmpe="$(mktemp)"
  {
    set +e
    "$@" >"$tmpo" 2>"$tmpe"
    rc=$?
    set -e
  }
  CR_STDOUT[$id]="$(<"$tmpo")"
  CR_STDERR[$id]="$(<"$tmpe")"
  rm -f "$tmpo" "$tmpe"
  if (( rc == 0 )); then
    CR_STATUS[$id]="pass"
    (( CR_PASSES++ ))
    print -P "%F{green}✔%f [$id] PASS"
  else
    CR_STATUS[$id]="fail:$rc"
    (( CR_FAILS++ ))
    print -P "%F{red}✘%f [$id] FAIL rc=$rc"
  fi
  return 0  # ไม่ทำให้สคริปต์หลักหลุด
}

cr_atomic_write() { # cr_atomic_write <path> <content>
  local path="$1"; shift
  local tmp="${path}.tmp"
  print -r -- "$*" > "$tmp"
  # validate JSON ถ้าลงท้าย .json
  if [[ "$path" == *.json ]]; then
    node -e "JSON.parse(require('fs').readFileSync('$tmp','utf8'))" >/dev/null 2>&1 || {
      print -u2 "JSON invalid for $path; keeping tmp"
      return 1
    }
  fi
  mv -f "$tmp" "$path"
}

cr_write_reports() {
  local md="$CR_OUTDIR/system_checks_$(date +%Y%m%d_%H%M).md"
  local js="$CR_OUTDIR/system_checks_$(date +%Y%m%d_%H%M).json"

  # Markdown
  {
    print "# System Checks — $(cr_ts)"
    print
    print "| Check | Status |"
    print "|------|--------|"
    local k
    for k in "${(@k)CR_STATUS}"; do
      print "| $k | ${CR_STATUS[$k]} |"
    done
    print
    print "## Details"
    for k in "${(@k)CR_STATUS}"; do
      print "### $k"
      print "**Status:** ${CR_STATUS[$k]}"
      [[ -n ${CR_STDOUT[$k]} ]] && print -r "\n**STDOUT:**\n\`\`\`\n${CR_STDOUT[$k]}\n\`\`\`"
      [[ -n ${CR_STDERR[$k]} ]] && print -r "\n**STDERR:**\n\`\`\`\n${CR_STDERR[$k]}\n\`\`\`"
      print
    done
  } > "${md}.tmp" 2>/dev/null || true
  mv -f "${md}.tmp" "$md" 2>/dev/null || true

  # JSON - Export state to ENV first, then generate JSON
  local k keys; keys=()
  for k in "${(@k)CR_STATUS}"; do
    keys+="$k"
    export "CR_STATUS_${k}=${CR_STATUS[$k]}"
    export "CR_STDOUT_${k}=${CR_STDOUT[$k]}"
    export "CR_STDERR_${k}=${CR_STDERR[$k]}"
  done
  export CR_PASSES CR_FAILS
  export CR_KEYS="${(j:, :)keys}"
  export CR_JSON_PATH="$js"
  
  # Generate JSON with env vars set
  node <<'NODE' > "${js}.tmp" 2>/dev/null || true
const fs=require('fs');
const env=process.env;
const keys=(env.CR_KEYS||'').split(',').filter(Boolean);
const status={}, stdout={}, stderr={};
for(const k of keys){
  status[k]=env['CR_STATUS_'+k]||'unknown';
  stdout[k]=env['CR_STDOUT_'+k]||'';
  stderr[k]=env['CR_STDERR_'+k]||'';
}
const payload={
  timestamp: new Date().toISOString(),
  passes: Number(env.CR_PASSES||0),
  fails: Number(env.CR_FAILS||0),
  status, stdout, stderr
};
if(env.CR_JSON_PATH){
  fs.writeFileSync(env.CR_JSON_PATH, JSON.stringify(payload,null,2));
}
NODE
  
  # Move tmp to final location if generated
  if [[ -f "${js}.tmp" ]] && [[ -s "${js}.tmp" ]]; then
    mv -f "${js}.tmp" "$js" 2>/dev/null || true
  else
    rm -f "${js}.tmp" 2>/dev/null || true
  fi

  print -P "%F{cyan}ℹ%f Reports: $md , $js"
}

# ensure we always emit reports
cr_finalize() { cr_write_reports || true; }
trap cr_finalize EXIT
