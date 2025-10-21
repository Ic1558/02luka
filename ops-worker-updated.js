export default {
  async fetch(req, env) {
    const url = new URL(req.url);
    if (req.method === 'GET' && url.pathname === '/api/ping')
      return json({ ok: true, ts: new Date().toISOString() });

    if (req.method === 'POST' && url.pathname === '/api/clc/mode') {
      const b = await req.json();
      const payload = { mode: b.mode, dir: b.dir };
      return publish(env, 'gg:clc:export_mode', payload);
    }

    if (req.method === 'POST' && url.pathname === '/api/cls/task') {
      const b = await req.json();
      const payload = b?.kind ? b : { kind: 'exec', cmd: String(b?.cmd || '') };
      return publish(env, 'gg:cls:tasks', payload);
    }

    if (req.method === 'GET' && url.pathname === '/api/state')
      return proxy(env, '/state');
    if (req.method === 'GET' && url.pathname === '/api/metrics')
      return proxy(env, '/metrics');
    if (req.method === 'GET' && url.pathname === '/api/health')
      return proxy(env, '/ops-health');

    if (req.method === 'GET' && url.pathname === '/')
      return html(ui());
    if (req.method === 'GET' && url.pathname === '/health')
      return html(healthUI());

    return new Response('Not found', { status: 404 });
  }
};

async function publish(env, channel, payload){
  const res = await fetch(env.BRIDGE_URL + '/pub', {
    method: 'POST',
    headers: { 'content-type':'application/json', 'x-auth-token': env.BRIDGE_TOKEN },
    body: JSON.stringify({ channel, payload })
  });
  if (!res.ok) return new Response('bridge error', { status: 502 });
  return json({ ok: true });
}

async function proxy(env, suffix){
  const r = await fetch(env.BRIDGE_URL + suffix, { method: 'GET', headers: { 'x-auth-token': env.BRIDGE_TOKEN }});
  return new Response(await r.text(), { status: r.status, headers: {'content-type':'application/json'} });
}

function json(obj){ return new Response(JSON.stringify(obj), { headers: { 'content-type':'application/json' } }); }
function html(s){ return new Response(s, { headers: { 'content-type':'text/html; charset=utf-8' } }); }
function ui(){ return `
<!doctype html><meta charset="utf-8"><title>02luka Ops</title>
<style>
  body{font:14px system-ui;margin:24px}
  button{padding:8px 12px;border:1px solid #ddd;border-radius:10px;margin:4px;cursor:pointer}
  .row{margin:12px 0}.card{border:1px solid #eee;padding:12px;border-radius:10px;margin:12px 0}
  pre{background:#fafafa;border:1px solid #eee;padding:12px;border-radius:8px;max-height:260px;overflow:auto}
  small{color:#666}
</style>
<h1>02luka Control Panel</h1>

<div class="card">
  <h3>Status</h3>
  <div id="status">loading…</div>
  <small id="ts"></small>
</div>

<div class="row">
  <h3>CLC Export Mode</h3>
  <button onclick="m('off')">off</button>
  <button onclick="m('local')">local</button>
  <button onclick="m('drive')">drive</button>
  <input id="dir" placeholder="/path for local" style="padding:8px;width:320px;margin-left:8px">
</div>

<div class="row">
  <h3>CLS Exec</h3>
  <input id="cmd" placeholder='node knowledge/sync.cjs --export' style="padding:8px;width:420px">
  <button onclick="x()">run</button>
</div>

<pre id="out"></pre>

<script>
async function refresh(){
  try{
    const [s,m] = await Promise.all([
      fetch('/api/state').then(r=>r.json()),
      fetch('/api/metrics').then(r=>r.json())
    ]);
    const st = s?.state || {};
    const mt = m?.metrics || {};
    document.getElementById('status').innerHTML =
      'MODE: <b>'+(st.MODE||'-')+'</b>' +
      (st.LOCAL_DIR ? ' · LOCAL_DIR: <code>'+st.LOCAL_DIR+'</code>' : '') +
      (st.UPDATED_AT ? ' · UPDATED: '+st.UPDATED_AT : '') +
      (mt && Object.keys(mt).length ? '<br><small>metrics: '+Object.keys(mt).join(', ')+'</small>' : '');
    document.getElementById('ts').textContent = new Date().toLocaleString();
  }catch(e){ document.getElementById('status').textContent = 'error loading status'; }
}
async function m(mode){
  const dir = document.getElementById('dir').value;
  const r = await fetch('/api/clc/mode',{method:'POST',headers:{'content-type':'application/json'},
    body: JSON.stringify({mode, dir: (mode==='local' && dir)?dir:undefined})});
  document.getElementById('out').textContent = await r.text();
  setTimeout(refresh, 500);
}
async function x(){
  const cmd = document.getElementById('cmd').value;
  const r = await fetch('/api/cls/task',{method:'POST',headers:{'content-type':'application/json'},
    body: JSON.stringify({kind:'exec', cmd})});
  document.getElementById('out').textContent = await r.text();
}
refresh(); setInterval(refresh, 5000);
</script>
`; }

function healthUI(){ return `
<!doctype html><meta charset="utf-8"><title>02luka Health</title>
<style>
  body{font:14px system-ui;margin:24px}
  .row{margin:16px 0}
  canvas{max-width:960px;width:100%;height:280px;border:1px solid #eee;border-radius:8px;background:#fff}
  .card{border:1px solid #eee;border-radius:10px;padding:12px;margin:12px 0}
  code{background:#fafafa;padding:2px 6px;border-radius:6px}
</style>
<h1>02luka • Health Dashboard</h1>
<div class="card">
  <div id="meta">loading…</div>
</div>
<div class="row">
  <h3>Success Rate (last checks)</h3>
  <canvas id="rate"></canvas>
</div>
<div class="row">
  <h3>Average Latency ms (last checks)</h3>
  <canvas id="lat"></canvas>
</div>
<script>
async function load(){
  const r = await fetch('/api/health'); const j = await r.json();
  const h = j?.health || {};
  const checks = (h.checks||[]).slice(-60); // last ~5h at 5min interval
  // meta
  const last = h?.summary?.last_check || (checks.at(-1)?.timestamp)||'n/a';
  const succ = h?.summary?.recent_success_rate ?? '-';
  const avg  = h?.summary?.recent_avg_latency_ms ?? '-';
  document.getElementById('meta').innerHTML =
    'Last check: <b>'+last+'</b> · Recent success: <b>'+succ+'%</b> · Recent avg latency: <b>'+avg+' ms</b>';

  // datasets
  const labels = checks.map(c => new Date(c.timestamp).toLocaleTimeString());
  const rate = checks.map(c => c.success_rate ?? null);
  const lat  = checks.map(c => c.avg_latency_ms ?? null);

  drawLine('rate', labels, rate, 'Success %');
  drawLine('lat', labels, lat, 'Avg Latency (ms)');
}

function drawLine(id, labels, data, label){
  const ctx = document.getElementById(id).getContext('2d');
  // vanilla canvas line chart
  const W = ctx.canvas.width, H = ctx.canvas.height;
  // DPR scale
  const dpr = window.devicePixelRatio || 1;
  ctx.canvas.width = W*dpr; ctx.canvas.height = H*dpr; ctx.scale(dpr,dpr);

  ctx.clearRect(0,0,W,H);
  ctx.font = '12px system-ui'; ctx.fillStyle = '#222'; ctx.strokeStyle = '#888';

  const padL=40, padR=12, padT=10, padB=26;
  const plotW = W - padL - padR, plotH = H - padT - padB;

  // y scale
  const vals = data.filter(v => v!==null && v!==undefined);
  const yMin = Math.min(...vals, label.includes('Success')?0:Math.min(...vals));
  const yMax = Math.max(...vals, label.includes('Success')?100:Math.max(...vals));
  const yRange = (yMax - yMin) || 1;

  // axes
  ctx.strokeStyle = '#ddd';
  ctx.beginPath();
  ctx.moveTo(padL, padT); ctx.lineTo(padL, padT+plotH); ctx.lineTo(padL+plotW, padT+plotH); ctx.stroke();

  // y ticks (4)
  ctx.fillStyle='#666';
  for(let i=0;i<=4;i++){
    const yVal = yMin + (yRange*i/4);
    const y = padT + plotH - (plotH*(yVal-yMin)/yRange);
    ctx.strokeStyle='#eee'; ctx.beginPath(); ctx.moveTo(padL, y); ctx.lineTo(padL+plotW, y); ctx.stroke();
    ctx.fillText(String(Math.round(yVal)), 6, y+4);
  }

  // line
  ctx.strokeStyle = '#1f78ff';
  ctx.beginPath();
  data.forEach((v, i) => {
    const x = padL + (plotW * i / Math.max(1, data.length-1));
    const y = padT + plotH - (plotH*(v - yMin)/yRange);
    if(i===0) ctx.moveTo(x,y); else ctx.lineTo(x,y);
  });
  ctx.stroke();

  // x labels (every ~10th)
  ctx.fillStyle='#666';
  const step = Math.ceil(labels.length/6);
  labels.forEach((t, i) => {
    if(i%step!==0) return;
    const x = padL + (plotW * i / Math.max(1, labels.length-1));
    ctx.fillText(t, x-20, padT+plotH+16);
  });

  // title
  ctx.fillStyle='#333';
  ctx.fillText(label, padL, 14);
}

load(); setInterval(load, 30000);
</script>
`; }
