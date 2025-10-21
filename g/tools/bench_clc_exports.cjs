const { execSync } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');

function run(cmd, env) {
  const t0 = Date.now();
  try {
    execSync(cmd, { stdio: 'ignore', env: { ...process.env, ...env } });
    const t1 = Date.now();
    return { ok:true, ms:t1-t0 };
  } catch (e) {
    const t1 = Date.now();
    return { ok:false, ms:t1-t0, err:String(e) };
  }
}

const ROOT = process.argv[2] || '.';
const SYNC = path.join(ROOT, 'knowledge', 'sync.cjs');
const REP  = path.join(ROOT, 'g', 'reports', '251021_drive_bench.md');

const cases = [
  { name:'off',   env:{ KNOW_EXPORT_MODE:'off' } },
  { name:'local', env:{ KNOW_EXPORT_MODE:'local', KNOW_EXPORT_DIR: path.join(ROOT,'.exports_local') } },
  { name:'drive', env:{ KNOW_EXPORT_MODE:'drive' } },
];

let rows = [];
for (const c of cases) {
  const r = run(`node "${SYNC}"`, c.env);
  rows.push({ mode:c.name, ok:r.ok, ms:r.ms, err:r.err||'' });
}

const md = [
  '# 251021 – CLC Export Benchmark',
  '',
  '| Mode  | Result | Duration (s) | Notes |',
  '|------:|:------:|-------------:|-------|',
  ...rows.map(x => `| ${x.mode} | ${x.ok?'✅':'❌'} | ${(x.ms/1000).toFixed(2)} | ${x.err.replace(/\|/g, '\\|').slice(0,120)} |`)
].join('\n');

fs.writeFileSync(REP, md);
console.log('Wrote', REP);
