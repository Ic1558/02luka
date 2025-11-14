async function safeJson(url) {
  try {
    const r = await fetch(url, { cache: "no-store" });
    if (!r.ok) throw new Error(`${r.status} ${r.statusText}`);
    return await r.json();
  } catch (e) {
    return { error: String(e), url };
  }
}
function brief(obj, pick) {
  if (!obj || typeof obj !== "object") return obj;
  const out = {};
  for (const k of pick) out[k] = obj[k];
  return out;
}
(async () => {
  const idx = await safeJson("../index.json");
  const reg = await safeJson("../mcp_registry.json");
  const hlt = await safeJson("../mcp_health.json");

  document.getElementById("index-meta").textContent =
    JSON.stringify(idx?._meta ? brief(idx._meta, ["created_at","source","total","mem_root"]) : idx, null, 2);

  document.getElementById("registry-meta").textContent =
    JSON.stringify(reg?._meta ? brief(reg._meta, ["created_at","source","config_path","total"]) : reg, null, 2);

  document.getElementById("health-meta").textContent =
    JSON.stringify(hlt?._meta ? brief(hlt._meta, ["created_at","source","healthy","total"]) : hlt, null, 2);
})();
