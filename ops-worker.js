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
      const payload = b.kind ? b : { kind: 'exec', cmd: String(b?.cmd || '') };
      return publish(env, 'gg:cls:tasks', payload);
    }

    if (req.method === 'GET' && url.pathname === '/')
      return html(ui());

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

function json(obj){ return new Response(JSON.stringify(obj), { headers: { 'content-type':'application/json' } }); }
function html(s){ return new Response(s, { headers: { 'content-type':'text/html; charset=utf-8' } }); }
function ui(){ return `
<!doctype html><meta charset="utf-8"><title>02luka Ops</title>
<style>body{font:14px system-ui;margin:24px}button{padding:8px 12px;border:1px solid #ddd;border-radius:10px;margin:4px;cursor:pointer}</style>
<h1>02luka Control Panel</h1>
<section>
  <h3>CLC Export Mode</h3>
  <button onclick="m('off')">off</button>
  <button onclick="m('local')">local</button>
  <button onclick="m('drive')">drive</button>
  <input id=dir placeholder="/path for local" style="padding:8px;width:320px;margin-left:8px">
</section>
<section>
  <h3>CLS Exec</h3>
  <input id=cmd placeholder='node knowledge/sync.cjs --export' style="padding:8px;width:420px">
  <button onclick="x()">run</button>
</section>
<pre id=o></pre>
<script>
async function m(mode){
  const dir = document.getElementById('dir').value;
  const r = await fetch('/api/clc/mode',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({mode,dir:mode==='local'&&dir?dir:undefined})});
  document.getElementById('o').textContent = await r.text();
}
async function x(){
  const cmd = document.getElementById('cmd').value;
  const r = await fetch('/api/cls/task',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({kind:'exec',cmd})});
  document.getElementById('o').textContent = await r.text();
}
</script>
`; }
