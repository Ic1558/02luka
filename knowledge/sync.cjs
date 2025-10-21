#!/usr/bin/env node
/* Syncs g/memory, g/telemetry, g/reports into knowledge/02luka.db and exports JSON/MD */
const fs = require('fs');
const fsp = require('fs').promises;
const path = require('path');
const os = require('os');
const sqlite3 = require('sqlite3').verbose();

const ROOT = path.resolve(__dirname, '..');
const DB_PATH = path.join(ROOT, 'knowledge', '02luka.db');
const SCHEMA = path.join(ROOT, 'knowledge', 'schema.sql');
const VEC_SRC = path.join(ROOT, 'g', 'memory', 'vector_index.json');
const TEL_DIR = path.join(ROOT, 'g', 'telemetry');
const REP_DIR = path.join(ROOT, 'g', 'reports');
const EXP_DIR = path.join(ROOT, 'knowledge', 'exports');

const args = process.argv.slice(2);
const FULL = args.includes('--full');
const DO_EXPORT = args.includes('--export');
const EXPORT_DIRECT = process.env.EXPORT_DIRECT === '1' || args.includes('--export-direct');

main().catch(e => { console.error(e); process.exit(1); });

async function main() {
  ensureDirs();
  const db = await open(DB_PATH);
  await execSQL(db, fs.readFileSync(SCHEMA, 'utf8'));

  const stats = { inserted: {mem:0,tel:0,rep:0}, updated: {mem:0} };

  // 1) Memories (vector_index.json)
  if (fs.existsSync(VEC_SRC)) {
    const ix = JSON.parse(fs.readFileSync(VEC_SRC, 'utf8'));
    const memories = ix.memories || [];
    for (const m of memories) {
      const id = m.id || hash(`${m.kind}:${m.timestamp}:${m.text.slice(0,64)}`);
      const row = {
        $id: id,
        $kind: m.kind || null,
        $text: m.text || '',
        $importance: m.importance ?? null,
        $queryCount: m.queryCount ?? 0,
        $lastAccess: m.lastAccess || null,
        $timestamp: m.timestamp || null,
        $meta: JSON.stringify(m.meta || {}),
        $tokens: JSON.stringify(m.tokens || []),
        $vector: JSON.stringify(m.vector || {})
      };
      const exists = await getOne(db, 'SELECT id FROM memories WHERE id = ?', [id]);
      if (exists) {
        await run(db, `UPDATE memories SET kind=$kind,text=$text,importance=$importance,queryCount=$queryCount,lastAccess=$lastAccess,timestamp=$timestamp,meta=$meta,tokens=$tokens,vector=$vector WHERE id=$id`, row);
        stats.updated.mem++;
      } else {
        await run(db, `INSERT INTO memories (id,kind,text,importance,queryCount,lastAccess,timestamp,meta,tokens,vector)
                       VALUES ($id,$kind,$text,$importance,$queryCount,$lastAccess,$timestamp,$meta,$tokens,$vector)`, row);
        await run(db, `INSERT INTO memories_fts(rowid,text) SELECT rowid, text FROM memories WHERE id=$id`, {$id:id});
        stats.inserted.mem++;
      }
    }
  }

  // 2) Telemetry (NDJSON files)
  if (fs.existsSync(TEL_DIR)) {
    const files = fs.readdirSync(TEL_DIR).filter(f => f.endsWith('.log'));
    for (const f of files) {
      const lines = fs.readFileSync(path.join(TEL_DIR, f), 'utf8').trim().split(/\r?\n/);
      for (const line of lines) {
        if (!line.trim()) continue;
        try {
          const e = JSON.parse(line);
          const row = {
            $ts: e.ts || e.timestamp || null,
            $task: e.task || null,
            $pass: e.pass ?? null,
            $warn: e.warn ?? null,
            $fail: e.fail ?? null,
            $duration: e.duration_ms ?? e.duration ?? null,
            $meta: JSON.stringify(e.meta || {})
          };
          // Simple idempotency: skip if same ts+task+duration exists
          const exists = await getOne(db,
            `SELECT id FROM telemetry WHERE ts=$ts AND task=$task AND duration_ms=$duration`, {$ts:row.$ts,$task:row.$task,$duration:row.$duration});
          if (!exists) {
            await run(db, `INSERT INTO telemetry (ts,task,pass,warn,fail,duration_ms,meta)
                           VALUES ($ts,$task,$pass,$warn,$fail,$duration,$meta)`, row);
            stats.inserted.tel++;
          }
        } catch (_) {}
      }
    }
  }

  // 3) Reports (markdown)
  if (fs.existsSync(REP_DIR)) {
    const files = fs.readdirSync(REP_DIR).filter(f => f.endsWith('.md'));
    for (const f of files) {
      const p = path.join(REP_DIR, f);
      const content = fs.readFileSync(p, 'utf8');
      const row = {
        $filename: f,
        $type: inferType(f),
        $generated: guessIsoFromName(f),
        $content: content,
        $metadata: JSON.stringify({})
      };
      const exists = await getOne(db, `SELECT id FROM reports WHERE filename=$filename`, {$filename:f});
      if (!exists || FULL) {
        if (exists) await run(db, `DELETE FROM reports WHERE filename=$filename`, {$filename:f});
        await run(db, `INSERT INTO reports (filename,type,generated,content,metadata)
                       VALUES ($filename,$type,$generated,$content,$metadata)`, row);
        const lastId = await getOne(db, `SELECT last_insert_rowid() as id`);
        await run(db, `INSERT INTO reports_fts(rowid, content) VALUES (?, ?)`, [lastId.id, content]);
        stats.inserted.rep++;
      }
    }
  }

  // Exports
  if (DO_EXPORT) await exportJSON(db);

  console.log(JSON.stringify({ok:true, stats}, null, 2));
  db.close();
}

function ensureDirs(){
  if (!fs.existsSync(EXP_DIR)) fs.mkdirSync(EXP_DIR, {recursive:true});
}

function open(p){ return new Promise((res,rej)=>{ const db=new sqlite3.Database(p, e=>e?rej(e):res(db)); }); }
function execSQL(db, s){ return new Promise((res,rej)=>db.exec(s, e=>e?rej(e):res())); }
function run(db,q,params){ return new Promise((res,rej)=>db.run(q,params,function(e){e?rej(e):res(this);})); }
function getOne(db,q,params){ return new Promise((res,rej)=>db.get(q,params||[],(e,row)=>e?rej(e):res(row))); }

function hash(s){ let h=0; for (let i=0;i<s.length;i++) h=((h<<5)-h)+s.charCodeAt(i)|0; return 'm_'+(h>>>0).toString(16); }
function inferType(f){ if (/SELF_REVIEW|self_review/i.test(f)) return 'self_review'; if (/PHASE|OPS/i.test(f)) return 'ops'; return 'report'; }
function guessIsoFromName(f){ const m=f.match(/\d{4}-\d{2}-\d{2}T[\d-]+Z|\d{8,}/); return m?m[0]:null; }

async function exportJSON(db){
  const all = (q)=>new Promise((res,rej)=>db.all(q,[],(e,rows)=>e?rej(e):res(rows)));

  // Temp-then-move pattern: write to local temp first, then atomic rename to Google Drive
  const tmpRoot = process.env.EXPORT_TMP_DIR || path.join(os.tmpdir(), '02luka-exports');
  const tmpOut = EXPORT_DIRECT ? EXP_DIR : path.join(tmpRoot, String(process.pid));
  const finalOut = EXP_DIR;

  console.log(`\n[export] mode: ${EXPORT_DIRECT ? 'direct-to-drive' : 'temp-then-move'}`);

  // Ensure temp directory exists
  await fsp.mkdir(tmpOut, { recursive: true });

  // Prepare data
  const artifacts = [
    { name: 'memories.json', data: JSON.stringify(await all('SELECT * FROM memories'), null, 2) },
    { name: 'telemetry.json', data: JSON.stringify(await all('SELECT * FROM telemetry'), null, 2) },
    { name: 'reports.index.json', data: JSON.stringify(await all('SELECT id, filename, type, generated FROM reports'), null, 2) }
  ];

  // Write files
  for (const a of artifacts) {
    const tmpFile = path.join(tmpOut, a.name);
    process.stdout.write(`  • writing ${a.name}... `);
    await fsp.writeFile(tmpFile, a.data, 'utf8');
    process.stdout.write('✓\n');
  }

  // Atomic move to final destination if using temp path
  if (!EXPORT_DIRECT) {
    process.stdout.write('  • staging → drive... ');
    await fsp.mkdir(finalOut, { recursive: true });
    for (const a of artifacts) {
      const src = path.join(tmpOut, a.name);
      const dst = path.join(finalOut, a.name);
      await fsp.rename(src, dst);
    }
    // Clean up temp directory
    await fsp.rm(tmpOut, { recursive: true, force: true }).catch(() => {});
    process.stdout.write('✓\n');
  }

  console.log('[export] complete\n');
}
