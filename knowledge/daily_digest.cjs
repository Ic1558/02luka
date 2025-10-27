#!/usr/bin/env node
// Daily digest for web_actions.jsonl -> g/reports/daily_digest_YYYYMMDD.{json,csv}
// Usage: node knowledge/daily_digest.cjs [--date=YYYY-MM-DD] [--in=g/telemetry/web_actions.jsonl]
const fs = require('fs');
const readline = require('readline');

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
    digest.push({
      pattern,
      samples: arr.length,
      avg_ms: avg !== null ? Number(avg.toFixed(2)) : null,
      p50_ms: p50,
      p95_ms: p95,
      p99_ms: p99,
      slow_flag: !!slow
    });
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
