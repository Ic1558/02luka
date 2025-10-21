// Mini Ops Status Widget - Zero Dependencies
// Drop this script into any page to show real-time ops status

(function MiniOpsStatus(){
  const host = document.getElementById('mini-status');
  if (!host) return;

  const cssCard = [
    'position:absolute','top:0','right:0','z-index:20',
    'background:#0b0f14','border:1px solid rgba(255,255,255,.08)',
    'border-radius:12px','padding:10px 12px','color:#e7e7e7',
    'font:12px/1.35 system-ui, -apple-system, Segoe UI, Roboto, sans-serif',
    'box-shadow:0 4px 16px rgba(0,0,0,.25)','min-width:240px'
  ].join(';');

  const cssRow = 'display:flex;align-items:center;gap:8px;margin:4px 0;';
  const cssDot = (ok)=>[
    'width:10px','height:10px','border-radius:50%',
    'background:'+ (ok ? '#19c37d' : '#f63'),'box-shadow:0 0 0 2px rgba(255,255,255,.06) inset'
  ].join(';');

  const keyLabel = { bridge:'Bridge', health:'Health', predict:'Predict', federation:'Federation' };

  const card = document.createElement('div');
  card.setAttribute('role','status');
  card.setAttribute('aria-live','polite');
  card.style.cssText = cssCard;
  host.appendChild(card);

  async function load() {
    try {
      const r = await fetch('/api/verify', { cache:'no-store', credentials:'include' });
      const j = await r.json();
      const chk = j.checks || {};
      const ts = j.ts || '';
      const ok = !!j.ok;

      card.innerHTML = `
        <div style="display:flex;align-items:center;justify-content:space-between;gap:8px;margin-bottom:6px;">
          <div style="font-weight:600;opacity:.9">${ok ? '✅ OPS PASS' : '❌ OPS FAIL'}</div>
          <div title="${ts}" style="opacity:.6">${ts ? new Date(ts).toLocaleTimeString() : ''}</div>
        </div>
        ${['bridge','health','predict','federation'].map(k=>{
          const v = !!chk[k];
          return `<div style="${cssRow}">
                    <span aria-hidden="true" style="${cssDot(v)}"></span>
                    <span>${keyLabel[k]}</span>
                    <span style="margin-left:auto;opacity:.65">${v?'OK':'FAIL'}</span>
                  </div>`;
        }).join('')}
        <div style="margin-top:6px;opacity:.7">${j.summary ? j.summary.replace(/^✅|^❌/,'').trim() : ''}</div>
      `;
    } catch (e) {
      card.innerHTML = `<div style="opacity:.8">Status unavailable</div>`;
    }
  }

  load();
  setInterval(load, 30_000);
})();
