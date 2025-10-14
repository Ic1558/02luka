#!/usr/bin/env bash
set -euo pipefail
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
OUT="$ROOT/views/ops/daily/index.html"
mkdir -p "$(dirname "$OUT")"

collect_latest() { # <glob-root> <pattern> <max> -> prints absolute paths
  local base="$1" pat="$2" max="$3"
  # find -> null-delimited -> sort by mtime via ls -t -> head N
  find "$base" -maxdepth 1 -type f -name "$pat" -print0 2>/dev/null \
    | xargs -0 ls -t 2>/dev/null | head -"$max" || true
}

collect_latest_memory() { # <memory-root> <max>
  local base="$1" max="$2"
  # scan memory/*/*.md
  find "$base" -mindepth 2 -maxdepth 2 -type f -name "*.md" -print0 2>/dev/null \
    | xargs -0 ls -t 2>/dev/null | head -"$max" || true
}

mapfile -t REPORTS < <(collect_latest "$ROOT/g/reports" "*.md" 10)
mapfile -t MEMORY  < <(collect_latest_memory "$ROOT/memory" 10)

ts="$(date +%Y-%m-%dT%H:%M:%S)"
cat > "$OUT" <<HTML
<!doctype html>
<html lang="en">
<meta charset="utf-8"/>
<title>Daily Ops — Latest Reports & Memory</title>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<style>
  :root { font-family: system-ui, -apple-system, Segoe UI, Roboto, sans-serif; line-height:1.4; }
  body { max-width: 880px; margin: 2rem auto; padding: 0 1rem; }
  h1{margin-bottom:.25rem} .meta{color:#666;margin-bottom:1.25rem}
  h2{margin-top:1.5rem} ul{padding-left:1.1rem} li{margin:.25rem 0}
  .grid{display:grid; grid-template-columns: 1fr 1fr; gap: 1.5rem; align-items:start}
  .pill{display:inline-block; font-size:.8rem; padding:.15rem .5rem; border:1px solid #ddd; border-radius:999px; color:#555}
  a{text-decoration:none} a:hover{text-decoration:underline}
  .empty{color:#888}
</style>
<body>
  <h1>Daily Ops</h1>
  <div class="meta">Updated: ${ts}</div>
  <div class="grid">
    <section>
      <h2>Latest Reports <span class="pill">10</span></h2>
      <ul>
HTML

if ((${#REPORTS[@]})); then
  for p in "${REPORTS[@]}"; do
    rel="${p#"$ROOT"/}"
    href="../../${rel}"
    name="$(basename "$p")"
    printf '        <li><a href="%s">%s</a></li>\n' "$href" "$name" >> "$OUT"
  done
else
  echo '        <li class="empty">No reports found.</li>' >> "$OUT"
fi

cat >> "$OUT" <<HTML
      </ul>
    </section>
    <section>
      <h2>Latest Memory <span class="pill">10</span></h2>
      <ul>
HTML

if ((${#MEMORY[@]})); then
  for p in "${MEMORY[@]}"; do
    rel="${p#"$ROOT"/}"
    href="../../${rel}"
    name="$(basename "$p")"
    agent="$(echo "$rel" | awk -F/ 'NR==1{print $2}')"
    printf '        <li><a href="%s">%s</a> <span class="pill">%s</span></li>\n' "$href" "$name" "$agent" >> "$OUT"
  done
else
  echo '        <li class="empty">No memory entries found.</li>' >> "$OUT"
fi

cat >> "$OUT" <<'HTML'
      </ul>
    </section>
  </div>
  <p style="margin-top:1.5rem">
    See also: <a href="../../boss/reports/index.md">boss/reports</a> ·
    <a href="../../boss/memory/index.md">boss/memory</a>
  </p>
</body>
</html>
HTML

echo "✅ Daily HTML → ${OUT#$ROOT/}"
