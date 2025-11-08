# Hub Quicken v2 - API Documentation

## Table of Contents
- [Data Sources](#data-sources)
- [AI Integration](#ai-integration)
- [LocalStorage API](#localstorage-api)
- [Service Worker API](#service-worker-api)
- [JavaScript API](#javascript-api)

---

## Data Sources

### Hub Index Endpoint
**URL:** `../../hub/index.json`
**Method:** GET
**Cache:** No cache (`cache: "no-store"`)

**Response Format:**
```typescript
interface HubIndex {
  _meta: {
    created_at: string;      // ISO 8601 timestamp
    source: string;          // "hub_indexer"
    total: number;           // Total items count
    mem_root: string;        // Memory root path
  };
  items: Array<{
    path: string;            // Relative file path
    size: number;            // File size in bytes
    modified: string;        // ISO 8601 timestamp
    type?: string;           // File type (optional)
  }>;
}
```

**Example:**
```json
{
  "_meta": {
    "created_at": "2025-11-08T12:34:56Z",
    "source": "hub_indexer",
    "total": 1247,
    "mem_root": "/home/user/02luka/memory"
  },
  "items": [
    {
      "path": "memory/agents/status.md",
      "size": 2048,
      "modified": "2025-11-08T10:00:00Z",
      "type": "markdown"
    }
  ]
}
```

---

### MCP Registry Endpoint
**URL:** `../../hub/mcp_registry.json`
**Method:** GET
**Cache:** No cache

**Response Format:**
```typescript
interface MCPRegistry {
  _meta: {
    created_at: string;
    source: string;          // "mcp_scanner"
    total: number;           // Total servers count
    config_path: string;     // MCP config file path
  };
  servers: Array<{
    name: string;            // Server identifier
    command: string;         // Executable command
    args: string[];          // Command arguments
    env?: Record<string, string>; // Environment variables
  }>;
}
```

**Example:**
```json
{
  "_meta": {
    "created_at": "2025-11-08T12:34:56Z",
    "source": "mcp_scanner",
    "total": 15,
    "config_path": "/home/user/.config/mcp/servers.json"
  },
  "servers": [
    {
      "name": "mcp-database",
      "command": "node",
      "args": ["dist/index.js"],
      "env": {
        "DATABASE_URL": "postgresql://localhost/db"
      }
    }
  ]
}
```

---

### MCP Health Endpoint
**URL:** `../../hub/mcp_health.json`
**Method:** GET
**Cache:** No cache

**Response Format:**
```typescript
interface MCPHealth {
  _meta: {
    created_at: string;
    healthy: number;         // Count of healthy servers
    total: number;           // Total servers checked
  };
  results: Array<{
    server: string;          // Server name
    status: "healthy" | "degraded" | "unhealthy";
    latency_ms: number;      // Response time in ms
    last_check: string;      // ISO 8601 timestamp
    error?: string;          // Error message if unhealthy
  }>;
}
```

**Example:**
```json
{
  "_meta": {
    "created_at": "2025-11-08T12:34:56Z",
    "healthy": 13,
    "total": 15
  },
  "results": [
    {
      "server": "mcp-database",
      "status": "healthy",
      "latency_ms": 45,
      "last_check": "2025-11-08T12:34:50Z"
    },
    {
      "server": "mcp-cache",
      "status": "degraded",
      "latency_ms": 250,
      "last_check": "2025-11-08T12:34:52Z"
    },
    {
      "server": "mcp-offline",
      "status": "unhealthy",
      "latency_ms": 0,
      "last_check": "2025-11-08T12:34:54Z",
      "error": "Connection refused"
    }
  ]
}
```

---

## AI Integration

### Ollama API
**Default Endpoint:** `http://localhost:11434/api/generate`
**Documentation:** https://ollama.com/docs/api

**Request:**
```typescript
interface OllamaRequest {
  model: string;           // e.g., "llama3.2:latest"
  prompt: string;          // Analysis prompt
  stream: boolean;         // Always false for Hub Quicken
  temperature?: number;    // 0.0 - 1.0 (optional)
}
```

**Response:**
```typescript
interface OllamaResponse {
  response: string;        // AI-generated text
  model: string;
  created_at: string;
  done: boolean;
}
```

**Example Request:**
```bash
curl http://localhost:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama3.2:latest",
    "prompt": "Analyze this hub data...",
    "stream": false
  }'
```

---

### OpenAI Compatible API
**Endpoint:** Configurable (OpenAI, LM Studio, etc.)
**Default:** `https://api.openai.com/v1/chat/completions`

**Request:**
```typescript
interface OpenAIRequest {
  model: string;           // e.g., "gpt-4o-mini"
  messages: Array<{
    role: "system" | "user" | "assistant";
    content: string;
  }>;
  temperature?: number;    // 0.0 - 2.0 (default: 0.7)
  max_tokens?: number;
}
```

**Response:**
```typescript
interface OpenAIResponse {
  choices: Array<{
    message: {
      role: string;
      content: string;       // AI-generated text
    };
    finish_reason: string;
  }>;
  usage: {
    prompt_tokens: number;
    completion_tokens: number;
    total_tokens: number;
  };
}
```

**Example Request:**
```bash
curl https://api.openai.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -d '{
    "model": "gpt-4o-mini",
    "messages": [
      {"role": "system", "content": "You are a hub analyst."},
      {"role": "user", "content": "Analyze this data..."}
    ],
    "temperature": 0.7
  }'
```

---

## LocalStorage API

### Keys Used

| Key | Type | Description |
|-----|------|-------------|
| `02luka.hub.quicken.snapshot.v1` | Object | Current snapshot |
| `02luka.hub.quicken.history.v1` | Array | Historical snapshots (max 50) |
| `02luka.hub.quicken.ai.v1` | Object | AI settings |
| `02luka.theme` | String | Theme preference ("dark" or "light") |

### Snapshot Format
```typescript
interface Snapshot {
  t: number;              // Timestamp (Date.now())
  data: {
    idx: HubIndex;
    reg: MCPRegistry;
    hlt: MCPHealth;
  };
}
```

### History Format
```typescript
type History = Snapshot[]; // Max 50 items, newest first
```

### AI Settings Format
```typescript
interface AISettings {
  endpoint: string;        // API endpoint URL
  model: string;           // Model name
  apiKey: string;          // API key (if required)
  autoAnalyze: boolean;    // Auto-analyze on refresh
  detectAnomalies: boolean;
  trendAnalysis: boolean;
  recommendations: boolean;
}
```

### Example Usage
```javascript
// Load snapshot
const snapshot = JSON.parse(localStorage.getItem('02luka.hub.quicken.snapshot.v1'));

// Save snapshot
localStorage.setItem('02luka.hub.quicken.snapshot.v1', JSON.stringify({
  t: Date.now(),
  data: { idx, reg, hlt }
}));

// Load history
const history = JSON.parse(localStorage.getItem('02luka.hub.quicken.history.v1') || '[]');

// Load AI settings
const aiSettings = JSON.parse(localStorage.getItem('02luka.hub.quicken.ai.v1'));
```

---

## Service Worker API

### Cache Names
- **Static Cache:** `hub-quicken-v2`
- **Runtime Cache:** `hub-quicken-runtime`

### Caching Strategy

**Static Assets (HTML/CSS/JS):**
- Strategy: Cache-first with background update
- Files: `index.html`, `style.css`, `app.js`, `manifest.json`

**JSON Data:**
- Strategy: Network-first with cache fallback
- Files: `*.json` endpoints
- Fallback: Offline indicator in response

### Manual Cache Control
```javascript
// Clear all caches
if ('serviceWorker' in navigator) {
  navigator.serviceWorker.controller.postMessage({
    type: 'CLEAR_CACHE'
  });
}

// Update service worker
if ('serviceWorker' in navigator) {
  navigator.serviceWorker.controller.postMessage({
    type: 'SKIP_WAITING'
  });
}
```

---

## JavaScript API

### Core Functions

#### Data Fetching
```javascript
/**
 * Fetch JSON data from endpoint
 * @param {string} url - Endpoint URL
 * @returns {Promise<Object>} Parsed JSON or error object
 */
async function fetchJSON(url);

/**
 * Main render function - fetches all data and updates UI
 * @returns {Promise<void>}
 */
async function render();
```

#### Search & Filter
```javascript
/**
 * Filter object by search term
 * @param {Object} obj - Object to filter
 * @param {string} term - Search term (lowercase)
 * @returns {Object} Filtered object
 */
function filterObj(obj, term);

/**
 * Normalize object for search comparison
 * @param {Object} obj - Object to normalize
 * @returns {string} Lowercase JSON string
 */
function normalizeForSearch(obj);
```

#### Snapshot Management
```javascript
/**
 * Save current snapshot to localStorage
 * @param {Object} data - Snapshot data {idx, reg, hlt}
 */
function saveSnapshot(data);

/**
 * Load snapshot from localStorage
 * @returns {Object|null} Snapshot or null
 */
function loadSnapshot();

/**
 * Add snapshot to history
 * @param {Object} data - Snapshot data
 */
function addToHistory(data);

/**
 * Load history from localStorage
 * @returns {Array} Array of snapshots (max 50)
 */
function loadHistory();
```

#### AI Functions
```javascript
/**
 * Call AI endpoint with prompt
 * @param {string} prompt - Analysis prompt
 * @param {Object} settings - AI settings override (optional)
 * @returns {Promise<string>} AI response text
 */
async function callAI(prompt, settings = null);

/**
 * Generate analysis prompt from hub data
 * @param {Object} data - Hub data {idx, reg, hlt}
 * @returns {string} Formatted prompt
 */
function generateAnalysisPrompt(data);

/**
 * Run AI analysis on current data
 * @returns {Promise<void>}
 */
async function runAIAnalysis();

/**
 * Test AI connection with test prompt
 * @returns {Promise<void>}
 */
async function testAIConnection();
```

#### Utility Functions
```javascript
/**
 * Show toast notification
 * @param {string} message - Message text
 * @param {string} type - "success"|"error"|"warn"|"info"
 */
function toast(message, type = "info");

/**
 * Copy text to clipboard
 * @param {string} text - Text to copy
 * @returns {Promise<void>}
 */
async function copyToClipboard(text);

/**
 * Debounce function calls
 * @param {Function} fn - Function to debounce
 * @param {number} delay - Delay in ms
 * @returns {Function} Debounced function
 */
function debounce(fn, delay);

/**
 * Calculate diff between objects
 * @param {Object} a - First object
 * @param {Object} b - Second object
 * @returns {Object} {changed, add, rem}
 */
function diff(a, b);
```

### DOM Selectors
```javascript
// Quick selector
const Q = sel => document.querySelector(sel);

// Query all
const QA = sel => document.querySelectorAll(sel);

// Examples:
Q("#search")              // Search input
Q("#ai-badge")            // AI badge element
QA(".card")               // All cards
QA("[data-collapse]")     // All collapse buttons
```

### Constants
```javascript
// Storage keys
const SKEY = "02luka.hub.quicken.snapshot.v1";
const HKEY = "02luka.hub.quicken.history.v1";
const AI_SETTINGS_KEY = "02luka.hub.quicken.ai.v1";
const MAX_HISTORY = 50;

// Endpoints
const ENDPOINTS = {
  index: "../../hub/index.json",
  registry: "../../hub/mcp_registry.json",
  health: "../../hub/mcp_health.json"
};

// AI Presets
const AI_PRESETS = {
  ollama: { endpoint: "http://localhost:11434/api/generate", model: "llama3.2:latest", apiKey: "" },
  lmstudio: { endpoint: "http://localhost:1234/v1/chat/completions", model: "local-model", apiKey: "" },
  openai: { endpoint: "https://api.openai.com/v1/chat/completions", model: "gpt-4o-mini", apiKey: "" },
  custom: { endpoint: "", model: "", apiKey: "" }
};
```

---

## Events & Lifecycle

### Page Load
```javascript
window.addEventListener("load", async () => {
  setup();           // Initialize UI
  await render();    // First data fetch
  toast("Hub Quicken v2 loaded", "success");
});
```

### Setup Sequence
1. Load theme preference
2. Attach event listeners
3. Initialize keyboard shortcuts
4. Initialize collapsible cards
5. Initialize pull-to-refresh
6. Initialize AI settings
7. Register service worker

### Auto-Refresh
```javascript
// Triggered by checkbox + interval selector
setInterval(render, interval); // 5s/10s/30s/1m
```

### Auto-Analyze
```javascript
// Triggered after render if enabled
if (aiSettings.autoAnalyze) {
  setTimeout(() => runAIAnalysis(), 1000);
}
```

---

## Error Handling

### Network Errors
```javascript
try {
  const response = await fetch(url);
  if (!response.ok) throw new Error(`${response.status} ${response.statusText}`);
  return await response.json();
} catch (e) {
  toast(`Failed to fetch: ${e.message}`, "error");
  return { _error: String(e), _url: url };
}
```

### AI Errors
```javascript
try {
  const response = await callAI(prompt);
  // Success handling
} catch (e) {
  toast(`AI analysis failed: ${e.message}`, "error");
  // Show error in UI
}
```

### Storage Errors
```javascript
try {
  localStorage.setItem(key, value);
} catch (e) {
  console.error("Storage failed:", e);
  toast("Failed to save settings", "error");
}
```

---

## Extension Points

### Custom Data Sources
```javascript
// Add new endpoint
const ENDPOINTS = {
  index: "../../hub/index.json",
  registry: "../../hub/mcp_registry.json",
  health: "../../hub/mcp_health.json",
  custom: "../../hub/custom.json"  // Add here
};

// Fetch in render()
const custom = await fetchJSON(ENDPOINTS.custom);
```

### Custom AI Provider
```javascript
// Add preset
const AI_PRESETS = {
  // ... existing presets
  myai: {
    endpoint: "https://my-ai.com/api/chat",
    model: "my-model-v1",
    apiKey: ""
  }
};

// Add button in HTML
<button class="preset-btn" data-preset="myai">My AI</button>
```

### Custom Themes
```css
/* Add in style.css */
:root[data-theme="custom"] {
  --bg: #yourcolor;
  --fg: #yourcolor;
  /* ... */
}
```

---

## Rate Limits & Best Practices

### Data Endpoints
- **Recommended refresh:** 10s minimum
- **Max frequency:** 5s (use sparingly)
- **Timeout:** 30s default

### AI APIs
- **Ollama:** No rate limit (local)
- **LM Studio:** No rate limit (local)
- **OpenAI:** [See pricing](https://openai.com/pricing)
  - Free tier: Limited requests/day
  - Paid tier: Variable by plan

### LocalStorage
- **Quota:** Typically 5-10 MB
- **Current usage:** ~100-500 KB (50 snapshots)
- **Fallback:** Graceful degradation if full

---

## Security Considerations

### API Keys
- Stored in localStorage (browser-only)
- Never logged or transmitted except to configured endpoint
- **Recommendation:** Use environment variables or secure vault in production

### CORS
- Data endpoints must allow cross-origin requests
- AI endpoints must have appropriate CORS headers
- Service worker requires same-origin or proper CORS

### Content Security Policy
```html
<!-- Recommended CSP -->
<meta http-equiv="Content-Security-Policy"
  content="default-src 'self';
           script-src 'self';
           style-src 'self' 'unsafe-inline';
           connect-src 'self' http://localhost:* https://api.openai.com;
           img-src 'self' data:;">
```

---

## Performance Metrics

### Target Metrics
- **First Contentful Paint:** < 1s
- **Time to Interactive:** < 2s
- **Data Fetch:** < 500ms (local network)
- **AI Analysis:** Variable (5-30s depending on model)
- **Search Response:** < 100ms (debounced)

### Optimization Tips
1. Use debouncing for search (currently 300ms)
2. Lazy load cards (display one at a time)
3. Limit history to 50 snapshots
4. Cache AI responses (future enhancement)
5. Use smaller AI models for speed

---

**For more information, see [README.md](README.md)**
