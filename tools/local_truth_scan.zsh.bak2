#!/usr/bin/env zsh
set -euo pipefail

# ===== Local Truth Scanner =====
# Analyzes actual data in ~/02luka to generate data-driven TODO/roadmap
# No execution - just intelligent analysis and proposals

ROOT="$HOME/02luka"
REPORT_DIR="$ROOT/g/reports/system_insights/$(date +%Y%m%d_%H%M)"
OUT_JSON="$REPORT_DIR/local_truth.json"
OUT_MD="$REPORT_DIR/local_truth.md"
OUT_HTML="$REPORT_DIR/local_truth.html"
WO_DIR="$ROOT/bridge/outbox/RD"
TEL="$ROOT/telemetry/metrics.jsonl"

mkdir -p "$REPORT_DIR" "$WO_DIR"

# Helpers
count_files(){ [ -d "$1" ] && find "$1" -type f 2>/dev/null | wc -l | awk '{print $1}' || echo 0; }
count_imgs(){ [ -d "$1" ] && find "$1" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.heic' -o -iname '*.pdf' \) 2>/dev/null | wc -l | awk '{print $1}' || echo 0; }
count_dirs(){ [ -d "$1" ] && find "$1" -maxdepth 1 -type d -not -path "$1" 2>/dev/null | wc -l | awk '{print $1}' || echo 0; }
recent_files(){ [ -d "$1" ] && find "$1" -type f -mtime -7 2>/dev/null | wc -l | awk '{print $1}' || echo 0; }
sz(){ [ -d "$1" ] && du -sh "$1" 2>/dev/null | awk '{print $1}' || echo "0"; }

echo "🔍 Scanning local data..."

# === Scan directories ===
PROJ_DIR="$ROOT/g/projects"
EXP_INBOX="$ROOT/g/inbox/expense_slips"
NOTES_DIR="$ROOT/g/projects"
SESS_DIR="$ROOT/g/reports/sessions"
MEM_DIR="$ROOT/memory"

# Projects
proj_dirs=$(count_dirs "$PROJ_DIR")
proj_files=$(count_files "$PROJ_DIR")
proj_recent=$(recent_files "$PROJ_DIR")

# Expense slips
expense_total=$(count_imgs "$EXP_INBOX")
expense_recent=$([ -d "$EXP_INBOX" ] && find "$EXP_INBOX" -type f -mtime -7 2>/dev/null | wc -l | awk '{print $1}' || echo 0)

# Sessions & memory
sessions_count=$(count_files "$SESS_DIR")
sessions_recent=$(recent_files "$SESS_DIR")
mem_files=$(count_files "$MEM_DIR")
mem_size=$(sz "$MEM_DIR")

# Queues
llm_pending=$([ -d "$ROOT/bridge/inbox/LLM" ] && find "$ROOT/bridge/inbox/LLM" -type f -name 'WO-*.json' 2>/dev/null | wc -l | awk '{print $1}' || echo 0)
rd_pending=$([ -d "$ROOT/bridge/inbox/RD" ] && find "$ROOT/bridge/inbox/RD" -type f -name '*.json' 2>/dev/null | wc -l | awk '{print $1}' || echo 0)
rd_proposals=$([ -d "$WO_DIR" ] && find "$WO_DIR" -maxdepth 1 -type f -name 'WO-*.json' 2>/dev/null | wc -l | awk '{print $1}' || echo 0)

# Telemetry
if [ -f "$TEL" ]; then
  tel_total=$(wc -l < "$TEL" | awk '{print $1}')
  tel_recent=$(tail -n 100 "$TEL" 2>/dev/null | wc -l | awk '{print $1}')
  tel_cost=$(jq -r '.cost_usd // empty' "$TEL" 2>/dev/null | tail -n 100 | awk '{s+=$1} END{printf "%.2f", s+0}')
  tel_providers=$(jq -r 'select(.provider!=null) | .provider' "$TEL" 2>/dev/null | tail -n 100 | sort | uniq -c | sort -nr | head -3 | awk '{print "  - " $2 ": " $1 " calls"}')
else
  tel_total=0; tel_recent=0; tel_cost="0.00"; tel_providers="  - (no data)"
fi

echo "  📊 Projects: $proj_dirs dirs, $proj_files files ($proj_recent recent)"
echo "  🧾 Expense slips: $expense_total total ($expense_recent this week)"
echo "  📝 Sessions: $sessions_count total ($sessions_recent recent)"
echo "  🔬 Telemetry: $tel_total lines, \$$tel_cost recent cost"

# === Intelligent Analysis ===
echo "🧠 Analyzing patterns..."

# Infer needs based on data
needs_expense=false
needs_rollup=false
needs_invoice=false
needs_boq=false

# Expense tracker: if slips exist
[ "$expense_total" -ge 3 ] && needs_expense=true

# Project rollup: if multiple active projects
[ "$proj_dirs" -ge 2 ] && [ "$proj_recent" -ge 3 ] && needs_rollup=true

# Invoice: if any projects exist
[ "$proj_dirs" -ge 1 ] && needs_invoice=true

# BOQ: check for CAD/drawing files
boq_drawings=$([ -d "$PROJ_DIR" ] && find "$PROJ_DIR" -type f \( -iname '*.dwg' -o -iname '*.dxf' -o -iname '*plan*.pdf' -o -iname '*drawing*.pdf' \) 2>/dev/null | wc -l | awk '{print $1}' || echo 0)
[ "$boq_drawings" -ge 1 ] && needs_boq=true

# Determine P0 (highest priority)
P0="none"
P0_reason=""

if $needs_expense && [ "$expense_recent" -ge 2 ]; then
  P0="expense_tracker"
  P0_reason="Recent expense activity ($expense_recent slips this week)"
elif $needs_rollup && [ "$sessions_recent" -ge 2 ]; then
  P0="project_rollup"
  P0_reason="Active projects with recent updates"
elif $needs_invoice && [ "$proj_dirs" -ge 1 ]; then
  P0="invoice_editor"
  P0_reason="Projects exist but no invoice system"
elif $needs_boq && [ "$boq_drawings" -ge 1 ]; then
  P0="boq_system"
  P0_reason="CAD/drawing files found ($boq_drawings files)"
fi

echo "  ✨ Priority: $P0 ($P0_reason)"

# === Write JSON Report ===
cat > "$OUT_JSON" <<JSON
{
  "timestamp": "$(date '+%Y-%m-%d %H:%M:%S%z')",
  "scan_duration_ms": 0,
  "inventory": {
    "projects": {
      "dirs": $proj_dirs,
      "files": $proj_files,
      "recent_files": $proj_recent
    },
    "expense_slips": {
      "total": $expense_total,
      "recent_week": $expense_recent
    },
    "sessions": {
      "total": $sessions_count,
      "recent": $sessions_recent
    },
    "memory": {
      "files": $mem_files,
      "size": "$mem_size"
    },
    "queues": {
      "llm_pending": $llm_pending,
      "rd_pending": $rd_pending,
      "rd_proposals": $rd_proposals
    },
    "telemetry": {
      "lines": $tel_total,
      "recent_lines": $tel_recent,
      "recent_cost_usd": $tel_cost
    },
    "boq_potential": {
      "drawing_files": $boq_drawings
    }
  },
  "inferred_needs": {
    "expense_tracker": $needs_expense,
    "project_rollup": $needs_rollup,
    "invoice_editor": $needs_invoice,
    "boq_system": $needs_boq
  },
  "priority": {
    "P0": "$P0",
    "reason": "$P0_reason"
  }
}
JSON

# === Write Markdown Report ===
cat > "$OUT_MD" <<MD
# Local Truth Analysis
**Generated:** $(date '+%Y-%m-%d %H:%M:%S')

## 📊 System Inventory

### Projects
- **Directories:** $proj_dirs
- **Files:** $proj_files
- **Recent activity:** $proj_recent files (past 7 days)

### Expense Slips
- **Total:** $expense_total images/PDFs
- **This week:** $expense_recent new slips

### Sessions & Memory
- **Sessions:** $sessions_count total, $sessions_recent recent
- **Memory:** $mem_files files (~$mem_size)

### Work Queues
- **LLM pending:** $llm_pending
- **RD pending:** $rd_pending
- **RD proposals:** $rd_proposals

### Telemetry
- **Total lines:** $tel_total
- **Recent cost:** \$$tel_cost
$tel_providers

### BOQ Potential
- **Drawing files found:** $boq_drawings

---

## 🎯 Inferred Needs (Data-Driven)

$(if $needs_expense; then echo "- ✅ **Expense Tracker** - Found $expense_total slips ($expense_recent recent)"; else echo "- ⬜ Expense Tracker - No slips found"; fi)
$(if $needs_rollup; then echo "- ✅ **Project Rollup** - $proj_dirs active projects"; else echo "- ⬜ Project Rollup - Insufficient project activity"; fi)
$(if $needs_invoice; then echo "- ✅ **Invoice Editor** - Projects exist"; else echo "- ⬜ Invoice Editor - No projects yet"; fi)
$(if $needs_boq; then echo "- ✅ **BOQ System** - $boq_drawings drawing files found"; else echo "- ⬜ BOQ System - No CAD/drawings"; fi)

---

## 🚀 Recommended Priority

**P0:** \`$P0\`
**Reason:** $P0_reason

---

## 📋 Next Actions (Suggested)

1. Review this analysis
2. If P0 is correct → approve relevant WO in \`bridge/outbox/RD/\`
3. If P0 needs adjustment → manually prioritize
4. Run this scanner daily to track changes

---

**Report location:** \`$REPORT_DIR\`
MD

# === Write HTML Report (Interactive) ===
cat > "$OUT_HTML" <<'HTML'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8"/>
<title>Local Truth Analysis</title>
<meta name="viewport" content="width=device-width,initial-scale=1"/>
<style>
* { margin: 0; padding: 0; box-sizing: border-box; }
body {
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif;
  background: #0a0e14;
  color: #e5e9f0;
  padding: 24px;
  line-height: 1.6;
}
.container { max-width: 1200px; margin: 0 auto; }
h1 {
  font-size: 28px;
  margin-bottom: 8px;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
}
.timestamp { color: #88c0d0; font-size: 14px; margin-bottom: 32px; }
.grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 16px; margin-bottom: 32px; }
.card {
  background: #1a1f2e;
  border: 1px solid #2e3440;
  border-radius: 12px;
  padding: 20px;
}
.card h2 {
  font-size: 16px;
  color: #88c0d0;
  margin-bottom: 12px;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}
.metric {
  display: flex;
  justify-content: space-between;
  padding: 8px 0;
  border-bottom: 1px solid #2e3440;
}
.metric:last-child { border-bottom: none; }
.metric .label { color: #d8dee9; }
.metric .value {
  font-weight: 600;
  color: #88c0d0;
}
.priority {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  border-radius: 12px;
  padding: 24px;
  margin-bottom: 32px;
  text-align: center;
}
.priority h2 { color: white; font-size: 18px; margin-bottom: 12px; }
.priority .p0 {
  font-size: 32px;
  font-weight: 700;
  color: #ffffff;
  margin: 12px 0;
  text-transform: uppercase;
  letter-spacing: 1px;
}
.priority .reason { color: #e5e9f0; font-size: 14px; font-style: italic; }
.needs { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 12px; }
.need {
  background: #1a1f2e;
  border: 2px solid #2e3440;
  border-radius: 8px;
  padding: 16px;
  display: flex;
  align-items: center;
  gap: 12px;
}
.need.active { border-color: #88c0d0; background: #1e2530; }
.need .icon { font-size: 24px; }
.need .text { flex: 1; }
.need .name { font-weight: 600; color: #e5e9f0; }
.need .detail { font-size: 13px; color: #88c0d0; }
.actions {
  background: #1a1f2e;
  border: 1px solid #2e3440;
  border-radius: 12px;
  padding: 20px;
}
.actions h2 { color: #88c0d0; margin-bottom: 16px; }
.actions ol { margin-left: 20px; }
.actions li { margin: 8px 0; color: #d8dee9; }
code {
  background: #0a0e14;
  border: 1px solid #2e3440;
  border-radius: 4px;
  padding: 2px 6px;
  font-family: "SF Mono", Monaco, monospace;
  font-size: 13px;
  color: #88c0d0;
}
</style>
</head>
<body>
<div class="container">
  <h1>🔍 Local Truth Analysis</h1>
  <div class="timestamp" id="timestamp"></div>

  <div class="priority">
    <h2>Recommended Priority</h2>
    <div class="p0" id="p0"></div>
    <div class="reason" id="reason"></div>
  </div>

  <div class="grid">
    <div class="card">
      <h2>📊 Projects</h2>
      <div class="metric"><span class="label">Directories</span><span class="value" id="proj_dirs"></span></div>
      <div class="metric"><span class="label">Files</span><span class="value" id="proj_files"></span></div>
      <div class="metric"><span class="label">Recent (7d)</span><span class="value" id="proj_recent"></span></div>
    </div>

    <div class="card">
      <h2>🧾 Expense Slips</h2>
      <div class="metric"><span class="label">Total</span><span class="value" id="exp_total"></span></div>
      <div class="metric"><span class="label">This week</span><span class="value" id="exp_recent"></span></div>
    </div>

    <div class="card">
      <h2>📝 Sessions</h2>
      <div class="metric"><span class="label">Total</span><span class="value" id="sess_total"></span></div>
      <div class="metric"><span class="label">Recent</span><span class="value" id="sess_recent"></span></div>
    </div>

    <div class="card">
      <h2>💰 Telemetry</h2>
      <div class="metric"><span class="label">Lines</span><span class="value" id="tel_lines"></span></div>
      <div class="metric"><span class="label">Recent cost</span><span class="value" id="tel_cost"></span></div>
    </div>
  </div>

  <div class="card" style="margin-bottom: 32px;">
    <h2>🎯 Inferred Needs</h2>
    <div class="needs" id="needs"></div>
  </div>

  <div class="actions">
    <h2>📋 Next Actions</h2>
    <ol>
      <li>Review this data-driven analysis</li>
      <li>If P0 is correct → check <code>~/02luka/bridge/outbox/RD/</code> for proposals</li>
      <li>If P0 needs adjustment → manually prioritize</li>
      <li>Run scanner daily to track changes: <code>~/02luka/tools/local_truth_scan.zsh</code></li>
    </ol>
  </div>
</div>

<script>
// Load data from JSON file (assumes same directory)
fetch('./local_truth.json')
  .then(r => r.json())
  .then(data => {
    document.getElementById('timestamp').textContent = data.timestamp;
    document.getElementById('p0').textContent = data.priority.P0.replace(/_/g, ' ');
    document.getElementById('reason').textContent = data.priority.reason;

    document.getElementById('proj_dirs').textContent = data.inventory.projects.dirs;
    document.getElementById('proj_files').textContent = data.inventory.projects.files;
    document.getElementById('proj_recent').textContent = data.inventory.projects.recent_files;

    document.getElementById('exp_total').textContent = data.inventory.expense_slips.total;
    document.getElementById('exp_recent').textContent = data.inventory.expense_slips.recent_week;

    document.getElementById('sess_total').textContent = data.inventory.sessions.total;
    document.getElementById('sess_recent').textContent = data.inventory.sessions.recent;

    document.getElementById('tel_lines').textContent = data.inventory.telemetry.lines;
    document.getElementById('tel_cost').textContent = '$' + data.inventory.telemetry.recent_cost_usd;

    // Needs
    const needs = [
      { key: 'expense_tracker', icon: '🧾', name: 'Expense Tracker', detail: data.inventory.expense_slips.total + ' slips found' },
      { key: 'project_rollup', icon: '📊', name: 'Project Rollup', detail: data.inventory.projects.dirs + ' active projects' },
      { key: 'invoice_editor', icon: '📄', name: 'Invoice Editor', detail: 'For client billing' },
      { key: 'boq_system', icon: '📐', name: 'BOQ System', detail: data.inventory.boq_potential.drawing_files + ' drawings' }
    ];

    const needsHtml = needs.map(n => {
      const active = data.inferred_needs[n.key] ? 'active' : '';
      const icon = data.inferred_needs[n.key] ? '✅' : '⬜';
      return `<div class="need ${active}"><div class="icon">${icon}</div><div class="text"><div class="name">${n.name}</div><div class="detail">${n.detail}</div></div></div>`;
    }).join('');

    document.getElementById('needs').innerHTML = needsHtml;
  })
  .catch(e => {
    document.getElementById('timestamp').textContent = 'Error loading data: ' + e.message;
  });
</script>
</body>
</html>
HTML

# === Create TODO/roadmap as plain files (for manual review) ===

# Check roadmap progress if exists
ROADMAP_PROGRESS=""
if [[ -f "$ROOT/g/progress/current_progress.json" ]]; then
  ROADMAP_NAME=$(jq -r '.roadmap_name' "$ROOT/g/progress/current_progress.json" 2>/dev/null || echo "")
  OVERALL_PCT=$(jq -r '.overall_progress_pct' "$ROOT/g/progress/current_progress.json" 2>/dev/null || echo "")
  CURRENT_PHASE=$(jq -r '.current_phase' "$ROOT/g/progress/current_progress.json" 2>/dev/null || echo "")
  PHASE_PCT=$(jq -r '.current_phase_pct' "$ROOT/g/progress/current_progress.json" 2>/dev/null || echo "")

  if [[ -n "$ROADMAP_NAME" ]]; then
    ROADMAP_PROGRESS="## 🗺️ Current Roadmap Progress

**Roadmap:** $ROADMAP_NAME
**Overall:** ${OVERALL_PCT}% complete
**Current Phase:** $CURRENT_PHASE (${PHASE_PCT}%)

**Check full status:** \`~/02luka/tools/show_progress.zsh\`

---

"
  fi
fi

cat > "$REPORT_DIR/TODO.md" <<TODO
# Automated TODO List (Generated from Local Data)

Based on scan at $(date '+%Y-%m-%d %H:%M:%S')

$ROADMAP_PROGRESS
## Priority 0: $P0
**Reason:** $P0_reason

**Action:** Review and approve relevant WO in \`~/02luka/bridge/outbox/RD/\`

---

## All Inferred Needs

$(if $needs_expense; then echo "### ✅ Expense Tracker"; echo "- Found: $expense_total slips ($expense_recent recent)"; echo "- Action: Build OCR → categorization → HTML ledger"; echo ""; fi)
$(if $needs_rollup; then echo "### ✅ Project Weekly Rollup"; echo "- Found: $proj_dirs projects with $proj_recent recent files"; echo "- Action: Build multi-project summary → client-ready HTML"; echo ""; fi)
$(if $needs_invoice; then echo "### ✅ Invoice/Quotation Editor"; echo "- Found: Projects exist but no billing system"; echo "- Action: Build editable invoice templates"; echo ""; fi)
$(if $needs_boq; then echo "### ✅ BOQ System"; echo "- Found: $boq_drawings CAD/drawing files"; echo "- Action: Build plan parser → quantity extraction → pricing"; echo ""; fi)

---

## Maintenance Tasks

- [ ] Review daily digest
- [ ] Check pending WOs in \`outbox/RD/pending/\`
- [ ] Monitor telemetry costs
- [ ] Archive old sessions (>30 days)

TODO

echo "✅ Analysis complete!"
echo ""
echo "📊 Reports generated:"
echo "  • JSON:  $OUT_JSON"
echo "  • MD:    $OUT_MD"
echo "  • HTML:  $OUT_HTML"
echo "  • TODO:  $REPORT_DIR/TODO.md"
echo ""
echo "🌐 Open in browser:"
echo "  open $OUT_HTML"
