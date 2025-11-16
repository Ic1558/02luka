#!/usr/bin/env zsh
# brave_fetch.zsh — Headless fetch via Brave for agents/LaunchAgents.
# Usage:
#   brave_fetch.zsh [-m dom|png|pdf] [-o OUTPUT] [-t SECONDS] [--ua "UserAgent"] URL
# Defaults: -m dom, -t 30, output -> stdout (for dom), auto-filenames for png/pdf.

set -euo pipefail

print_err(){ print -u2 -- "[$(date -u +%FT%TZ)] $*"; }
die(){ print_err "ERROR: $*"; exit 1; }

# --- Resolve Brave binary ---
BRAVE_CANDIDATES=(
  "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser"
  "/Applications/Brave Browser Beta.app/Contents/MacOS/Brave Browser Beta"
  "/Applications/Brave Browser Nightly.app/Contents/MacOS/Brave Browser Nightly"
)
for p in "${BRAVE_CANDIDATES[@]}"; do
  [[ -x "$p" ]] && BRAVE="$p" && break
done
[[ -n "${BRAVE:-}" ]] || die "Brave not found in /Applications. Install Brave first."

# --- Defaults ---
MODE="dom"         # dom | png | pdf
OUT=""             # stdout for dom if empty; auto path for png/pdf if empty
TIMEOUT=30
UA="Mozilla/5.0 (Macintosh; Intel Mac OS X) AppleWebKit/537.36 (KHTML, like Gecko) Brave/Headless"

# --- Parse args ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    -m|--mode) MODE="${2:-}"; shift 2;;
    -o|--output) OUT="${2:-}"; shift 2;;
    -t|--timeout) TIMEOUT="${2:-}"; shift 2;;
    --ua) UA="${2:-}"; shift 2;;
    -h|--help)
      cat <<EOF
Usage: brave_fetch.zsh [-m dom|png|pdf] [-o OUTPUT] [-t SECONDS] [--ua "UserAgent"] URL
Examples:
  brave_fetch.zsh https://example.com
  brave_fetch.zsh -m png -o /tmp/page.png https://example.com
  brave_fetch.zsh -m pdf https://example.com      # saves to ./page.pdf by default
EOF
      exit 0;;
    *) URL="${1:-}"; shift;;
  esac
done

[[ -n "${URL:-}" ]] || die "URL is required"
[[ "$MODE" = "dom" || "$MODE" = "png" || "$MODE" = "pdf" ]] || die "Invalid mode: $MODE"

# --- Output path defaults for file modes ---
if [[ "$MODE" != "dom" && -z "$OUT" ]]; then
  fname_base="$(echo "$URL" | sed -E 's#https?://##; s#[^A-Za-z0-9._-]+#_#g; s/_+$//')"
  [[ -z "$fname_base" ]] && fname_base="page"
  case "$MODE" in
    png) OUT="./${fname_base}.png";;
    pdf) OUT="./${fname_base}.pdf";;
  esac
fi

# --- Common flags ---
FLAGS=(
  --headless=new            # modern headless, more stable
  --disable-gpu
  --no-sandbox
  --user-agent "$UA"
  --timeout="$(( TIMEOUT * 1000 ))"
)

# Ensure non-interactive run (no profile prompts)
FLAGS+=( --profile-directory=Default --disable-features=TranslateUI )

# --- Execute by mode ---
case "$MODE" in
  dom)
    # --dump-dom writes to stdout
    exec "$BRAVE" "${FLAGS[@]}" --dump-dom "$URL"
    ;;
  png)
    # --screenshot writes a PNG; --window-size controls viewport
    # If OUT provided, Brave expects --screenshot=PATH
    SCARG="--screenshot"
    [[ -n "$OUT" ]] && SCARG="--screenshot=$OUT"
    exec "$BRAVE" "${FLAGS[@]}" --window-size=1366,1024 "$SCARG" "$URL"
    ;;
  pdf)
    # --print-to-pdf writes a PDF
    PFARG="--print-to-pdf"
    [[ -n "$OUT" ]] && PFARG="--print-to-pdf=$OUT"
    exec "$BRAVE" "${FLAGS[@]}" "$PFARG" "$URL"
    ;;
esac
