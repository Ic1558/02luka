# WO-251027-CLS-PHASE9_2E-DAILY-DIGEST
Implement Phase 9.2-E Daily Digest end-to-end:
- Create sample telemetry (NDJSON)
- Implement knowledge/daily_digest.cjs (JSON + CSV)
- Create tools/run_daily_digest.sh wrapper
- Add systemd service+timer (Linux) and LaunchAgent plist (macOS)
- Provide test script to validate output

## 1) Sample telemetry (for local test)
Create `g/telemetry/web_actions.jsonl` if missing, with realistic lines:

{“ts”:“2025-10-26T03:12:10Z”,“pattern”:“token efficiency”,“ms”:7.2,“ok”:true,“agent”:“CLS”}
{“ts”:“2025-10-26T09:41:33Z”,“pattern”:“phase 7.2 delegation”,“ms”:12.1,“ok”:true,“agent”:“GG”}
{“ts”:“2025-10-26T11:05:00Z”,“pattern”:“system architecture”,“ms”:108.3,“ok”:true,“agent”:“Mary”}
{“ts”:“2025-10-27T01:05:55Z”,“pattern”:“token efficiency”,“ms”:6.9,“ok”:true,“agent”:“CLS”}
{“ts”:“2025-10-27T01:22:10Z”,“pattern”:“phase 7.2 delegation”,“ms”:13.9,“ok”:true,“agent”:“GG”}
{“ts”:“2025-10-27T02:40:00Z”,“pattern”:“incident correlation”,“ms”:9.5,“ok”:true,“agent”:“Paula”}
{“ts”:“2025-10-27T03:00:10Z”,“pattern”:“system architecture”,“ms”:103.2,“ok”:true,“agent”:“Mary”}
{“ts”:“2025-10-27T03:11:47Z”,“pattern”:“token efficiency”,“ms”:5.9,“ok”:true,“agent”:“CLS”}
{“ts”:“2025-10-27T03:35:01Z”,“pattern”:“boss-api v2.0”,“ms”:8.2,“ok”:true,“agent”:“Lisa”}
{“ts”:“2025-10-27T03:59:59Z”,“pattern”:“token efficiency”,“ms”:7.1,“ok”:true,“agent”:“CLS”}

## 2) Daily digest script
Create `knowledge/daily_digest.cjs`:
```
#!/usr/bin/env node
// Daily digest for web_actions.jsonl -> g/reports/daily_digest_YYYYMMDD.{json,csv}
// Usage: node knowledge/daily_digest.cjs [--date=YYYY-MM-DD] [--in=g/telemetry/web_actions.jsonl]
import fs from 'fs';
import readline from 'readline';

const args = Object.fromEntries(process.argv.slice(2).map(a=>{
  const m=a.match(/^--([^=]+)=(.*)$/); return m?[m[1],m[2]]:[a,true];
}).filter(x=>Array.isArray(x)));

const inFile = args.in || 'g/telemetry/web_actions.jsonl';
const dateStr = args.date || new Date().toISOString().slice(0,10); // local ISO date
const outJson = `g/reports/daily_digest_${dateStr.replaceAll('-','')}.json`;
const outCsv  = `g/reports/daily_digest_${dateStr.replaceAll('-','')}.csv`;

fs.mkdirSync('g/reports', { recursive: true });

function sameDay(tsISO, dStr){
  const d = new Date(tsISO);
  const iso = new Date(d.getFullYear(), d.getMonth(), d.getDate())
    .toISOString().slice(0,10);
  return iso === dStr;
}

function quantiles(sorted, qs){ // qs in [0..1]
  const n=sorted.length; if(n===0) return qs.map(()=>null);
  return qs.map(q=>{
    const idx = Math.max(0, Math.min(n-1, Math.floor(q*(n-1))));
    return sorted[idx];
  });
}

async function run(){
  if (!fs.existsSync(inFile)) {
    console.log(JSON.stringify({ok:false, reason:`missing input ${inFile}`}));
    process.exit(0);
  }
  const rl = readline.createInterface({ input: fs.createReadStream(inFile) });
  const rows = [];
  for await (const line of rl) {
    if (!line.trim()) continue;
    try {
      const j = JSON.parse(line);
      if (!j.ts || !j.pattern || typeof j.ms!=='number') continue;
      if (sameDay(j.ts, dateStr)) rows.push(j);
    } catch(e) {}
  }
  const byPattern = new Map();
  for (const r of rows){
    const key = r.pattern;
    if(!byPattern.has(key)) byPattern.set(key, []);
    byPattern.get(key).push(r.ms);
  }
  const digest = [];
  for (const [pattern, arr] of byPattern){
    arr.sort((a,b)=>a-b);
    const sum = arr.reduce((a,b)=>a+b,0);
    const avg = arr.length ? sum/arr.length : null;
    const [p50,p95,p99] = quantiles(arr, [0.5,0.95,0.99]);
    const slow = (p95!==null && p95>100); // threshold 100ms
    digest.push({ pattern, samples: arr.length, avg_ms:+avg?.toFixed?.(2), p50_ms:p50, p95_ms:p95, p99_ms:p99, slow_flag: !!slow });
  }
  // sort: slow first, then by samples
  digest.sort((a,b)=> (Number(b.slow_flag)-Number(a.slow_flag)) || (b.samples-a.samples));

  const out = {
    ok: true,
    date: dateStr,
    total_samples: rows.length,
    patterns: digest
  };
  fs.writeFileSync(outJson, JSON.stringify(out, null, 2));
  // CSV
  const csvHead = 'pattern,samples,avg_ms,p50_ms,p95_ms,p99_ms,slow_flag\n';
  const csvBody = digest.map(d=>`"${d.pattern.replaceAll('"','""')}",${d.samples},${d.avg_ms ?? ''},${d.p50_ms ?? ''},${d.p95_ms ?? ''},${d.p99_ms ?? ''},${d.slow_flag}`).join('\n');
  fs.writeFileSync(outCsv, csvHead+csvBody+'\n');

  console.log(JSON.stringify({ok:true, outJson, outCsv, date: dateStr, counts: digest.length}));
}
run();
```

3) Wrapper

Create tools/run_daily_digest.sh:

```
#!/usr/bin/env bash
set -euo pipefail
ROOT="${GITHUB_WORKSPACE:-$HOME/02luka}"
cd "$ROOT"
mkdir -p g/reports
DATE="${1:-$(date +%F)}"
node knowledge/daily_digest.cjs --date="$DATE" --in="g/telemetry/web_actions.jsonl"
echo "Daily digest done for $DATE"
```

Make executable.

4) systemd (Linux)

Create systemd/units/02luka-daily-digest.service:

```
[Unit]
Description=02luka Daily Digest

[Service]
Type=oneshot
WorkingDirectory=%h/02luka
ExecStart=/usr/bin/env bash tools/run_daily_digest.sh
```

Create systemd/units/02luka-daily-digest.timer:

```
[Unit]
Description=Run 02luka Daily Digest at 02:30

[Timer]
OnCalendar=*-*-* 02:30:00
Persistent=true

[Install]
WantedBy=timers.target
```

5) LaunchAgent (macOS)

Create LaunchAgents/com.02luka.daily-digest.plist:

```
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.02luka.daily-digest</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>/Users/$(whoami)/02luka/tools/run_daily_digest.sh</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key><integer>2</integer>
    <key>Minute</key><integer>30</integer>
  </dict>
  <key>StandardOutPath</key><string>/Users/$(whoami)/02luka/g/reports/daily_digest.log</string>
  <key>StandardErrorPath</key><string>/Users/$(whoami)/02luka/g/reports/daily_digest.err</string>
  <key>RunAtLoad</key><true/>
</dict>
</plist>
```

6) Test script

Create scripts/test_daily_digest.sh:

```
#!/usr/bin/env bash
set -euo pipefail
ROOT="${GITHUB_WORKSPACE:-$HOME/02luka}"
cd "$ROOT"
# ensure sample telemetry exists
mkdir -p g/telemetry g/reports
test -s g/telemetry/web_actions.jsonl || {
  echo '{"ts":"'"$(date -Iseconds)"'","pattern":"token efficiency","ms":7.0,"ok":true,"agent":"CLS"}' >> g/telemetry/web_actions.jsonl
}
DATE="${1:-$(date +%F)}"
bash tools/run_daily_digest.sh "$DATE"
ls g/reports/daily_digest_*.json >/dev/null
ls g/reports/daily_digest_*.csv  >/dev/null
echo "OK: daily digest generated for $DATE"
```

Make executable.

7) Acceptance
•Running bash scripts/test_daily_digest.sh produces both JSON and CSV under g/reports/daily_digest_YYYYMMDD.*.
•tools/run_daily_digest.sh succeeds on default date.
•On Linux: systemd units present under systemd/units/ (admin can link+enable).
•On macOS: LaunchAgent plist present (admin can load via launchctl).
•Sample telemetry file exists or is generated.

Mapping to pending todos
•todo-…-blf4hqqb9 -> Sample telemetry files ✅
•todo-…-hwuzjb9g4 -> Implement daily_digest.cjs ✅
•todo-…-g7163wz94 -> run_daily_digest.sh wrapper ✅
•todo-…-ebet2nn9x -> systemd service+timer ✅
•todo-…-sbqejq637 -> LaunchAgent plist ✅
•todo-…-dy6mma5lz -> Test digest generation ✅
