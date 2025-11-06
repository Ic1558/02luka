#!/usr/bin/env zsh
set -euo pipefail
DQ="$HOME/02luka/tools/dispatch_quick.zsh"

# ถ้ามี handler แล้ว ให้จบงาน
if grep -q '^\s*ci:health\)' "$DQ"; then
  echo "ci:health already present."
  exit 0
fi

# แทรกบล็อก handler เข้าใน case "$1" in … esac
# หาเส้น 'case "$1" in' ตัวแรก แล้วแทรก handler ถัดลงมา 1 บรรทัด
awk '
  BEGIN{added=0}
  /case[[:space:]]*\$1[[:space:]]*in/ && added==0 {
    print; 
    print "  ci:health)";
    print "    shift";
    print "    \"${BASE:-$HOME/02luka}\"/tools/ci_health.zsh \"${1:-20}\"";
    print "    exit $?";
    print "    ;;";
    added=1;
    next
  }
  {print}
' "$DQ" > "$DQ.tmp"

mv "$DQ.tmp" "$DQ"
chmod +x "$DQ"
echo "ci:health added."

