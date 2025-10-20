#!/usr/bin/env node
/* Query layer: FTS search, vector recall (TF-IDF cosine), stats, exports */
const fs = require('fs');
const path = require('path');
const sqlite3 = require('sqlite3').verbose();

const ROOT = path.resolve(__dirname, '..');
const DB_PATH = path.join(ROOT, 'knowledge', '02luka.db');

const args = process.argv.slice(2);
const mode = args[0];

main().catch(e=>{console.error(e);process.exit(1);});

async function main(){
  if (!fs.existsSync(DB_PATH)) {
    console.error('Database not found. Run: node knowledge/sync.cjs --full --export');
    process.exit(1);
  }

  const db = await open(DB_PATH);
  
  if (mode === '--search') {
    const q = args.slice(1).join(' ');
    const rows = await all(db, `SELECT m.id, m.kind, snippet(memories_fts, 0, '[', ']', '…', 10) AS snippet
                                FROM memories_fts JOIN memories m ON memories_fts.rowid = m.rowid
                                WHERE memories_fts MATCH ? LIMIT 20`, [q]);
    console.log(JSON.stringify({query:q, results:rows}, null, 2));
  } else if (mode === '--recall') {
    const q = args.slice(1).join(' ');
    const rows = await all(db, `SELECT id, kind, text, vector FROM memories`);
    const scored = scoreCosine(q, rows).sort((a,b)=>b.score-a.score).slice(0,10);
    console.log(JSON.stringify({query:q, results:scored}, null, 2));
  } else if (mode === '--stats') {
    const counts = await one(db, `SELECT COUNT(*) as memories FROM memories`);
    const tel = await one(db, `SELECT COUNT(*) as entries FROM telemetry`);
    const reps = await one(db, `SELECT COUNT(*) as reports FROM reports`);
    console.log(JSON.stringify({counts, tel, reps}, null, 2));
  } else if (mode === '--export') {
    // light wrapper to call sync with --export
    const {spawnSync} = require('child_process');
    const res = spawnSync('node', [path.join(ROOT,'knowledge','sync.cjs'),'--export'], {stdio:'inherit'});
    process.exit(res.status || 0);
  } else {
    console.log(`Usage:
  node knowledge/index.cjs --search "query"
  node knowledge/index.cjs --recall "query"
  node knowledge/index.cjs --stats
  node knowledge/index.cjs --export`);
  }
  db.close();
}

function tokenize(s){ return (s||'').toLowerCase().split(/[^a-zA-Z0-9_]+/).filter(Boolean); }
function tf(tokens){ const m=new Map(); for (const t of tokens) m.set(t,(m.get(t)||0)+1); const n=tokens.length||1; for (const [k,v] of m) m.set(k, v/n); return m; }
function dot(a,b){ let sum=0; for (const [k,v] of a) if (b.has(k)) sum += v*b.get(k); return sum; }
function norm(a){ let s=0; for (const v of a.values()) s+=v*v; return Math.sqrt(s)||1; }
function scoreCosine(q, rows){
  const qtf = tf(tokenize(q));
  return rows.map(r=>{
    // Stored vectors are JSON TF-IDF objects
    let v = {};
    try { v = JSON.parse(r.vector||'{}'); } catch {}
    // Convert stored vector/object into Map
    const m = new Map(Object.entries(v).map(([k,val])=>[k, Number(val)||0]));
    const score = dot(qtf, m) / (norm(qtf)*norm(m));
    return { id:r.id, kind:r.kind, text:r.text, score: Number.isFinite(score)? Number(score.toFixed(3)) : 0 };
  });
}

function open(p){ return new Promise((res,rej)=>{ const db=new sqlite3.Database(p, e=>e?rej(e):res(db));});}
function all(db,q,params){ return new Promise((res,rej)=>db.all(q,params,(e,rows)=>e?rej(e):res(rows))); }
function one(db,q,params){ return new Promise((res,rej)=>db.get(q,params,(e,row)=>e?rej(e):res(row))); }
