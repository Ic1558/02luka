const Q = sel => document.querySelector(sel);
const SKEY = "02luka.hub.quicken.snapshot.v1";
const ENDPOINTS = {
  index: "../../hub/index.json",
  registry: "../../hub/mcp_registry.json",
  health: "../../hub/mcp_health.json"
};

async function fetchJSON(url){
  try{
    const r = await fetch(url,{cache:"no-store"});
    if(!r.ok) throw new Error(`${r.status} ${r.statusText}`);
    return await r.json();
  }catch(e){ return { _error: String(e), _url: url }; }
}
function pick(o,k){const r={}; for(const x of k) r[x]=o?.[x]; return r;}
function normalizeForSearch(obj){return JSON.stringify(obj).toLowerCase();}
function colorBadge(el,cls){el.classList.remove("ok","warn","err"); if(cls) el.classList.add(cls);}

function diff(a,b){
  // lightweight deep diff by string compare; good enough for status glance
  const sa = JSON.stringify(a); const sb = JSON.stringify(b);
  if(sa===sb) return {changed:false, add:0, rem:0};
  // naive counts
  const add = Math.max(0, sb.length - sa.length);
  const rem = Math.max(0, sa.length - sb.length);
  return {changed:true, add, rem};
}

function saveSnapshot(data){
  localStorage.setItem(SKEY, JSON.stringify({t:Date.now(), data}));
}
function loadSnapshot(){
  try{ return JSON.parse(localStorage.getItem(SKEY) || ""); }catch{ return null; }
}

async function render(){
  const [idx, reg, hlt] = await Promise.all([
    fetchJSON(ENDPOINTS.index),
    fetchJSON(ENDPOINTS.registry),
    fetchJSON(ENDPOINTS.health)
  ]);

  // Badges
  Q("#idx-badge").textContent = idx?._meta ? `${idx._meta.total ?? "?"} items` : "—";
  Q("#reg-badge").textContent = reg?._meta ? `${reg._meta.total ?? "?"} servers` : "—";
  if(hlt?._meta){
    const healthy = hlt._meta.healthy ?? 0, total = hlt._meta.total ?? 0;
    const pct = total ? Math.round(healthy*100/total) : 0;
    const b = Q("#hlt-badge"); b.textContent = `${healthy}/${total} (${pct}%)`;
    colorBadge(b, pct===100 ? "ok" : pct>=50 ? "warn" : "err");
  } else Q("#hlt-badge").textContent = "—";

  // Compose 1 payload for search/diff
  const payload = {idx, reg, hlt};
  const prev = loadSnapshot();

  // Diff
  let d = {changed:false,add:0,rem:0};
  if(prev?.data) d = diff(prev.data, payload);
  const db = Q("#diff-badge");
  db.textContent = d.changed ? `changed (+${d.add}/-${d.rem})` : "no change";
  colorBadge(db, d.changed ? "warn" : "ok");

  // Search filter
  const term = Q("#search").value.trim().toLowerCase();
  const showIdx = term ? filterObj(idx, term) : idx;
  const showReg = term ? filterObj(reg, term) : reg;
  const showHlt = term ? filterObj(hlt, term) : hlt;

  Q("#index-view").textContent   = JSON.stringify(showIdx?._meta ? { _meta: pick(showIdx._meta,["created_at","source","total","mem_root"]), sample: (showIdx.items||[]).slice(0,30) } : showIdx, null, 2);
  Q("#registry-view").textContent= JSON.stringify(showReg?._meta ? { _meta: pick(showReg._meta,["created_at","source","config_path","total"]), servers: (showReg.servers||[]).slice(0,30)} : showReg, null, 2);
  Q("#health-view").textContent  = JSON.stringify(showHlt, null, 2);

  saveSnapshot(payload);
}
function filterObj(obj, term){
  if(!obj) return obj;
  try{
    const s = normalizeForSearch(obj);
    if(s.includes(term)) return obj;
    // More granular on known arrays
    if(Array.isArray(obj.items)){
      const items = obj.items.filter(x => normalizeForSearch(x).includes(term));
      return {...obj, items};
    }
    if(Array.isArray(obj.servers)){
      const servers = obj.servers.filter(x => normalizeForSearch(x).includes(term));
      return {...obj, servers};
    }
    if(Array.isArray(obj.results)){
      const results = obj.results.filter(x => normalizeForSearch(x).includes(term));
      return {...obj, results};
    }
    return obj; // no direct hit but keep
  }catch{ return obj; }
}

function setup(){
  // Theme
  const root = document.documentElement;
  const saved = localStorage.getItem("02luka.theme");
  if(saved) root.setAttribute("data-theme", saved);
  Q("#toggle-theme").onclick = () => {
    const cur = root.getAttribute("data-theme")==="dark" ? "light":"dark";
    root.setAttribute("data-theme", cur);
    localStorage.setItem("02luka.theme", cur);
  };

  // Search
  Q("#search").addEventListener("input", () => { render(); });

  // Export
  Q("#export").onclick = async () => {
    const data = {
      index: await fetchJSON(ENDPOINTS.index),
      registry: await fetchJSON(ENDPOINTS.registry),
      health: await fetchJSON(ENDPOINTS.health),
      exported_at: new Date().toISOString()
    };
    const blob = new Blob([JSON.stringify(data,null,2)], {type:"application/json"});
    const a = document.createElement("a");
    a.href = URL.createObjectURL(blob);
    a.download = `hub_export_${Date.now()}.json`;
    a.click();
  };

  // Auto refresh
  const cb = Q("#autorefresh");
  let timer = null;
  const apply = ()=>{
    if(timer) clearInterval(timer);
    if(cb.checked) timer = setInterval(render, 10000);
  };
  cb.addEventListener("change", apply);
  apply();

  // Service worker (optional offline)
  if('serviceWorker' in navigator){
    navigator.serviceWorker.register('./sw.js').catch(()=>{});
  }
}

window.addEventListener("load", async () => { setup(); await render(); });
