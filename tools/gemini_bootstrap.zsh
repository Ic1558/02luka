#!/usr/bin/env zsh
set -euo pipefail

POLICY_FILE="${GEMINI_POLICIES:-$HOME/.config/gemini/policies.yaml}"

RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'
NC=$'\033[0m'

usage() {
  cat <<'EOF'
Gemini CLI bootstrap (profiles + banner)

Usage:
  tools/gemini_bootstrap.zsh <profile> [--print] [--doctor] [--] [gemini args...]

Examples:
  tools/gemini_bootstrap.zsh human
  tools/gemini_bootstrap.zsh system_gmx -- --help
  tools/gemini_bootstrap.zsh human --print
  tools/gemini_bootstrap.zsh system_gmx --doctor
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" || -z "${1:-}" ]]; then
  usage
  exit 0
fi

PROFILE="$1"
shift

DO_PRINT=0
DO_DOCTOR=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --print) DO_PRINT=1; shift ;;
    --doctor) DO_DOCTOR=1; shift ;;
    --) shift; break ;;
    *) break ;;
  esac
done

if [[ ! -f "$POLICY_FILE" ]]; then
  echo "${RED}❌ Policies file not found:${NC} $POLICY_FILE" >&2
  echo "Create it (per spec) at: $HOME/.config/gemini/policies.yaml" >&2
  exit 2
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "${RED}❌ python3 not found${NC} (required to parse policies.yaml)" >&2
  exit 2
fi

eval "$(
  python3 - "$POLICY_FILE" "$PROFILE" <<'PY'
import os, sys, shlex, re

policy_path = sys.argv[1]
profile = sys.argv[2]

def parse_scalar(raw: str):
    s = raw.strip()
    if s.startswith(("'", '"')) and s.endswith(("'", '"')) and len(s) >= 2:
        return s[1:-1]
    low = s.lower()
    if low in ("true", "yes", "on"):
        return True
    if low in ("false", "no", "off"):
        return False
    if low.isdigit():
        try:
            return int(low)
        except Exception:
            return s
    return s

def parse_minimal_yaml(text: str):
    # Minimal subset parser: mapping-of-mappings with 2-space indents.
    root = {}
    stack = [(0, root)]  # (indent_of_keys, mapping)
    for line in text.splitlines():
        line = line.split("#", 1)[0].rstrip()
        if not line.strip():
            continue
        indent = len(line) - len(line.lstrip(" "))
        stripped = line.strip()
        if ":" not in stripped:
            continue
        key, rest = stripped.split(":", 1)
        key = key.strip()
        rest = rest.strip()

        while stack and indent < stack[-1][0]:
            stack.pop()
        if not stack:
            stack = [(0, root)]
        current = stack[-1][1]

        if rest == "":
            child = {}
            current[key] = child
            stack.append((indent + 2, child))
        else:
            current[key] = parse_scalar(rest)
    return root

def load_yaml(path: str):
    text = open(path, "r", encoding="utf-8").read()
    try:
        import yaml  # type: ignore
        data = yaml.safe_load(text) or {}
        if isinstance(data, dict):
            return data
    except Exception:
        pass
    return parse_minimal_yaml(text)

data = load_yaml(policy_path)
profiles = data.get("profiles", {}) if isinstance(data, dict) else {}
cfg = profiles.get(profile) if isinstance(profiles, dict) else None

if not isinstance(cfg, dict):
    sys.stderr.write(f"Profile not found in policies.yaml: {profile}\n")
    sys.exit(3)

def to_bool(v, default=False):
    if v is None:
        return default
    if isinstance(v, bool):
        return v
    if isinstance(v, (int, float)):
        return bool(v)
    s = str(v).strip().lower()
    return s in ("1", "true", "yes", "on")

model = str(cfg.get("model", "auto"))

sandbox_raw = cfg.get("sandbox", "auto")
if isinstance(sandbox_raw, bool):
    sandbox = "on" if sandbox_raw else "off"
else:
    sandbox = str(sandbox_raw)
sandbox = sandbox.strip()
web = to_bool(cfg.get("web", True), default=True)
tools = to_bool(cfg.get("tools", True), default=True)
agent = cfg.get("agent")
project_root = cfg.get("project_root")
banner = cfg.get("banner")
unset_env = cfg.get("unset_env") or cfg.get("unsetEnv") or cfg.get("unset") or []

if isinstance(unset_env, str):
    # Allow comma-separated string for convenience.
    unset_env = [p.strip() for p in unset_env.split(",") if p.strip()]
elif isinstance(unset_env, list):
    unset_env = [str(v).strip() for v in unset_env if str(v).strip()]
else:
    unset_env = []

def q(v):
    return shlex.quote("" if v is None else str(v))

print(f"PROFILE={q(profile)}")
print(f"MODEL={q(model)}")
print(f"SANDBOX={q(sandbox)}")
print(f"WEB={'1' if web else '0'}")
print(f"TOOLS={'1' if tools else '0'}")
print(f"AGENT={q(agent)}")
print(f"PROJECT_ROOT={q(project_root)}")
print(f"BANNER={q(banner)}")
print(f"UNSET_ENV={q(' '.join(unset_env))}")
PY
)"

WEB_LABEL="on"
[[ "$WEB" == "0" ]] && WEB_LABEL="off"
TOOLS_LABEL="on"
[[ "$TOOLS" == "0" ]] && TOOLS_LABEL="off"

COLOR="$CYAN"
[[ "$PROFILE" == system_* ]] && COLOR="$RED"

WARNINGS=()

if [[ -n "${UNSET_ENV:-}" ]]; then
  for var in ${(z)UNSET_ENV}; do
    if [[ -n "$var" ]]; then
      unset "$var" 2>/dev/null || true
    fi
  done
  WARNINGS+=("unset env vars for this profile: ${UNSET_ENV}")
fi

GEMINI_BIN="$(command -v gemini 2>/dev/null || true)"
if [[ -z "$GEMINI_BIN" ]]; then
  WARNINGS+=("gemini not found in PATH")
fi

if [[ -n "${PROJECT_ROOT:-}" && -d "$PROJECT_ROOT" ]]; then
  cd "$PROJECT_ROOT"
fi

GEMINI_ARGS=()

if [[ -n "$GEMINI_BIN" ]]; then
  HELP_OUT="$("$GEMINI_BIN" --help 2>/dev/null || true)"

  has_flag() {
    local flag="$1"
    print -r -- "$HELP_OUT" | grep -Fq -- "$flag" 2>/dev/null
  }

  if has_flag "--model"; then
    if [[ "${MODEL}" != "auto" && -n "${MODEL}" ]]; then
      GEMINI_ARGS+=(--model "$MODEL")
    fi
  else
    if [[ "${MODEL}" != "auto" && -n "${MODEL}" ]]; then
      WARNINGS+=("gemini does not advertise --model (not passing model=$MODEL)")
    fi
  fi

  if [[ "$SANDBOX" == "off" ]]; then
    if has_flag "--no-sandbox"; then
      GEMINI_ARGS+=(--no-sandbox)
    elif has_flag "--sandbox"; then
      GEMINI_ARGS+=(--sandbox=false)
    else
      WARNINGS+=("profile requests sandbox=off but gemini does not advertise --no-sandbox/--sandbox")
    fi
  elif [[ "$SANDBOX" == "on" || "$SANDBOX" == "true" || "$SANDBOX" == "1" || "$SANDBOX" == "yes" ]]; then
    if has_flag "--sandbox"; then
      GEMINI_ARGS+=(--sandbox)
    else
      WARNINGS+=("profile requests sandbox=on but gemini does not advertise --sandbox")
    fi
  fi

  if [[ -n "${AGENT:-}" ]]; then
    if has_flag "--agent"; then
      GEMINI_ARGS+=(--agent "$AGENT")
    else
      export GEMINI_AGENT="$AGENT"
      WARNINGS+=("gemini does not advertise --agent (exported GEMINI_AGENT=$AGENT)")
    fi
  fi

  if [[ "$TOOLS" == "1" ]]; then
    if has_flag "--tools"; then
      GEMINI_ARGS+=(--tools)
    fi
  fi

  if [[ -n "${PROJECT_ROOT:-}" ]]; then
    if has_flag "--project"; then
      GEMINI_ARGS+=(--project "$PROJECT_ROOT")
    fi
  fi

  if [[ "$WEB" == "0" ]]; then
    WARNINGS+=("profile requests web=off but gemini CLI has no explicit web-disable flag; rely on approvals/policy discipline")
  fi
fi

print_banner() {
  echo "${COLOR}══════════════════════════════════════════════════════════════════════${NC}"
  if [[ -n "${BANNER:-}" ]]; then
    echo "${COLOR}${BANNER}${NC}"
  else
    echo "${COLOR}Gemini bootstrap profile: ${PROFILE}${NC}"
  fi
  echo "${COLOR}profile=${PROFILE}  model=${MODEL}  sandbox=${SANDBOX}  web=${WEB_LABEL}  tools=${TOOLS_LABEL}${NC}"
  if [[ -n "${AGENT:-}" ]]; then
    echo "${COLOR}agent=${AGENT}${NC}"
  fi
  if [[ -n "${PROJECT_ROOT:-}" ]]; then
    echo "${COLOR}project_root=${PROJECT_ROOT}${NC}"
  fi
  echo "${COLOR}policy_file=${POLICY_FILE}${NC}"
  if (( ${#WARNINGS[@]} > 0 )); then
    echo "${YELLOW}Warnings:${NC}"
    for w in "${WARNINGS[@]}"; do
      echo "  ${YELLOW}- ${w}${NC}"
    done
  fi
  echo "${COLOR}══════════════════════════════════════════════════════════════════════${NC}"
}

if (( DO_DOCTOR )); then
  print_banner
  if [[ -n "$GEMINI_BIN" ]]; then
    echo "${GREEN}gemini:${NC} $GEMINI_BIN"
    echo "${GREEN}gemini --help (first 60 lines):${NC}"
    "$GEMINI_BIN" --help 2>/dev/null | sed -n '1,60p' || true
  else
    echo "${RED}gemini:${NC} not found (install/ensure it is on PATH)" >&2
    exit 3
  fi
  exit 0
fi

if (( DO_PRINT )); then
  print_banner
  echo "${GREEN}Resolved exec:${NC}"
  echo "  cd $(pwd)"
  if [[ -n "$GEMINI_BIN" ]]; then
    printf '  %q' "$GEMINI_BIN"
    for a in "${GEMINI_ARGS[@]}"; do
      printf ' %q' "$a"
    done
    echo
  else
    echo "  gemini (not found)"
  fi
  exit 0
fi

print_banner

if [[ -z "$GEMINI_BIN" ]]; then
  echo "${RED}❌ Cannot start Gemini CLI: gemini not found in PATH${NC}" >&2
  exit 3
fi

exec "$GEMINI_BIN" "${GEMINI_ARGS[@]}" "$@"
