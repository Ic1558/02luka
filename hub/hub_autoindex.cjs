// @created_by: GG_Agent_02luka
// @phase: 20
// @file: hub_autoindex.cjs
import fs from 'fs';
import fsp from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';
import crypto from 'crypto';
import { createClient } from 'redis';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const ENV = {
  MEM_ROOT: process.env.LUKA_MEM_REPO_ROOT || path.join(process.env.HOME||'', 'LocalProjects/02luka-memory'),
  INDEX_PATH: process.env.HUB_INDEX_PATH || path.join(__dirname, 'index.json'),
  REDIS_URL: process.env.REDIS_URL || 'redis://:gggclukaic@127.0.0.1:6379',
  CHANNEL: 'hub:index:update',
};

function safeYamlFrontMatter(md) {
  // very small YAML front-matter reader (--- ... ---)
  const s = md.trimStart();
  if (!s.startsWith('---')) return { meta:{}, body: md };
  const end = s.indexOf('\n---', 3);
  if (end === -1) return { meta:{}, body: md };
  const yml = s.slice(3, end).trim();
  const body = s.slice(end+4).replace(/^\s*\n/, '');
  const meta = {};
  for (const line of yml.split('\n')) {
    const m = line.match(/^\s*([A-Za-z0-9_\-]+)\s*:\s*(.*)\s*$/);
    if (m) {
      let v = m[2].trim();
      v = v.replace(/^"(.*)"$/, '$1').replace(/^'(.*)'$/, '$1');
      meta[m[1]] = v;
    }
  }
  return { meta, body };
}

async function collectFiles(root) {
  const out = [];
  async function walk(dir) {
    const items = await fsp.readdir(dir, { withFileTypes: true });
    for (const it of items) {
      const p = path.join(dir, it.name);
      if (it.isDirectory()) {
        await walk(p);
      } else if (/\.(md|markdown|json)$/i.test(it.name)) {
        out.push(p);
      }
    }
  }
  await walk(root);
  return out;
}

function sha256(buf){return crypto.createHash('sha256').update(buf).digest('hex');}

async function buildIndex() {
  const files = await collectFiles(ENV.MEM_ROOT);
  const rows = [];
  for (const fp of files) {
    try {
      const stat = await fsp.stat(fp);
      const rel = path.relative(ENV.MEM_ROOT, fp);
      const ext = path.extname(fp).toLowerCase();
      const buf = await fsp.readFile(fp);
      let meta={}, title="", summary="";
      if (ext === '.md' || ext === '.markdown') {
        const { meta:fm, body } = safeYamlFrontMatter(buf.toString('utf8'));
        meta = fm;
        title = (body.match(/^#\s+(.+)$/m) || [,''])[1];
        summary = body.slice(0, 400);
      } else if (ext === '.json') {
        const j = JSON.parse(buf.toString('utf8'));
        meta = j?.meta || {};
        title = j?.title || '';
        summary = JSON.stringify(j).slice(0, 400);
      }
      rows.push({
        rel,
        mtime: stat.mtime.toISOString?.() || new Date(stat.mtime).toISOString(),
        bytes: stat.size,
        kind: ext.replace('.',''),
        title,
        summary,
        meta,
        sha256: sha256(buf)
      });
    } catch(e){ /* skip broken file */ }
  }
  rows.sort((a,b)=> String(b.mtime).localeCompare(String(a.mtime)));
  const index = {
    _meta: {
      created_by: 'GG_Agent_02luka',
      created_at: new Date().toISOString(),
      source: 'hub_autoindex.cjs',
      total: rows.length,
      mem_root: ENV.MEM_ROOT
    },
    items: rows
  };
  await fsp.mkdir(path.dirname(ENV.INDEX_PATH), { recursive: true });
  await fsp.writeFile(ENV.INDEX_PATH, JSON.stringify(index, null, 2));
  return index;
}

async function publishRedis(payload) {
  try {
    const client = createClient({ url: ENV.REDIS_URL });
    await client.connect();
    await client.publish(ENV.CHANNEL, JSON.stringify(payload));
    await client.quit();
  } catch(e) {
    // log to stderr but don't fail the build
    console.error('[hub:index] redis publish failed:', e?.message||e);
  }
}

(async()=>{
  const index = await buildIndex();
  await publishRedis({ type:'hub.index.update', at:new Date().toISOString(), total:index._meta.total });
  console.log(`[hub:index] wrote → ${ENV.INDEX_PATH} (items=${index._meta.total})`);
})();
