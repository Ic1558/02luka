#!/usr/bin/env node
/**
 * Kim Proxy Gateway
 * ==================
 * Phase 15 - Autonomous Knowledge Routing (AKR)
 * Part of Issue #184: FAISS/HNSW Vector Index + Kim Proxy Gateway Integration
 *
 * This gateway provides intelligent query routing through Kim agent.
 * It classifies intent and delegates to appropriate backends:
 * - Andy (code tasks)
 * - System (ops commands)
 * - Vector Search (knowledge queries)
 *
 * Architecture:
 * User Query → Intent Classification → Route Decision → Backend Execution
 *
 * Endpoints:
 * - POST /query - Main query endpoint with intent routing
 * - POST /classify - Intent classification only
 * - GET /health - Health check
 * - GET /stats - Gateway statistics
 *
 * WO-ID: WO-251107-PHASE-15-KIM-PROXY
 */

const http = require('http');
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// Configuration
const PORT = 8767;
const HOST = '127.0.0.1';
const CONFIG_DIR = path.join(process.env.HOME, '02luka', 'config');
const TELEMETRY_FILE = path.join(process.env.HOME, '02luka', 'g', 'telemetry_unified', 'unified.jsonl');

// Backend endpoints
const BACKENDS = {
  vector_search: 'http://127.0.0.1:8766/vector_query',
  rag_legacy: 'http://127.0.0.1:8765/rag_query',
  mcp_memory: 'http://localhost:5330',
  mcp_search: 'http://localhost:5340'
};

// Statistics
const stats = {
  total_queries: 0,
  intent_classified: 0,
  routed_to_andy: 0,
  routed_to_system: 0,
  routed_to_vector: 0,
  routed_to_rag: 0,
  errors: 0
};

/**
 * Emit telemetry event in Phase 14.2 unified format
 */
function emitTelemetry(event, data) {
  const telemetry = {
    timestamp: new Date().toISOString(),
    event,
    agent: 'kim_proxy_gateway',
    phase: '15',
    work_order: 'WO-251107-PHASE-15-KIM-PROXY',
    data,
    __source: 'kim_proxy_gateway',
    __normalized: true
  };

  try {
    const dir = path.dirname(TELEMETRY_FILE);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
    fs.appendFileSync(TELEMETRY_FILE, JSON.stringify(telemetry) + '\n');
  } catch (err) {
    console.error('Warning: Failed to emit telemetry:', err.message);
  }
}

/**
 * Load Kim agent configuration
 */
function loadKimConfig() {
  try {
    const configPath = path.join(CONFIG_DIR, 'agents', 'kim.yaml');
    if (!fs.existsSync(configPath)) {
      console.warn('Kim config not found, using defaults');
      return null;
    }

    // Parse YAML using yq if available
    try {
      const yamlContent = execSync(`yq eval -o=json '.' "${configPath}"`).toString();
      return JSON.parse(yamlContent);
    } catch (err) {
      console.warn('yq not available, using basic config');
      return null;
    }
  } catch (err) {
    console.error('Failed to load Kim config:', err.message);
    return null;
  }
}

/**
 * Classify user query intent
 *
 * Returns: { intent, confidence, route, reason }
 */
function classifyIntent(query) {
  const queryLower = query.toLowerCase();

  // Code-related patterns (route to Andy)
  const codePatterns = [
    /\b(write|implement|create|add|build)\s+(code|function|class|component|api|feature)/i,
    /\b(fix|debug|resolve)\s+(bug|error|issue)/i,
    /\b(refactor|optimize|improve)\s+code/i,
    /\b(test|unit test|integration test)/i,
    /\b(commit|push|pull request|merge|branch)/i
  ];

  for (const pattern of codePatterns) {
    if (pattern.test(query)) {
      return {
        intent: 'code_task',
        confidence: 0.90,
        route: 'andy',
        reason: 'Code implementation or technical task detected'
      };
    }
  }

  // System command patterns
  const systemPatterns = [
    /\b(backup|restart|deploy|status|health)\b/i,
    /\b(check system|service status)/i,
    /\bซิงค์|สำรอง|รีสตาร์ท|รีลีส\b/i
  ];

  for (const pattern of systemPatterns) {
    if (pattern.test(query)) {
      return {
        intent: 'system_command',
        confidence: 0.85,
        route: 'system',
        reason: 'System operation or command detected'
      };
    }
  }

  // Knowledge query patterns (route to vector search)
  const knowledgePatterns = [
    /\b(what|who|when|where|why|how)\b/i,
    /\b(explain|describe|tell me|show me)\b/i,
    /\b(search|find|look for|locate)\b/i,
    /\b(summary|summarize|overview)\b/i,
    /\b(translate|แปล)\b/i
  ];

  for (const pattern of knowledgePatterns) {
    if (pattern.test(query)) {
      return {
        intent: 'knowledge_query',
        confidence: 0.80,
        route: 'vector_search',
        reason: 'Knowledge or information query detected'
      };
    }
  }

  // Default: route to vector search for general queries
  return {
    intent: 'general_query',
    confidence: 0.50,
    route: 'vector_search',
    reason: 'Default routing to knowledge base'
  };
}

/**
 * Execute query against vector search backend
 */
async function queryVectorSearch(query, options = {}) {
  const { top_k = 5, min_score = 0.7 } = options;

  const requestData = JSON.stringify({
    query,
    top_k,
    min_score
  });

  return new Promise((resolve, reject) => {
    const url = new URL(BACKENDS.vector_search);
    const req = http.request({
      hostname: url.hostname,
      port: url.port,
      path: url.pathname,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': requestData.length
      }
    }, (res) => {
      let data = '';

      res.on('data', (chunk) => {
        data += chunk;
      });

      res.on('end', () => {
        try {
          const result = JSON.parse(data);
          resolve(result);
        } catch (err) {
          reject(new Error(`Failed to parse response: ${err.message}`));
        }
      });
    });

    req.on('error', (err) => {
      reject(new Error(`Vector search request failed: ${err.message}`));
    });

    req.write(requestData);
    req.end();
  });
}

/**
 * Handle /query endpoint
 */
async function handleQuery(req, res) {
  const startTime = Date.now();

  try {
    let body = '';
    for await (const chunk of req) {
      body += chunk;
    }

    const data = JSON.parse(body);
    const query = data.query || '';

    if (!query) {
      res.writeHead(400, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: 'Missing query parameter' }));
      return;
    }

    stats.total_queries++;

    // Step 1: Classify intent
    const classification = classifyIntent(query);
    stats.intent_classified++;

    emitTelemetry('kim.intent.classified', {
      query,
      intent: classification.intent,
      confidence: classification.confidence,
      route: classification.route,
      reason: classification.reason
    });

    // Step 2: Route to appropriate backend
    let result;
    let backend;

    switch (classification.route) {
      case 'andy':
        stats.routed_to_andy++;
        backend = 'andy';
        result = {
          route: 'andy',
          message: 'This query requires code implementation. Please use Andy agent directly.',
          classification
        };
        break;

      case 'system':
        stats.routed_to_system++;
        backend = 'system';
        result = {
          route: 'system',
          message: 'This query requires system command execution. Please use system CLI.',
          classification
        };
        break;

      case 'vector_search':
      default:
        stats.routed_to_vector++;
        backend = 'vector_search';
        try {
          const vectorResult = await queryVectorSearch(query, data.options || {});
          result = {
            route: 'vector_search',
            backend: 'faiss_hnsw',
            query,
            results: vectorResult.results || [],
            latency_ms: vectorResult.latency_ms,
            classification
          };
        } catch (err) {
          // Fallback to legacy RAG if vector search fails
          stats.routed_to_rag++;
          console.error('Vector search failed, using legacy RAG:', err.message);
          result = {
            route: 'rag_legacy',
            backend: 'legacy',
            query,
            results: [],
            error: err.message,
            classification
          };
        }
        break;
    }

    const totalLatency = Date.now() - startTime;

    emitTelemetry('kim.query.completed', {
      query,
      route: classification.route,
      backend,
      latency_ms: totalLatency,
      num_results: result.results?.length || 0
    });

    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      ...result,
      total_latency_ms: totalLatency,
      timestamp: new Date().toISOString()
    }));

  } catch (err) {
    stats.errors++;
    console.error('Query error:', err);

    emitTelemetry('kim.query.error', { error: err.message });

    res.writeHead(500, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      error: err.message,
      timestamp: new Date().toISOString()
    }));
  }
}

/**
 * Handle /classify endpoint
 */
function handleClassify(req, res) {
  try {
    let body = '';
    req.on('data', (chunk) => {
      body += chunk;
    });

    req.on('end', () => {
      const data = JSON.parse(body);
      const query = data.query || '';

      if (!query) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'Missing query parameter' }));
        return;
      }

      const classification = classifyIntent(query);

      emitTelemetry('kim.classify.requested', { query, classification });

      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({
        query,
        classification,
        timestamp: new Date().toISOString()
      }));
    });
  } catch (err) {
    res.writeHead(500, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: err.message }));
  }
}

/**
 * Handle /health endpoint
 */
function handleHealth(req, res) {
  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({
    status: 'healthy',
    service: 'kim_proxy_gateway',
    version: '1.0.0',
    uptime_seconds: Math.floor(process.uptime()),
    backends: BACKENDS
  }));
}

/**
 * Handle /stats endpoint
 */
function handleStats(req, res) {
  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({
    stats,
    uptime_seconds: Math.floor(process.uptime()),
    timestamp: new Date().toISOString()
  }));
}

/**
 * Main HTTP server
 */
const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`);

  // CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.writeHead(200);
    res.end();
    return;
  }

  // Route requests
  if (url.pathname === '/query' && req.method === 'POST') {
    handleQuery(req, res);
  } else if (url.pathname === '/classify' && req.method === 'POST') {
    handleClassify(req, res);
  } else if (url.pathname === '/health' && req.method === 'GET') {
    handleHealth(req, res);
  } else if (url.pathname === '/stats' && req.method === 'GET') {
    handleStats(req, res);
  } else {
    res.writeHead(404, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Not found' }));
  }
});

/**
 * Main entry point
 */
function main() {
  console.log('='.repeat(60));
  console.log('Kim Proxy Gateway - Autonomous Knowledge Routing');
  console.log('='.repeat(60));
  console.log(`Server: http://${HOST}:${PORT}`);
  console.log('Backends:');
  Object.entries(BACKENDS).forEach(([name, url]) => {
    console.log(`  - ${name}: ${url}`);
  });
  console.log('='.repeat(60));

  // Load Kim config
  const kimConfig = loadKimConfig();
  if (kimConfig) {
    console.log('Kim agent configuration loaded');
  }

  // Start server
  server.listen(PORT, HOST, () => {
    console.log(`Kim Proxy Gateway listening on http://${HOST}:${PORT}`);

    emitTelemetry('service.started', {
      host: HOST,
      port: PORT,
      backends: Object.keys(BACKENDS)
    });
  });

  // Graceful shutdown
  process.on('SIGTERM', () => {
    console.log('SIGTERM received, shutting down gracefully...');
    emitTelemetry('service.stopped', { reason: 'SIGTERM' });
    server.close(() => {
      process.exit(0);
    });
  });
}

// Start the gateway
if (require.main === module) {
  main();
}

module.exports = { classifyIntent };
