# --- 02luka Permission Guard (CLS) ---
# Auto-approve when from GG/CLS (set via ENV or lock file)
# - Set ENV: PERMISSION_PREAPPROVED=1
# - Or create file: ~/.02luka/.gg_approved.lock or ~/02luka/.ci/GG_APPROVED.lock

permission_guard() {
  local cmd_str="$*"
  local ts; ts="$(date +%Y%m%d_%H%M%S)"
  local log_dir="$HOME/02luka/g/reports/permission_queries"
  local log_file="$log_dir/query_${ts}.log"

  # If pre-approved (from GG/CLS automation), allow immediately
  if [[ "${PERMISSION_PREAPPROVED:-0}" == "1" ]] \
     || [[ -f "$HOME/.02luka/.gg_approved.lock" ]] \
     || [[ -f "$HOME/02luka/.ci/GG_APPROVED.lock" ]]; then
    echo "🔓 PermissionGuard: pre-approved (GG/CLS)."
    return 0
  fi

  # List of "risky" commands (can be extended via PERMISSION_GUARD_EXTRA)
  local sensitive=(gh brew launchctl systemctl sudo rm curl scp rsync docker kubectl gcloud aws helm)
  if [[ -n "${PERMISSION_GUARD_EXTRA:-}" ]]; then
    read -r -a extra <<< "${PERMISSION_GUARD_EXTRA}"
    sensitive+=("${extra[@]}")
  fi

  # Check if any risky command appears in the string
  local hit=""
  for s in "${sensitive[@]}"; do
    if [[ "$cmd_str" == *" $s "* || "$cmd_str" == "$s "* || "$cmd_str" == *" $s" ]]; then
      hit="$s"; break
    fi
  done

  # If no risky command found → allow
  if [[ -z "$hit" ]]; then
    return 0
  fi

  # Alert + request permission
  mkdir -p "$log_dir"
  {
    echo "time: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo "script: $0"
    echo "argv: $cmd_str"
    echo "matched_sensitive: $hit"
  } >> "$log_file"

  echo "⚠️  PermissionGuard: '$hit' detected in: $cmd_str"
  echo "   เหตุผล: คำสั่งนี้อาจแตะระบบ/เครือข่าย/ที่เก็บโค้ด"
  echo "   ตัวเลือก:"
  echo "     [y] อนุญาตและรันต่อทันที"
  echo "     [n] ยกเลิก"
  echo "     [g] ถาม GG ก่อน (จะบันทึก context แล้วหยุด)"
  read -r -p "Proceed? [y/N/g]: " ans

  case "$ans" in
    [Yy]) echo "✅ Approved by user."; return 0 ;;
    [Gg]) echo "🧠 Logged for GG review → $log_file"; return 2 ;;  # Code 2 = consult GG
    *)    echo "🚫 Cancelled by user."; return 1 ;;
  esac
}
