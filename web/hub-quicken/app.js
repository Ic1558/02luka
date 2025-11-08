// ======== UTILITY FUNCTIONS ========
const Q = sel => document.querySelector(sel);
const QA = sel => document.querySelectorAll(sel);
const SKEY = "02luka.hub.quicken.snapshot.v1";
const HKEY = "02luka.hub.quicken.history.v1";
const AI_SETTINGS_KEY = "02luka.hub.quicken.ai.v1";
const MAX_HISTORY = 50;

const ENDPOINTS = {
  index: "../../hub/index.json",
  registry: "../../hub/mcp_registry.json",
  health: "../../hub/mcp_health.json"
};

const AI_PRESETS = {
  ollama: {
    endpoint: "http://localhost:11434/api/generate",
    model: "llama3.2:latest",
    apiKey: ""
  },
  lmstudio: {
    endpoint: "http://localhost:1234/v1/chat/completions",
    model: "local-model",
    apiKey: ""
  },
  openai: {
    endpoint: "https://api.openai.com/v1/chat/completions",
    model: "gpt-4o-mini",
    apiKey: ""
  },
  custom: {
    endpoint: "",
    model: "",
    apiKey: ""
  }
};

let useRegex = false;
let lastData = {};
let aiSettings = null;

// Debounce helper
function debounce(fn, delay) {
  let timeout;
  return (...args) => {
    clearTimeout(timeout);
    timeout = setTimeout(() => fn(...args), delay);
  };
}

// Toast notification system
function toast(message, type = "info") {
  const container = Q("#toast-container");
  const toast = document.createElement("div");
  toast.className = `toast toast-${type}`;
  toast.textContent = message;
  container.appendChild(toast);

  setTimeout(() => toast.classList.add("show"), 10);
  setTimeout(() => {
    toast.classList.remove("show");
    setTimeout(() => toast.remove(), 300);
  }, 3000);
}

// ======== DATA FETCHING ========
async function fetchJSON(url, retries = 3) {
  for (let attempt = 1; attempt <= retries; attempt++) {
    try {
      const r = await fetch(url, { cache: "no-store" });
      if (!r.ok) throw new Error(`${r.status} ${r.statusText}`);
      return await r.json();
    } catch (e) {
      if (attempt === retries) {
        console.error(`Failed to fetch ${url} after ${retries} attempts:`, e);
        toast(`Failed to fetch ${url.split('/').pop()}: ${e.message}`, "error");
        return { _error: String(e), _url: url };
      }
      // Exponential backoff: 1s, 2s, 4s
      const delay = Math.pow(2, attempt - 1) * 1000;
      console.warn(`Fetch attempt ${attempt} failed for ${url}, retrying in ${delay}ms...`);
      await new Promise(resolve => setTimeout(resolve, delay));
    }
  }
}

// ======== DATA PROCESSING ========
function pick(o, k) {
  const r = {};
  for (const x of k) r[x] = o?.[x];
  return r;
}

function normalizeForSearch(obj) {
  return JSON.stringify(obj).toLowerCase();
}

function colorBadge(el, cls) {
  el.classList.remove("ok", "warn", "err");
  if (cls) el.classList.add(cls);
}

function diff(a, b) {
  const sa = JSON.stringify(a);
  const sb = JSON.stringify(b);
  if (sa === sb) return { changed: false, add: 0, rem: 0 };
  const add = Math.max(0, sb.length - sa.length);
  const rem = Math.max(0, sa.length - sb.length);
  return { changed: true, add, rem };
}

// ======== STORAGE ========
function saveSnapshot(data) {
  localStorage.setItem(SKEY, JSON.stringify({ t: Date.now(), data }));
  addToHistory(data);
}

function loadSnapshot() {
  try {
    return JSON.parse(localStorage.getItem(SKEY) || "");
  } catch {
    return null;
  }
}

function addToHistory(data) {
  try {
    const history = JSON.parse(localStorage.getItem(HKEY) || "[]");
    history.unshift({ t: Date.now(), data });
    if (history.length > MAX_HISTORY) history.length = MAX_HISTORY;
    localStorage.setItem(HKEY, JSON.stringify(history));
  } catch (e) {
    console.error("Failed to save history:", e);
  }
}

function loadHistory() {
  try {
    return JSON.parse(localStorage.getItem(HKEY) || "[]");
  } catch {
    return [];
  }
}

// ======== SEARCH/FILTER ========
function filterObj(obj, term) {
  if (!obj) return obj;
  try {
    if (useRegex) {
      const regex = new RegExp(term, "i");
      const s = JSON.stringify(obj);
      if (regex.test(s)) return obj;
    } else {
      const s = normalizeForSearch(obj);
      if (s.includes(term)) return obj;
    }

    // Granular filtering for arrays
    if (Array.isArray(obj.items)) {
      const items = obj.items.filter(x => {
        if (useRegex) {
          try {
            return new RegExp(term, "i").test(JSON.stringify(x));
          } catch {
            return false;
          }
        }
        return normalizeForSearch(x).includes(term);
      });
      return { ...obj, items };
    }

    if (Array.isArray(obj.servers)) {
      const servers = obj.servers.filter(x => {
        if (useRegex) {
          try {
            return new RegExp(term, "i").test(JSON.stringify(x));
          } catch {
            return false;
          }
        }
        return normalizeForSearch(x).includes(term);
      });
      return { ...obj, servers };
    }

    if (Array.isArray(obj.results)) {
      const results = obj.results.filter(x => {
        if (useRegex) {
          try {
            return new RegExp(term, "i").test(JSON.stringify(x));
          } catch {
            return false;
          }
        }
        return normalizeForSearch(x).includes(term);
      });
      return { ...obj, results };
    }

    return obj;
  } catch (e) {
    if (useRegex) toast("Invalid regex pattern", "error");
    return obj;
  }
}

// ======== RENDERING ========
function showLoading(id, show = true) {
  const loader = Q(`#loading-${id}`);
  if (loader) loader.style.display = show ? "flex" : "none";
}

async function render() {
  // Show loading states
  showLoading("index", true);
  showLoading("registry", true);
  showLoading("health", true);

  const [idx, reg, hlt] = await Promise.all([
    fetchJSON(ENDPOINTS.index),
    fetchJSON(ENDPOINTS.registry),
    fetchJSON(ENDPOINTS.health)
  ]);

  // Hide loading states
  showLoading("index", false);
  showLoading("registry", false);
  showLoading("health", false);

  // Update last data cache
  lastData = { idx, reg, hlt };

  // Badges
  Q("#idx-badge").textContent = idx?._meta ? `${idx._meta.total ?? "?"} items` : "—";
  Q("#reg-badge").textContent = reg?._meta ? `${reg._meta.total ?? "?"} servers` : "—";

  if (hlt?._meta) {
    const healthy = hlt._meta.healthy ?? 0, total = hlt._meta.total ?? 0;
    const pct = total ? Math.round((healthy * 100) / total) : 0;
    const b = Q("#hlt-badge");
    b.textContent = `${healthy}/${total} (${pct}%)`;
    colorBadge(b, pct === 100 ? "ok" : pct >= 50 ? "warn" : "err");
  } else {
    Q("#hlt-badge").textContent = "—";
  }

  // Payload for diff/search
  const payload = { idx, reg, hlt };
  const prev = loadSnapshot();

  // Diff calculation
  let d = { changed: false, add: 0, rem: 0 };
  if (prev?.data) d = diff(prev.data, payload);
  const db = Q("#diff-badge");
  db.textContent = d.changed ? `changed (+${d.add}/-${d.rem})` : "no change";
  colorBadge(db, d.changed ? "warn" : "ok");

  // Search filter
  const term = Q("#search").value.trim().toLowerCase();
  const showIdx = term ? filterObj(idx, term) : idx;
  const showReg = term ? filterObj(reg, term) : reg;
  const showHlt = term ? filterObj(hlt, term) : hlt;

  // Update views
  Q("#index-view").textContent = JSON.stringify(
    showIdx?._meta
      ? {
          _meta: pick(showIdx._meta, ["created_at", "source", "total", "mem_root"]),
          sample: (showIdx.items || []).slice(0, 30)
        }
      : showIdx,
    null,
    2
  );

  Q("#registry-view").textContent = JSON.stringify(
    showReg?._meta
      ? {
          _meta: pick(showReg._meta, ["created_at", "source", "config_path", "total"]),
          servers: (showReg.servers || []).slice(0, 30)
        }
      : showReg,
    null,
    2
  );

  Q("#health-view").textContent = JSON.stringify(showHlt, null, 2);

  // Update timestamp
  Q("#last-update").textContent = `Updated ${new Date().toLocaleTimeString()}`;

  // Save snapshot
  saveSnapshot(payload);

  // Auto-analyze if enabled
  if (aiSettings && aiSettings.autoAnalyze) {
    setTimeout(() => runAIAnalysis(), 1000); // Delay to let data settle
  }
}

// Debounced render for search
const debouncedRender = debounce(render, 300);

// ======== COPY TO CLIPBOARD ========
async function copyToClipboard(text) {
  try {
    await navigator.clipboard.writeText(text);
    toast("Copied to clipboard!", "success");
  } catch (e) {
    toast("Failed to copy", "error");
  }
}

// ======== EXPORT ========
async function exportData() {
  const data = {
    index: await fetchJSON(ENDPOINTS.index),
    registry: await fetchJSON(ENDPOINTS.registry),
    health: await fetchJSON(ENDPOINTS.health),
    exported_at: new Date().toISOString()
  };

  const blob = new Blob([JSON.stringify(data, null, 2)], { type: "application/json" });
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = `hub_export_${Date.now()}.json`;
  a.click();
  toast("Export complete!", "success");
}

// ======== HISTORY VIEW ========
function showHistory() {
  const modal = Q("#history-modal");
  const list = Q("#history-list");
  const history = loadHistory();

  if (history.length === 0) {
    list.innerHTML = "<p>No snapshots yet</p>";
  } else {
    list.innerHTML = history
      .map((snap, i) => {
        const date = new Date(snap.t);
        return `
          <div class="history-item" data-index="${i}">
            <div class="history-time">${date.toLocaleString()}</div>
            <div class="history-stats">
              ${snap.data.idx?._meta?.total || 0} items ·
              ${snap.data.reg?._meta?.total || 0} servers ·
              ${snap.data.hlt?._meta?.healthy || 0}/${snap.data.hlt?._meta?.total || 0} healthy
            </div>
            <button class="btn-compare" data-index="${i}">Compare</button>
          </div>
        `;
      })
      .join("");

    // Attach compare listeners
    QA(".btn-compare").forEach(btn => {
      btn.addEventListener("click", () => {
        const idx = parseInt(btn.dataset.index);
        compareSnapshot(history[idx]);
        modal.close();
      });
    });
  }

  modal.showModal();
}

function compareSnapshot(snap) {
  const current = lastData;
  const d = diff(snap.data, current);

  Q("#diff-view").textContent = JSON.stringify(
    {
      snapshot_time: new Date(snap.t).toISOString(),
      current_time: new Date().toISOString(),
      diff: d,
      changes: {
        index: diff(snap.data.idx, current.idx),
        registry: diff(snap.data.reg, current.reg),
        health: diff(snap.data.hlt, current.hlt)
      }
    },
    null,
    2
  );

  toast(`Comparing with snapshot from ${new Date(snap.t).toLocaleString()}`, "info");
}

// ======== PULL TO REFRESH ========
let pullStartY = 0;
let pullDistance = 0;

function initPullRefresh() {
  const pullIndicator = Q("#pull-refresh");
  let isPulling = false;

  document.addEventListener("touchstart", e => {
    if (window.scrollY === 0) {
      pullStartY = e.touches[0].clientY;
      isPulling = true;
    }
  });

  document.addEventListener("touchmove", e => {
    if (!isPulling) return;
    pullDistance = e.touches[0].clientY - pullStartY;

    if (pullDistance > 0 && pullDistance < 150) {
      pullIndicator.style.transform = `translateY(${pullDistance}px)`;
      pullIndicator.style.opacity = pullDistance / 150;
    }
  });

  document.addEventListener("touchend", () => {
    if (pullDistance > 80) {
      toast("Refreshing...", "info");
      render();
    }
    pullIndicator.style.transform = "";
    pullIndicator.style.opacity = "0";
    isPulling = false;
    pullDistance = 0;
  });
}

// ======== KEYBOARD SHORTCUTS ========
function initKeyboardShortcuts() {
  document.addEventListener("keydown", e => {
    // Ctrl+K: Focus search
    if (e.ctrlKey && e.key === "k") {
      e.preventDefault();
      Q("#search").focus();
    }

    // Ctrl+E: Export
    if (e.ctrlKey && e.key === "e") {
      e.preventDefault();
      exportData();
    }

    // Ctrl+H: History
    if (e.ctrlKey && e.key === "h") {
      e.preventDefault();
      showHistory();
    }

    // Alt+T: Toggle theme
    if (e.altKey && e.key === "t") {
      e.preventDefault();
      Q("#toggle-theme").click();
    }

    // Alt+R: Toggle regex
    if (e.altKey && e.key === "r") {
      e.preventDefault();
      Q("#regex-toggle").click();
    }

    // ?: Show shortcuts
    if (e.key === "?") {
      e.preventDefault();
      Q("#shortcuts-modal").showModal();
    }

    // Esc: Close modals
    if (e.key === "Escape") {
      QA("dialog[open]").forEach(d => d.close());
    }
  });
}

// ======== COLLAPSIBLE CARDS ========
function initCollapsible() {
  QA("[data-collapse]").forEach(btn => {
    btn.addEventListener("click", () => {
      const cardId = btn.dataset.collapse;
      const card = Q(`#${cardId}`);
      const body = card.querySelector(".card-body");

      if (card.classList.contains("collapsed")) {
        card.classList.remove("collapsed");
        body.style.display = "block";
        btn.textContent = "−";
      } else {
        card.classList.add("collapsed");
        body.style.display = "none";
        btn.textContent = "+";
      }
    });
  });
}

// ======== AI ANALYSIS ========
function loadAISettings() {
  try {
    const saved = localStorage.getItem(AI_SETTINGS_KEY);
    if (saved) {
      aiSettings = JSON.parse(saved);
    } else {
      // Default to Ollama
      aiSettings = {
        ...AI_PRESETS.ollama,
        autoAnalyze: false,
        detectAnomalies: true,
        trendAnalysis: true,
        recommendations: true
      };
    }
    return aiSettings;
  } catch (e) {
    console.error("Failed to load AI settings:", e);
    return AI_PRESETS.ollama;
  }
}

function saveAISettings(settings) {
  try {
    localStorage.setItem(AI_SETTINGS_KEY, JSON.stringify(settings));
    aiSettings = settings;
    toast("AI settings saved", "success");
  } catch (e) {
    toast("Failed to save AI settings", "error");
  }
}

function applyAIPreset(presetName) {
  const preset = AI_PRESETS[presetName];
  if (!preset) return;

  Q("#ai-endpoint").value = preset.endpoint;
  Q("#ai-model").value = preset.model;
  Q("#ai-api-key").value = preset.apiKey;
  toast(`Applied ${presetName} preset`, "info");
}

async function testAIConnection() {
  const endpoint = Q("#ai-endpoint").value;
  const model = Q("#ai-model").value;
  const apiKey = Q("#ai-api-key").value;

  if (!endpoint) {
    toast("Please enter an AI endpoint", "error");
    return;
  }

  toast("Testing connection...", "info");

  try {
    const testPrompt = "Respond with 'OK' if you can read this.";
    const response = await callAI(testPrompt, { endpoint, model, apiKey });

    if (response) {
      toast("✓ Connection successful!", "success");
    } else {
      toast("Connection failed - check endpoint and model", "error");
    }
  } catch (e) {
    toast(`Connection error: ${e.message}`, "error");
  }
}

async function callAI(prompt, settings = null, retries = 2) {
  const config = settings || aiSettings;
  if (!config || !config.endpoint) {
    throw new Error("AI endpoint not configured");
  }

  for (let attempt = 1; attempt <= retries; attempt++) {
    try {
      // Detect API type by endpoint
      const isOllama = config.endpoint.includes("ollama") || config.endpoint.includes("11434");
      const isOpenAI = config.endpoint.includes("openai.com") || config.endpoint.includes("/v1/chat/completions");

      let requestBody, headers;

      if (isOllama) {
        // Ollama format
        requestBody = {
          model: config.model,
          prompt: prompt,
          stream: false
        };
        headers = { "Content-Type": "application/json" };
      } else if (isOpenAI) {
        // OpenAI/compatible format
        requestBody = {
          model: config.model,
          messages: [
            { role: "system", content: "You are a helpful AI assistant analyzing hub monitoring data." },
            { role: "user", content: prompt }
          ],
          temperature: 0.7
        };
        headers = {
          "Content-Type": "application/json"
        };
        if (config.apiKey) {
          headers["Authorization"] = `Bearer ${config.apiKey}`;
        }
      } else {
        // Generic format (try OpenAI-compatible)
        requestBody = {
          model: config.model,
          messages: [{ role: "user", content: prompt }]
        };
        headers = { "Content-Type": "application/json" };
        if (config.apiKey) {
          headers["Authorization"] = `Bearer ${config.apiKey}`;
        }
      }

      const response = await fetch(config.endpoint, {
        method: "POST",
        headers: headers,
        body: JSON.stringify(requestBody),
        signal: AbortSignal.timeout(60000) // 60s timeout
      });

      if (!response.ok) {
        const errorText = await response.text().catch(() => response.statusText);
        throw new Error(`API returned ${response.status}: ${errorText}`);
      }

      const data = await response.json();

      // Extract response based on format
      if (isOllama) {
        return data.response;
      } else if (data.choices && data.choices[0]) {
        return data.choices[0].message?.content || data.choices[0].text;
      } else {
        return JSON.stringify(data);
      }
    } catch (e) {
      if (attempt === retries) {
        console.error(`AI call failed after ${retries} attempts:`, e);
        throw e;
      }
      // Retry with backoff for network errors
      if (e.name === 'TypeError' || e.name === 'NetworkError' || e.message.includes('fetch')) {
        const delay = Math.pow(2, attempt) * 1000; // 2s, 4s
        console.warn(`AI attempt ${attempt} failed, retrying in ${delay}ms...`);
        await new Promise(resolve => setTimeout(resolve, delay));
      } else {
        // Don't retry for API errors (auth, rate limit, etc)
        throw e;
      }
    }
  }
}

function generateAnalysisPrompt(data) {
  const { idx, reg, hlt } = data;

  const prompt = `Analyze this hub monitoring data and provide insights:

HUB INDEX:
- Total items: ${idx?._meta?.total || 0}
- Source: ${idx?._meta?.source || "unknown"}

MCP REGISTRY:
- Total servers: ${reg?._meta?.total || 0}
- Servers: ${JSON.stringify((reg?.servers || []).slice(0, 5))}

MCP HEALTH:
- Healthy: ${hlt?._meta?.healthy || 0}
- Total: ${hlt?._meta?.total || 0}
- Health rate: ${hlt?._meta?.total ? Math.round((hlt._meta.healthy / hlt._meta.total) * 100) : 0}%
- Results: ${JSON.stringify((hlt?.results || []).slice(0, 10))}

Please provide:
1. Overall health assessment
2. Any anomalies or concerns detected
3. Performance trends (if data shows patterns)
4. Specific recommendations for improvement
5. Risk assessment (low/medium/high)

Format your response in clear sections with bullet points.`;

  return prompt;
}

async function runAIAnalysis() {
  if (!aiSettings || !aiSettings.endpoint) {
    toast("AI not configured. Click 🤖 AI to set up.", "warn");
    Q("#ai-settings-modal").showModal();
    return;
  }

  const loadingEl = Q("#loading-ai");
  const placeholderEl = Q(".ai-placeholder");
  const quickStatsEl = Q("#ai-quick-stats");
  const analysisEl = Q("#ai-analysis-text");

  try {
    // Show loading
    loadingEl.style.display = "flex";
    if (placeholderEl) placeholderEl.style.display = "none";

    // Generate prompt
    const prompt = generateAnalysisPrompt(lastData);

    // Call AI
    const response = await callAI(prompt);

    // Hide loading
    loadingEl.style.display = "none";

    // Show results
    quickStatsEl.style.display = "block";
    analysisEl.style.display = "block";

    // Update quick stats
    const healthRate = lastData.hlt?._meta?.total
      ? Math.round((lastData.hlt._meta.healthy / lastData.hlt._meta.total) * 100)
      : 0;

    quickStatsEl.innerHTML = `
      <div class="stat-item">
        <span class="stat-label">Health Score</span>
        <span class="stat-value ${healthRate >= 80 ? 'ok' : healthRate >= 50 ? 'warn' : 'err'}">${healthRate}%</span>
      </div>
      <div class="stat-item">
        <span class="stat-label">Servers</span>
        <span class="stat-value">${lastData.reg?._meta?.total || 0}</span>
      </div>
      <div class="stat-item">
        <span class="stat-label">Items</span>
        <span class="stat-value">${lastData.idx?._meta?.total || 0}</span>
      </div>
      <div class="stat-item">
        <span class="stat-label">Analyzed</span>
        <span class="stat-value">${new Date().toLocaleTimeString()}</span>
      </div>
    `;

    // Show AI response
    analysisEl.textContent = response;

    // Update badge
    Q("#ai-badge").textContent = "analyzed";
    Q("#ai-badge").className = "badge ok";

    toast("AI analysis complete!", "success");
  } catch (e) {
    loadingEl.style.display = "none";
    analysisEl.style.display = "block";
    analysisEl.textContent = `Error: ${e.message}\n\nPlease check your AI settings and ensure the endpoint is accessible.`;
    Q("#ai-badge").textContent = "error";
    Q("#ai-badge").className = "badge err";
    toast("AI analysis failed", "error");
  }
}

function initAISettings() {
  // Load settings
  loadAISettings();

  // Apply to form
  if (aiSettings) {
    Q("#ai-endpoint").value = aiSettings.endpoint || "";
    Q("#ai-model").value = aiSettings.model || "";
    Q("#ai-api-key").value = aiSettings.apiKey || "";
    Q("#ai-auto-analyze").checked = aiSettings.autoAnalyze || false;
    Q("#ai-detect-anomalies").checked = aiSettings.detectAnomalies !== false;
    Q("#ai-trend-analysis").checked = aiSettings.trendAnalysis !== false;
    Q("#ai-recommendations").checked = aiSettings.recommendations !== false;
  }

  // Settings button
  Q("#ai-settings").onclick = () => Q("#ai-settings-modal").showModal();

  // Analyze button
  Q("#ai-analyze").onclick = runAIAnalysis;

  // Preset buttons
  QA(".preset-btn").forEach(btn => {
    btn.addEventListener("click", () => {
      applyAIPreset(btn.dataset.preset);
    });
  });

  // Test connection
  Q("#ai-test-connection").onclick = testAIConnection;

  // Save settings
  Q("#ai-save-settings").onclick = () => {
    const settings = {
      endpoint: Q("#ai-endpoint").value,
      model: Q("#ai-model").value,
      apiKey: Q("#ai-api-key").value,
      autoAnalyze: Q("#ai-auto-analyze").checked,
      detectAnomalies: Q("#ai-detect-anomalies").checked,
      trendAnalysis: Q("#ai-trend-analysis").checked,
      recommendations: Q("#ai-recommendations").checked
    };
    saveAISettings(settings);
    Q("#ai-settings-modal").close();
  };
}

// ======== SETUP ========
function setup() {
  // Theme
  const root = document.documentElement;
  const saved = localStorage.getItem("02luka.theme");
  if (saved) root.setAttribute("data-theme", saved);

  Q("#toggle-theme").onclick = () => {
    const cur = root.getAttribute("data-theme") === "dark" ? "light" : "dark";
    root.setAttribute("data-theme", cur);
    localStorage.setItem("02luka.theme", cur);

    // Update theme-color meta
    const themeColor = cur === "dark" ? "#0b0f19" : "#ffffff";
    Q('meta[name="theme-color"]').setAttribute("content", themeColor);
    toast(`Switched to ${cur} mode`, "success");
  };

  // Search with debounce
  Q("#search").addEventListener("input", debouncedRender);

  // Regex toggle
  Q("#regex-toggle").addEventListener("click", () => {
    useRegex = !useRegex;
    Q("#regex-toggle").classList.toggle("active", useRegex);
    toast(`Regex search ${useRegex ? "enabled" : "disabled"}`, "info");
    debouncedRender();
  });

  // Export
  Q("#export").onclick = exportData;

  // History
  Q("#history").onclick = showHistory;

  // Copy buttons
  QA("[data-copy]").forEach(btn => {
    btn.addEventListener("click", () => {
      const targetId = btn.dataset.copy;
      const text = Q(`#${targetId}`).textContent;
      copyToClipboard(text);
    });
  });

  // Auto refresh with custom interval
  const cb = Q("#autorefresh");
  const intervalSelect = Q("#refresh-interval");
  let timer = null;

  const applyRefresh = () => {
    if (timer) clearInterval(timer);
    if (cb.checked) {
      const interval = parseInt(intervalSelect.value);
      timer = setInterval(render, interval);
    }
  };

  cb.addEventListener("change", applyRefresh);
  intervalSelect.addEventListener("change", applyRefresh);
  applyRefresh();

  // Modal close buttons
  QA(".close-modal").forEach(btn => {
    btn.addEventListener("click", () => {
      btn.closest("dialog").close();
    });
  });

  // Keyboard shortcuts for modals (click ? in footer)
  Q("footer kbd").addEventListener("click", () => {
    Q("#shortcuts-modal").showModal();
  });

  // Initialize features
  initKeyboardShortcuts();
  initCollapsible();
  initPullRefresh();
  initAISettings();

  // Service worker
  if ("serviceWorker" in navigator) {
    navigator.serviceWorker.register("./sw.js").catch(() => {});
  }
}

// ======== INIT ========
window.addEventListener("load", async () => {
  setup();
  await render();
  toast("Hub Quicken v2 loaded", "success");
});
