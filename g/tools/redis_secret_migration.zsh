#!/usr/bin/env zsh
set -euo pipefail
REPO="$HOME/02luka"
cd "$REPO"

echo "== Scan hard-coded Redis credentials =="
MATCHES=$(grep -RInE --exclude-dir=".git" --exclude="*.plist" --include="*.zsh" --include="*.sh" --include="*.py" \
  "(redis-cli .* -a [^ ]+)|(LUKA_REDIS_URL|REDIS_PASSWORD).*(=|:).*(gggclukaic|changeme-02luka)" . 2>/dev/null || true)

if [[ -z "$MATCHES" ]]; then
  echo "OK: No obvious hard-coded secrets found."
  exit 0
fi

echo "$MATCHES"
echo "---"
echo "Create/merge .env.local (no secrets here, just placeholders)"
ENV="$REPO/.env.local"
touch "$ENV"
grep -q '^REDIS_HOST=' "$ENV" || echo 'REDIS_HOST=localhost' >> "$ENV"
grep -q '^REDIS_PORT=' "$ENV" || echo 'REDIS_PORT=6379' >> "$ENV"
grep -q '^REDIS_PASSWORD=' "$ENV" || echo 'REDIS_PASSWORD=' >> "$ENV"  # <-- ใส่จริงภายหลังแบบ manual

if [[ "${APPLY:-0}" != "1" ]]; then
  echo "Dry-run mode. Set APPLY=1 to attempt automated patch."
  exit 0
fi

echo "== APPLY mode: try safe substitutions =="
# 1) ใส่บรรทัด source .env.local ที่หัวสคริปต์ shell (หากยังไม่มี)
for f in $(git ls-files '*.zsh' '*.sh' 2>/dev/null || true); do
  if [[ -f "$f" ]] && ! grep -q 'source "\$HOME/02luka/.env.local"' "$f" 2>/dev/null; then
    if grep -q '^#!/' "$f"; then
      tmp="$(mktemp)"
      {
        head -1 "$f"
        echo '[ -f "$HOME/02luka/.env.local" ] && source "$HOME/02luka/.env.local"'
        tail -n +2 "$f"
      } > "$tmp"
      mv "$tmp" "$f"
    fi
  fi
done

# 2) แทนที่ redis-cli -a <secret> → ใช้ ENV
for f in $(git ls-files '*.zsh' '*.sh' 2>/dev/null || true); do
  if [[ -f "$f" ]]; then
    perl -0777 -i -pe 's/redis-cli\s+-a\s+(\S+)/redis-cli -a "${REDIS_PASSWORD:-$1}" /g' "$f" 2>/dev/null || true
  fi
done

# 3) Python: ใส่ fallback จาก ENV
for f in $(git ls-files '*.py' 2>/dev/null || true); do
  if [[ -f "$f" ]] && grep -qE '(changeme-02luka|gggclukaic)' "$f"; then
    if ! grep -q '^import os' "$f"; then
      perl -0777 -i -pe 's/^(#!/.*\n)/$1import os\n/' "$f" 2>/dev/null || true
    fi
    perl -0777 -i -pe 's/(password\s*=\s*[\"'\''])(changeme-02luka|gggclukaic)([\"'\''])/\1os.environ.get("REDIS_PASSWORD", "")\3/g' "$f" 2>/dev/null || true
  fi
done

git add -A 2>/dev/null || true
git commit -m "chore(security): move Redis secrets to .env.local + ENV-driven access" || true
echo "DONE. Now set REDIS_PASSWORD in $ENV (local only)."
