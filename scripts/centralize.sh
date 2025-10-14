#!/usr/bin/env bash
set -euo pipefail

ACTION="${1:-run}"          # run | dry-run | rollback
TS="$(date +%y%m%d_%H%M%S)"

BASE="$HOME/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My Drive/02luka"
REPO="$BASE/02luka-repo"
LOG="$REPO/g/reports/${TS}_centralize.log"
VERIFY_MD="$REPO/g/reports/${TS}_centralization_verified.md"
FLAG="$REPO/config/migration.enforced"
HOOK="$REPO/.git/hooks/pre-push"

dirs=(boss docs g memory agents)   # เติม projects views ทีหลังได้

say(){ echo "[$(date +%H:%M:%S)] $*" | tee -a "$LOG"; }

need(){ command -v "$1" >/dev/null 2>&1 || { echo "❌ need $1"; exit 1; }; }

preflight() {
  say "== C.1 Preflight =="
  [ -d "$BASE" ] || { echo "❌ PARENT missing: $BASE"; exit 1; }
  [ -d "$REPO" ] || { echo "❌ REPO missing:   $REPO"; exit 1; }

  # ไม่มี LaunchAgents ใดชี้ parent อีกต่อไป
  if grep -RInE "/My Drive/02luka/(boss|g|docs|memory|agents)" "$HOME/Library/LaunchAgents" \
      --include="*.plist" --exclude="*__bak_*" --exclude="*.tmp" --exclude="*.sedtmp" --exclude="*.bak2" \
      --exclude-dir=".disabled" --exclude-dir=".backup_*" 2>/dev/null \
      | grep -v "02luka-repo" | grep -q .; then
    echo "❌ LaunchAgents ยังชี้ไปที่ parent — ให้รัน cutover ให้สะอาดก่อน"; exit 1;
  fi

  say "✓ LaunchAgents clean"
  make -C "$REPO" audit-parent >/dev/null || true
}

symlink_phase() {
  say "== C.2 Symlink Centralization =="

  for d in "${dirs[@]}"; do
    p="$BASE/$d"
    r="$REPO/$d"
    legacy="$BASE/.legacy_${d}_$TS"

    [ -e "$r" ] || { say "… skip ($d) — repo path missing: $r"; continue; }

    if [ -L "$p" ]; then
      say "✓ $d already symlink → $(readlink "$p")"
      continue
    fi

    if [ -e "$p" ]; then
      say "→ mv $p  $legacy"
      [ "$ACTION" = "dry-run" ] || mv "$p" "$legacy"
    fi

    say "→ ln -s $r  $p"
    [ "$ACTION" = "dry-run" ] || ln -s "$r" "$p"
  done
}

enforce_guards() {
  say "== C.3 Enable Enforcement =="
  [ "$ACTION" = "dry-run" ] || {
    mkdir -p "$REPO/config"
    printf "enforce=1\nts=%s\n" "$TS" > "$FLAG"
  }
  say "✓ created/updated $FLAG"

  # ทำให้ pre-push บังคับ validate-workspace
  if [ -f "$HOOK" ]; then
    if grep -q "make validate-workspace" "$HOOK"; then
      sed -i '' 's/make validate-workspace || true/make validate-workspace/' "$HOOK" || true
    else
      awk '1; NR==2{print "make validate-workspace"}' "$HOOK" > "$HOOK.tmp" && mv "$HOOK.tmp" "$HOOK"
    fi
    chmod +x "$HOOK"
    say "✓ pre-push enforces validate-workspace"
  else
    # สร้าง hook แบบขั้นต่ำ
    cat > "$HOOK" <<'H'
#!/usr/bin/env bash
set -euo pipefail
make validate-zones
make validate-docs
make validate-workspace
make proof >/dev/null || true
echo "✅ pre-push checks passed"
H
    chmod +x "$HOOK"
    say "✓ pre-push hook created"
  fi
}

verify_and_report() {
  say "== C.4 Verify & Report =="
  if [ "$ACTION" = "dry-run" ]; then
    say "… dry-run: skip verify"
    return
  fi

  make -C "$REPO" validate-docs
  make -C "$REPO" validate-workspace
  make -C "$REPO" boss >/dev/null || true
  make -C "$REPO" proof

  {
    cat <<EOF
---
project: system-stabilization
tags: [ops,centralization,verification]
---
# Centralization Verified ($TS)

- Parent dirs → symlink to repo: ${dirs[*]}
- Enforcement: enabled (config/migration.enforced)
- pre-push: validate-workspace enforced
- Proof & catalogs refreshed

See log: g/reports/${TS}_centralize.log
EOF
  } > "$VERIFY_MD"

  say "✓ report: ${VERIFY_MD##$REPO/}"
}

rollback() {
  say "== Rollback =="
  for d in "${dirs[@]}"; do
    p="$BASE/$d"
    latest=$(ls -1dt "$BASE"/.legacy_"$d"_* 2>/dev/null | head -1 || true)
    [ -n "${latest:-}" ] || { say "… no legacy for $d, skip"; continue; }

    [ -L "$p" ] && { say "→ rm symlink $p"; [ "$ACTION" = "dry-run" ] || rm "$p"; }
    say "→ mv $latest  $p"
    [ "$ACTION" = "dry-run" ] || mv "$latest" "$p"
  done

  if [ -f "$FLAG" ]; then
    say "→ remove $FLAG"
    [ "$ACTION" = "dry-run" ] || rm -f "$FLAG"
  fi

  if [ -f "$HOOK" ]; then
    say "→ relax pre-push"
    [ "$ACTION" = "dry-run" ] || sed -i '' 's/make validate-workspace/make validate-workspace || true/' "$HOOK" || true
  fi

  say "✓ rollback complete"
}

main() {
  need awk; # sed, ln, mv, make, grep มีแน่นอนใน macOS

  case "$ACTION" in
    run)       preflight; symlink_phase; enforce_guards; verify_and_report ;;
    dry-run)   preflight; symlink_phase; enforce_guards; verify_and_report ;;
    rollback)  rollback ;;
    *) echo "Usage: $0 [run|dry-run|rollback]"; exit 2 ;;
  esac
  echo
  echo "✅ Done ($ACTION). Log: ${LOG##$REPO/}"
}

main "$@"
