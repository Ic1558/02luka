// ======== UTILITY FUNCTIONS ========
const Q = sel => document.querySelector(sel);
const QA = sel => document.querySelectorAll(sel);
const SKEY = "02luka.hub.quicken.snapshot.v1";
const HKEY = "02luka.hub.quicken.history.v1";
const MAX_HISTORY = 50;

const ENDPOINTS = {
  index: "../../hub/index.json",
  registry: "../../hub/mcp_registry.json",
  health: "../../hub/mcp_health.json"
};

let useRegex = false;
let lastData = {};

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
async function fetchJSON(url) {
  try {
    const r = await fetch(url, { cache: "no-store" });
    if (!r.ok) throw new Error(`${r.status} ${r.statusText}`);
    return await r.json();
  } catch (e) {
    toast(`Failed to fetch ${url.split('/').pop()}: ${e.message}`, "error");
    return { _error: String(e), _url: url };
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
