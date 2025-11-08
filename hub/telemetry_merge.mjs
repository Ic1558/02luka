import fs from 'fs';
import path from 'path';

const env = (k,d='') => process.env[k] ?? d;
const LUKA_HOME = env('LUKA_HOME', path.join(process.env.HOME||'', '02luka'));
const CFG_PATH = path.join(process.cwd(),'config','telemetry_router.yaml');

function loadYAML(p){
  const y = require('child_process').spawnSync('yq',['-o','json',p],{encoding:'utf8'});
  if(y.status!==0) throw new Error('yq fail: '+y.stderr);
  return JSON.parse(y.stdout);
}

function readJsonSafe(p){
  try { return JSON.parse(fs.readFileSync(p,'utf8')); }
  catch { return null; }
}

function* iterateInputs(inputs){
  for(const rel of inputs){
    const p = rel.replace('${LUKA_HOME:-$HOME/02luka}', LUKA_HOME).replace('$HOME',process.env.HOME||'');
    const ab = path.isAbsolute(p) ? p : path.join(process.cwd(),p);
    const j = readJsonSafe(ab);
    if(!j) continue;
    if(j.items && Array.isArray(j.items)){
      for(const it of j.items){
        yield normalize(it, path.basename(ab));
      }
    }else{
      yield normalize(j, path.basename(ab));
    }
  }
}

function normalize(it, source){
  // map common shapes to unified telemetry
  const level = it.level || inferLevelFromSource(source) || 'info';
  const message = it.message || it.reason || it.status || source;
  return {
    ts: new Date().toISOString(),
    level,
    source,
    data: it
  };
}

function inferLevelFromSource(src){
  if(/health|selfcheck/.test(src)) return 'warn';
  return 'info';
}

function route(events, cfg){
  const out = [];
  for(const ev of events){
    const lvl = ev.level;
    const matched = cfg.rules.find(r => Array.isArray(r.match?.level) ? r.match.level.includes(lvl) : true);
    const routes = matched ? matched.route : ['file_unified'];
    out.push({ev, routes});
  }
  return out;
}

function ensureDir(p){ fs.mkdirSync(path.dirname(p), {recursive:true}); }

function writeFileSink(p, lines){
  ensureDir(p);
  const fd = fs.openSync(p,'a');
  for(const l of lines) fs.writeSync(fd, JSON.stringify(l)+'\n');
  fs.closeSync(fd);
}

function sendRedis(lines, sink){
  const { spawnSync } = require('child_process');
  for(const l of lines){
    const payload = JSON.stringify(l);
    const cmd = [
      'redis-cli',
      ...(sink.auth ? ['-a', sink.auth] : []),
      '-h', sink.host||'127.0.0.1',
      '-p', String(sink.port||6379),
      'PUBLISH', sink.channel||'telemetry:events', payload
    ];
    spawnSync(cmd[0], cmd.slice(1), {stdio:'ignore'});
  }
}

async function sendTelegram(lines, sink){
  const token = sink.bot_token, chat = sink.chat_id;
  if(!token || !chat) return;
  const { spawnSync } = require('child_process');
  for(const l of lines){
    const txt = `[${l.level}] ${l.source}\n`+ (l.data?.message || l.data?.status || 'event');
    const url = `https://api.telegram.org/bot${token}/sendMessage`;
    spawnSync('curl', ['-sS','-X','POST',url,'-d',`chat_id=${chat}`,'-d',`text=${txt}`], {stdio:'ignore'});
  }
}

(async ()=>{
  const cfg = loadYAML(CFG_PATH);
  const events = Array.from(iterateInputs(cfg.ingest.inputs));
  // batch by routes
  const routed = route(events, cfg);

  const bySink = {};
  for(const {ev, routes} of routed){
    for(const s of routes){
      bySink[s] = bySink[s] || [];
      bySink[s].push(ev);
    }
  }

  // emit
  for(const [name, lines] of Object.entries(bySink)){
    const sink = cfg.sinks[name];
    if(!sink) continue;
    if(sink.type==='file'){
      const p = (sink.path||'').replace('${LUKA_HOME:-$HOME/02luka}', LUKA_HOME).replace('$HOME',process.env.HOME||'');
      writeFileSink(p, lines);
    }else if(sink.type==='redis'){
      sendRedis(lines, sink);
    }else if(sink.type==='telegram'){
      await sendTelegram(lines, sink);
    }
  }

  // write merge snapshot for dashboard
  const snap = {
    _meta:{created_by:'GG_Agent_02luka', created_at:new Date().toISOString(), source:'telemetry_merge.mjs'},
    count: events.length
  };
  ensureDir('hub/'); fs.writeFileSync('hub/telemetry_snapshot.json', JSON.stringify(snap,null,2));
})();
