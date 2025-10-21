const { createClient } = require('redis');
const REDIS_URL = process.env.REDIS_URL || 'redis://localhost:6379';
const CH_IN  = process.env.KIM_IN_CH  || 'kim:msg';
const CH_OUT = process.env.KIM_OUT_CH || 'kim:out';
const CLS_CH = process.env.CLS_CHANNEL || 'gg:cls:tasks';

function parse(text){
  const t = (text||'').trim();
  if (!t.toLowerCase().startsWith('/cls')) return null;
  // Examples:
  // /cls run WO-...
  // /cls verify freeze-proofing
  // /cls exec node knowledge/sync.cjs --export
  // /cls raw {"kind":"verify","topic":"freeze-proofing"}
  const parts = t.split(/\s+/, 3);
  const sub = (parts[1]||'').toLowerCase();
  const rest = t.replace(/^\/cls\s+\w+\s*/i,'');
  switch(sub){
    case 'run':    return { kind:'run',    payload:{kind:'run',    work_order:rest} };
    case 'verify': return { kind:'verify', payload:{kind:'verify', topic:rest} };
    case 'exec':
      if (rest.trim().startsWith('{')) return { kind:'exec', payload: JSON.parse(rest) };
      return { kind:'exec', payload:{kind:'exec', cmd:rest} };
    case 'raw':
      return { kind:'raw', payload: JSON.parse(rest) };
    default:
      return { kind:'help' };
  }
}

(async ()=>{
  const cli = createClient({ url: REDIS_URL });
  await cli.connect();
  const sub = cli.duplicate(); await sub.connect();
  console.log(`[kim-cls-router] in:${CH_IN} -> ${CLS_CH}`);

  await sub.subscribe(CH_IN, async (msg)=>{
    try{
      const m = JSON.parse(msg||'{}');
      const text = m.text || ''; const chat_id = m.chat_id || '';
      const p = parse(text);
      if (!p) return;

      if (p.kind === 'help'){
        await cli.publish(CH_OUT, JSON.stringify({
          chat_id, text:
`/cls run WO-ID
/cls verify freeze-proofing
/cls exec node knowledge/sync.cjs --export
/cls raw {"kind":"verify","topic":"freeze-proofing"}`
        }));
        return;
      }

      await cli.publish(CLS_CH, JSON.stringify(p.payload));
      await cli.publish(CH_OUT, JSON.stringify({
        chat_id, text: `✅ queued -> ${CLS_CH}\n${JSON.stringify(p.payload)}`
      }));
    } catch(e){
      console.error('kim_cls_router error', e);
    }
  });
})();
