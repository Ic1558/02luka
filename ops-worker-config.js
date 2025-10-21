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

    // === Phase 8.1 & 8.2 — Maintenance endpoints ===
    if (req.method === 'GET' && url.pathname === '/api/maintenance')
      return proxy(env, '/maintenance');
    if (req.method === 'POST' && url.pathname === '/api/maintenance') {
      const b = await req.json().catch(()=> ({}));
      const r = await fetch(env.BRIDGE_URL + '/maintenance', {
        method: 'POST',
        headers: { 'content-type':'application/json', 'x-auth-token': env.BRIDGE_TOKEN },
        body: JSON.stringify(b)
      });
      return new Response(await r.text(), { status: r.status, headers: {'content-type':'application/json'} });
    }

    // === Phase 8.3-8.7 — Feature Flag System ===
    // /api/lab/features → bridge /lab/features
    if (req.method === 'GET' && url.pathname === '/api/lab/features') {
      return proxy(env, '/lab/features');
    }

    // simple Lab page (read-only)
    if (req.method === 'GET' && url.pathname === '/lab') {
      return html(labUI());
    }

    // === Phase 8.3 — Audit Trail Viewer ===
    // Proxy → /audit/latest
    if (req.method === 'GET' && url.pathname === '/api/audit/latest') {
      return proxy(env, '/audit/latest' + (url.search || ''));
    }

    // Add UI route
    if (req.method === 'GET' && url.pathname === '/audit') {
      return html(auditUI());
    }

    // === Phase 8.4 — Config Center ===
    // API proxies
    if (req.method === 'GET' && url.pathname === '/api/config/view') {
      return proxy(env, '/config/view');
    }
    if (req.method === 'POST' && url.pathname === '/api/config/apply') {
      const b = await req.json().catch(()=> ({}));
      const r = await fetch(env.BRIDGE_URL + '/config/apply', {
        method: 'POST',
        headers: { 'content-type':'application/json', 'x-auth-token': env.BRIDGE_TOKEN },
        body: JSON.stringify(b)
      });
      return new Response(await r.text(), { status: r.status, headers: {'content-type':'application/json'} });
    }

    // UI page
    if (req.method === 'GET' && url.pathname === '/config') {
      return html(configUI());
    }

    // === Phase 8.5 — AI Ops Digest ===
    // API proxies
    if (req.method === 'GET' && url.pathname === '/api/digest/latest') {
      return proxy(env, '/digest/latest');
    }
    if (req.method === 'POST' && url.pathname === '/api/digest/generate') {
      const r = await fetch(env.BRIDGE_URL + '/digest/generate', {
        method:'POST',
        headers:{ 'x-auth-token': env.BRIDGE_TOKEN }
      });
      return new Response(await r.text(), { status:r.status, headers:{'content-type':'application/json'} });
    }

    // UI page
    if (req.method === 'GET' && url.pathname === '/digest') {
      return html(digestUI());
    }

    // === Phase 8.6 — Incident Correlation ===
    // API proxies
    if (req.method === 'GET' && url.pathname === '/api/correlation/latest') {
      return proxy(env, '/correlation/latest');
    }
    if (req.method === 'POST' && url.pathname === '/api/correlation/run') {
      const r = await fetch(env.BRIDGE_URL + '/correlation/run', {
        method:'POST',
        headers:{ 'x-auth-token': env.BRIDGE_TOKEN }
      });
      return new Response(await r.text(), { status:r.status, headers:{'content-type':'application/json'} });
    }

    // UI page
    if (req.method === 'GET' && url.pathname === '/correlation') {
      return html(correlationUI());
    }

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

function configUI(){ return `
<!doctype html><meta charset="utf-8"><title>02luka • Config Center</title>
<style>
  body{font:14px system-ui;margin:24px;line-height:1.5}
  .tabs{display:flex;border-bottom:1px solid #ddd;margin-bottom:16px}
  .tab{padding:8px 16px;border:1px solid #ddd;border-bottom:none;background:#f8f9fa;cursor:pointer;margin-right:2px}
  .tab.active{background:#fff;border-bottom:1px solid #fff;margin-bottom:-1px}
  .tab-content{display:none}
  .tab-content.active{display:block}
  .banner{padding:8px 12px;border-radius:6px;margin:12px 0;font-weight:500}
  .banner.readonly{background:#f8d7da;color:#721c24;border:1px solid #f5c6cb}
  .banner.dryrun{background:#d4edda;color:#155724;border:1px solid #c3e6cb}
  .banner.live{background:#fff3cd;color:#856404;border:1px solid #ffeaa7}
  .form-group{margin:12px 0}
  .form-group label{display:block;margin-bottom:4px;font-weight:500}
  .form-group input, .form-group select{width:100%;padding:6px 8px;border:1px solid #ddd;border-radius:4px}
  .btn{padding:6px 12px;border:1px solid #ddd;border-radius:6px;background:#fff;cursor:pointer;margin:4px}
  .btn.primary{background:#007bff;color:#fff;border-color:#007bff}
  .btn.danger{background:#dc3545;color:#fff;border-color:#dc3545}
  .diff{background:#f8f9fa;border:1px solid #ddd;border-radius:6px;padding:12px;font-family:ui-monospace,Menlo,Consolas,monospace;white-space:pre-wrap}
  .diff .add{color:#155724;background:#d4edda}
  .diff .remove{color:#721c24;background:#f8d7da}
  .status{margin:8px 0;padding:8px;border-radius:4px}
  .status.success{background:#d4edda;color:#155724;border:1px solid #c3e6cb}
  .status.error{background:#f8d7da;color:#721c24;border:1px solid #f5c6cb}
  .status.info{background:#d1ecf1;color:#0c5460;border:1px solid #bee5eb}
</style>
<h1>02luka • Config Center</h1>

<div id="banner" class="banner">loading…</div>

<div class="tabs">
  <div class="tab active" onclick="showTab('env')">Environment</div>
  <div class="tab" onclick="showTab('flags')">Feature Flags</div>
  <div class="tab" onclick="showTab('compose')">Compose Summary</div>
</div>

<div id="env" class="tab-content active">
  <h3>Environment Variables</h3>
  <div id="env-form">
    <div class="form-group">
      <label>Add/Edit Variable:</label>
      <input type="text" id="env-key" placeholder="VARIABLE_NAME" style="width:200px;display:inline-block">
      <span style="margin:0 8px">=</span>
      <input type="text" id="env-value" placeholder="value" style="width:300px;display:inline-block">
      <button class="btn" onclick="addEnvVar()">Add</button>
    </div>
    <div id="env-vars">loading…</div>
  </div>
</div>

<div id="flags" class="tab-content">
  <h3>Feature Flags</h3>
  <div id="flags-content">loading…</div>
</div>

<div id="compose" class="tab-content">
  <h3>Docker Compose Summary</h3>
  <div id="compose-content">loading…</div>
</div>

<div style="margin-top:24px;padding-top:16px;border-top:1px solid #ddd">
  <button class="btn primary" onclick="previewChanges()">Preview Changes</button>
  <button class="btn danger" onclick="applyChanges()" id="apply-btn" disabled>Apply Changes</button>
  <span id="status"></span>
</div>

<div id="diff-preview" class="diff" style="display:none;margin-top:16px"></div>

<script>
let currentConfig = null;
let currentMode = 'off';

async function loadConfig(){
  try{
    const r = await fetch('/api/config/view');
    const j = await r.json();
    currentConfig = j.config;
    currentMode = j.config.mode || 'off';
    
    // Update banner
    const banner = document.getElementById('banner');
    if (currentMode === 'off') {
      banner.className = 'banner readonly';
      banner.textContent = '🔒 Read-Only Mode — Configuration changes are disabled';
    } else if (currentMode === 'dryrun') {
      banner.className = 'banner dryrun';
      banner.textContent = '✅ Safe Dry-Run Mode — Preview changes without applying';
    } else if (currentMode === 'on') {
      banner.className = 'banner live';
      banner.textContent = '⚠️ Live Write Enabled — Requires Confirm Header';
    }
    
    // Load environment tab
    loadEnvTab();
    loadFlagsTab();
    loadComposeTab();
  }catch(e){
    document.getElementById('status').innerHTML = '<div class="status error">Error loading config: '+e.message+'</div>';
  }
}

function loadEnvTab(){
  const env = currentConfig.env || {};
  const container = document.getElementById('env-vars');
  
  const rows = Object.entries(env).map(([k,v]) => 
    '<div style="margin:4px 0;padding:4px;border:1px solid #eee;border-radius:4px">' +
    '<span style="font-weight:500">'+escapeHtml(k)+'</span> = <code>'+escapeHtml(v)+'</code>' +
    '<button class="btn" onclick="removeEnvVar(\''+k+'\')" style="float:right;margin-left:8px">Remove</button>' +
    '<button class="btn" onclick="editEnvVar(\''+k+'\',\''+escapeHtml(v)+'\')" style="float:right">Edit</button>' +
    '</div>'
  ).join('');
  
  container.innerHTML = rows || '<div style="color:#666">No environment variables</div>';
}

function loadFlagsTab(){
  const flags = currentConfig.env || {};
  const container = document.getElementById('flags-content');
  
  const flagRows = Object.entries(flags).filter(([k]) => k.startsWith('LAB_') || k.startsWith('OPS_') || k.startsWith('CFG_') || k.startsWith('PREDICTIVE_') || k.startsWith('FEDERATION_') || k.startsWith('AUTO_')).map(([k,v]) => 
    '<div style="margin:4px 0;padding:8px;border:1px solid #eee;border-radius:4px">' +
    '<span style="font-weight:500">'+escapeHtml(k)+'</span> = <code>'+escapeHtml(v)+'</code>' +
    '</div>'
  ).join('');
  
  container.innerHTML = flagRows || '<div style="color:#666">No feature flags</div>';
}

function loadComposeTab(){
  const container = document.getElementById('compose-content');
  container.innerHTML = '<div style="color:#666">Docker Compose summary would go here</div>';
}

function addEnvVar(){
  const key = document.getElementById('env-key').value.trim();
  const value = document.getElementById('env-value').value.trim();
  
  if (!key) {
    document.getElementById('status').innerHTML = '<div class="status error">Variable name is required</div>';
    return;
  }
  
  if (!currentConfig) currentConfig = { env: {} };
  if (!currentConfig.env) currentConfig.env = {};
  
  currentConfig.env[key] = value;
  loadEnvTab();
  
  document.getElementById('env-key').value = '';
  document.getElementById('env-value').value = '';
}

function editEnvVar(key, value){
  document.getElementById('env-key').value = key;
  document.getElementById('env-value').value = value;
}

function removeEnvVar(key){
  if (!currentConfig || !currentConfig.env) return;
  delete currentConfig.env[key];
  loadEnvTab();
}

function showTab(tabName){
  // Hide all tabs
  document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
  document.querySelectorAll('.tab-content').forEach(t => t.classList.remove('active'));
  
  // Show selected tab
  document.querySelector(`[onclick="showTab('${tabName}')"]`).classList.add('active');
  document.getElementById(tabName).classList.add('active');
}

async function previewChanges(){
  if (!currentConfig || !currentConfig.env) {
    document.getElementById('status').innerHTML = '<div class="status error">No configuration to preview</div>';
    return;
  }
  
  try{
    const r = await fetch('/api/config/apply', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ env: currentConfig.env, mode: 'dryrun' })
    });
    
    const j = await r.json();
    
    if (j.ok) {
      document.getElementById('status').innerHTML = '<div class="status success">Preview generated successfully</div>';
      
      // Show diff
      const diffEl = document.getElementById('diff-preview');
      diffEl.style.display = 'block';
      diffEl.textContent = j.diff_markdown || 'No diff available';
      
      // Enable apply button if in dryrun or on mode
      const applyBtn = document.getElementById('apply-btn');
      if (currentMode === 'dryrun' || currentMode === 'on') {
        applyBtn.disabled = false;
      }
    } else {
      document.getElementById('status').innerHTML = '<div class="status error">Preview failed: '+j.error+'</div>';
    }
  }catch(e){
    document.getElementById('status').innerHTML = '<div class="status error">Preview error: '+e.message+'</div>';
  }
}

async function applyChanges(){
  if (!currentConfig || !currentConfig.env) {
    document.getElementById('status').innerHTML = '<div class="status error">No configuration to apply</div>';
    return;
  }
  
  if (currentMode === 'off') {
    document.getElementById('status').innerHTML = '<div class="status error">Configuration changes are disabled (CFG_EDIT=off)</div>';
    return;
  }
  
  if (currentMode === 'on' && !confirm('Are you sure you want to apply these changes? This will modify the .env file.')) {
    return;
  }
  
  try{
    const r = await fetch('/api/config/apply', {
      method: 'POST',
      headers: { 
        'content-type': 'application/json',
        'x-confirm': currentMode === 'on' ? 'yes' : 'no'
      },
      body: JSON.stringify({ env: currentConfig.env, mode: currentMode, confirm: currentMode === 'on' })
    });
    
    const j = await r.json();
    
    if (j.ok) {
      if (j.applied) {
        document.getElementById('status').innerHTML = '<div class="status success">Configuration applied successfully</div>';
        if (j.backup_path) {
          document.getElementById('status').innerHTML += '<div class="status info">Backup created: '+j.backup_path+'</div>';
        }
      } else {
        document.getElementById('status').innerHTML = '<div class="status info">Dry-run completed (no changes applied)</div>';
      }
      
      // Show diff
      const diffEl = document.getElementById('diff-preview');
      diffEl.style.display = 'block';
      diffEl.textContent = j.diff_markdown || 'No diff available';
      
      // Reload config
      await loadConfig();
    } else {
      document.getElementById('status').innerHTML = '<div class="status error">Apply failed: '+j.error+'</div>';
    }
  }catch(e){
    document.getElementById('status').innerHTML = '<div class="status error">Apply error: '+e.message+'</div>';
  }
}

function escapeHtml(s){ return (s||'').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c])); }

loadConfig();
</script>
`; }

function correlationUI(){ return `
<!doctype html><meta charset="utf-8"><title>02luka • Incident Correlation</title>
<style>
body{font:15px system-ui;margin:24px;line-height:1.5}
.btn{padding:6px 10px;border:1px solid #ddd;border-radius:8px;background:#fff;cursor:pointer}
.row{margin:12px 0}
#md{white-space:pre-wrap;font-family:ui-monospace, Menlo, Consolas, monospace;background:#fafafa;padding:12px;border-radius:8px;border:1px solid #eee}
.badge{display:inline-block;padding:2px 8px;border-radius:12px;border:1px solid #ddd}
</style>
<h1>Incident Correlation</h1>
<div class="row">
  <button class="btn" onclick="runNow()">Force Run</button>
  <span id="mode" class="badge">mode: …</span>
  <span id="status"></span>
</div>
<div id="md">loading…</div>
<script>
async function load(){
  const r = await fetch('/api/correlation/latest');
  const j = await r.json();
  document.getElementById('mode').textContent = 'mode: '+(j.mode||'?');
  document.getElementById('md').textContent = j.body || '(no findings yet)';
}
async function runNow(){
  document.getElementById('status').textContent = 'running…';
  const r = await fetch('/api/correlation/run', { method:'POST' });
  document.getElementById('status').textContent = r.ok ? 'done' : ('error '+r.status);
  await load();
}
load(); setInterval(load, 60000);
</script>
`; }

function digestUI(){ return `
<!doctype html><meta charset="utf-8"><title>02luka • AI Ops Digest</title>
<style>
body{font:15px system-ui;margin:24px;line-height:1.5}
#md{white-space:pre-wrap;font-family:ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;background:#fafafa;padding:12px;border-radius:8px;border:1px solid #eee}
.btn{padding:6px 10px;border:1px solid #ddd;border-radius:8px;background:#fff;cursor:pointer}
.row{margin:12px 0}
</style>
<h1>AI Ops Digest</h1>
<div class="row">
  <button class="btn" onclick="gen()">Force Generate Now</button>
  <span id="status"></span>
</div>
<div id="md">loading…</div>
<script>
async function load(){
  const r = await fetch('/api/digest/latest');
  const j = await r.json();
  document.getElementById('md').textContent = j.body || '(no digest yet)';
}
async function gen(){
  document.getElementById('status').textContent = 'generating…';
  const r = await fetch('/api/digest/generate', { method:'POST' });
  if(!r.ok){ document.getElementById('status').textContent = 'error '+r.status; return; }
  document.getElementById('status').textContent = 'done';
  await load();
}
load(); setInterval(load, 120000);
</script>
`; }

function auditUI(){ return `
<!doctype html><meta charset="utf-8"><title>02luka Audit</title>
<style>
  body{font:14px system-ui;margin:24px}
  .row{margin:12px 0}
  table{border-collapse:collapse;width:100%}
  th,td{border:1px solid #eee;padding:8px;text-align:left;font-size:13px}
  th{background:#fafafa}
  .pill{display:inline-block;padding:2px 8px;border-radius:12px;border:1px solid #ddd}
  .on{background:#d4edda;color:#155724;border-color:#c3e6cb}
  .off{background:#f8d7da;color:#721c24;border-color:#f5c6cb}
  .shadow{background:#fff3cd;color:#856404;border-color:#ffeaa7}
  .readonly{background:#d1ecf1;color:#0c5460;border-color:#bee5eb}
</style>
<h1>02luka • Audit Trail</h1>
<div class="row">
  <label>Type:</label>
  <select id="type">
    <option value="all">all</option>
    <option value="maint">maint</option>
    <option value="autoheal">autoheal</option>
    <option value="alerts">alerts</option>
  </select>
  <label style="margin-left:12px">Limit:</label>
  <input id="limit" type="number" value="200" min="10" max="1000" style="width:80px">
  <button onclick="reload()">Load</button>
</div>
<div class="row" id="status">loading…</div>
<div class="row">
  <table>
    <thead><tr><th>Time (UTC)</th><th>Type</th><th>Message</th></tr></thead>
    <tbody id="rows"></tbody>
  </table>
</div>
<script>
async function fetchAudit(){
  const type = document.getElementById('type').value;
  const limit = document.getElementById('limit').value || 200;
  const r = await fetch('/api/audit/latest?type='+encodeURIComponent(type)+'&limit='+encodeURIComponent(limit));
  if(!r.ok){ document.getElementById('status').textContent = 'error '+r.status; return { items:[] }; }
  return r.json();
}
function render(items){
  const tb = document.getElementById('rows');
  tb.innerHTML = items.map(x => (
    '<tr>'+
      '<td>'+x.ts.replace('T',' ').replace('Z','Z')+'</td>'+
      '<td><span class="pill">'+x.type+'</span></td>'+
      '<td>'+escapeHtml(x.msg)+'</td>'+
    '</tr>'
  )).join('');
  document.getElementById('status').textContent = 'showing '+items.length+' events';
}
function escapeHtml(s){ return (s||'').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c])); }
async function reload(){ const j = await fetchAudit(); render(j.items||[]); }
reload(); setInterval(reload, 60000);
</script>
`; }

function labUI(){ return `
<!doctype html><meta charset="utf-8"><title>02luka Lab Features</title>
<style>
  body{font:14px system-ui;margin:24px}
  .card{border:1px solid #eee;border-radius:10px;padding:12px;margin:12px 0}
  code{background:#fafafa;padding:2px 6px;border-radius:6px}
  .kv{display:grid;grid-template-columns:240px 1fr;gap:8px}
  .pill{display:inline-block;padding:2px 8px;border-radius:12px;border:1px solid #ddd}
  .on{background:#d4edda;color:#155724;border-color:#c3e6cb}
  .off{background:#f8d7da;color:#721c24;border-color:#f5c6cb}
  .shadow{background:#fff3cd;color:#856404;border-color:#ffeaa7}
  .readonly{background:#d1ecf1;color:#0c5460;border-color:#bee5eb}
</style>
<h1>02luka • Lab Features</h1>
<div class="card">
  <div id="flags">loading…</div>
</div>
<script>
async function loadFlags(){
  try{
    const r = await fetch('/api/lab/features'); const j = await r.json();
    const f = j.flags || {};
    const rows = Object.entries(f).map(([k,v])=>{
      let cls = 'pill';
      if (v === 'on') cls += ' on';
      else if (v === 'off') cls += ' off';
      else if (v === 'shadow') cls += ' shadow';
      else if (v === 'readonly') cls += ' readonly';
      return '<div>'+k+'</div><div><span class="'+cls+'">'+v+'</span></div>';
    }).join('');
    document.getElementById('flags').innerHTML = '<div class="kv">'+rows+'</div>';
  }catch(e){ document.getElementById('flags').textContent='error loading flags'; }
}
loadFlags();
</script>
`; }

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

<div class="card">
  <h3>Maintenance Console</h3>
  <div id="maint-status">loading…</div>
  <div style="margin-top:8px">
    <input id="maint-reason" placeholder="reason (optional)" style="padding:8px;width:360px">
    <button onclick="maint('on')">Enable Maintenance</button>
    <button onclick="maint('off')">Disable Maintenance</button>
  </div>
  <small>Writes <code>g/state/maintenance.flag</code> and logs to <code>g/logs/maintenance_actions.log</code></small>
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
async function checkMaintenance(){
  try{
    const r = await fetch('/api/maintenance');
    const j = await r.json();
    if(j.maintenance){
      const div = document.createElement('div');
      div.textContent = '🚧 SYSTEM IN MAINTENANCE MODE — auto-heal in progress';
      Object.assign(div.style, {
        position:'fixed', top:'0', left:'0', right:'0',
        background:'#ffcc00', color:'#000',
        textAlign:'center', padding:'8px',
        fontWeight:'bold', zIndex:9999
      });
      document.body.prepend(div);
    }
  }catch(e){/* ignore */}
}

async function loadMaint(){
  try{
    const r = await fetch('/api/maintenance'); const j = await r.json();
    const s = document.getElementById('maint-status');
    if (j.maintenance){
      s.innerHTML = 'Status: <b style="color:#b36b00">ON</b>' + (j.since?` · since ${j.since}`:'');
    } else {
      s.innerHTML = 'Status: <b style="color:#198754">OFF</b>';
    }
  }catch{ document.getElementById('maint-status').textContent = 'status error'; }
}

async function maint(action){
  const reason = document.getElementById('maint-reason').value || '';
  const r = await fetch('/api/maintenance', {
    method:'POST', headers:{'content-type':'application/json'},
    body: JSON.stringify({ action, reason, actor: 'ops-ui' })
  });
  const t = await r.text(); try { console.log(JSON.parse(t)); } catch { console.log(t); }
  setTimeout(loadMaint, 300);
}

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

checkMaintenance(); setInterval(checkMaintenance, 30000);
loadMaint(); setInterval(loadMaint, 30000);
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
async function checkMaintenance(){
  try{
    const r = await fetch('/api/maintenance');
    const j = await r.json();
    if(j.maintenance){
      const div = document.createElement('div');
      div.textContent = '🚧 SYSTEM IN MAINTENANCE MODE — auto-heal in progress';
      Object.assign(div.style, {
        position:'fixed', top:'0', left:'0', right:'0',
        background:'#ffcc00', color:'#000',
        textAlign:'center', padding:'8px',
        fontWeight:'bold', zIndex:9999
      });
      document.body.prepend(div);
    }
  }catch(e){/* ignore */}
}

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

checkMaintenance(); setInterval(checkMaintenance, 30000);
load(); setInterval(load, 30000);
</script>
`; }
