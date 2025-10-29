#!/usr/bin/env zsh
# Bridge utility for CLS ↔ CLC work-order handoffs.
set -euo pipefail

SCRIPT_DIR=${0:A:h}
REPO_ROOT=${SCRIPT_DIR:A:h}
source "${SCRIPT_DIR}/lib/cli_common.zsh"

usage() {
  cat <<'USAGE'
Usage: tools/bridge_cls_clc.zsh --title <text> --priority <Pn> --tags <tag1,tag2> --body <path> [--dry-run]

Prepare a CLS → CLC work order payload using repository-managed templates.

Options:
  --title       Work order title (e.g. "CLS CI smoke")
  --priority    Priority identifier (P0–P4)
  --tags        Comma-separated tags applied to the WO
  --body        Path to a YAML body file describing the WO payload
  --dry-run     Do not submit; print the derived metadata and exit
  -h, --help    Show this help message
USAGE
}

TITLE=""
PRIORITY=""
TAGS=""
BODY_PATH=""
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --title)
      shift
      [[ $# -gt 0 ]] || die "--title requires an argument"
      TITLE=$1
      ;;
    --priority)
      shift
      [[ $# -gt 0 ]] || die "--priority requires an argument"
      PRIORITY=$1
      ;;
    --tags)
      shift
      [[ $# -gt 0 ]] || die "--tags requires an argument"
      TAGS=$1
      ;;
    --body)
      shift
      [[ $# -gt 0 ]] || die "--body requires an argument"
      BODY_PATH=$1
      ;;
    --dry-run)
      DRY_RUN=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      die "Unknown option: $1"
      ;;
  esac
  shift
done

[[ -n $TITLE ]] || die "Missing required --title"
[[ -n $PRIORITY ]] || die "Missing required --priority"
[[ -n $TAGS ]] || die "Missing required --tags"
[[ -n $BODY_PATH ]] || die "Missing required --body"

BODY_ABS=${BODY_PATH:A}
[[ -f $BODY_ABS ]] || die "Body file not found: $BODY_PATH"

HASH=$(sha256 "$BODY_ABS")

cat <<EOF
$(ts) CLS ↔ CLC bridge invocation
  Repo root:      $REPO_ROOT
  Title:          $TITLE
  Priority:       $PRIORITY
  Tags:           $TAGS
  Body (abs):     $BODY_ABS
  Body checksum:  $HASH
EOF

if (( DRY_RUN )); then
  cat <<'EOF'
DRY RUN: payload validated locally.
To deploy runtime scripts, CLC operators may sync tools/*.zsh to ~/tools/ on target machines after merge.
EOF
  exit 0
fi

cat <<'EOF'
No automated dispatcher is configured in-repo.
CLS operators should:
  1. Review the payload above.
  2. Submit the WO through the approved runtime interface.
  3. (Optional) Copy updated scripts from the repository into ~/tools/ using an authorized work order.
EOF
