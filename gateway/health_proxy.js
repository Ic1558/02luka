#!/usr/bin/env node
/**
 * Health Proxy (Phase 4 Hardening)
 *
 * Aggregates health information for local services defined in
 * config/services.monitor.json. Provides Prometheus-style metrics
 * and a JSON health endpoint used by CI smoke tests.
 */

const http = require('http');
const fsp = require('fs').promises;
const path = require('path');
const net = require('net');

const PORT = Number(process.env.HEALTH_PROXY_PORT || 3002);
const CONFIG_PATH = process.env.HEALTH_PROXY_CONFIG || path.join(__dirname, '..', 'config', 'services.monitor.json');
const POLL_INTERVAL_MS = Number(process.env.HEALTH_PROXY_POLL_MS || 5000);
const REQUEST_TIMEOUT_MS = Number(process.env.HEALTH_PROXY_TIMEOUT_MS || 2500);

let pollTimer = null;
let shuttingDown = false;
const serviceState = new Map();
let currentConfig = {};
let lastConfigHash = '';
let lastUpdated = null;

async function readConfig() {
  try {
    const data = await fsp.readFile(CONFIG_PATH, 'utf8');
    const trimmed = data.trim();
    if (!trimmed) {
      return {};
    }
    if (trimmed === lastConfigHash) {
      return null; // unchanged
    }
    const config = JSON.parse(trimmed);
    lastConfigHash = trimmed;
    return config;
  } catch (err) {
    if (err.code === 'ENOENT') {
      if (lastConfigHash !== '__missing__') {
        console.warn(`[HealthProxy] Config not found at ${CONFIG_PATH}`);
        lastConfigHash = '__missing__';
      }
      return {};
    }
    console.error('[HealthProxy] Failed to read config:', err.message);
    return {};
  }
}

async function checkHttp(target) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
  const started = Date.now();

  try {
    const res = await fetch(target, {
      method: 'GET',
      redirect: 'follow',
      cache: 'no-store',
      signal: controller.signal
    });
    const latencyMs = Date.now() - started;
    return {
      ok: res.ok,
      latencyMs,
      status: res.status,
      error: res.ok ? null : `http_${res.status}`
    };
  } catch (err) {
    return {
      ok: false,
      latencyMs: Date.now() - started,
      status: 0,
      error: err.name === 'AbortError' ? 'timeout' : err.message
    };
  } finally {
    clearTimeout(timeout);
  }
}

async function checkTcp(target) {
  const [host, portStr] = String(target).split(':');
  const port = Number(portStr || '');

  if (!host || Number.isNaN(port)) {
    return { ok: false, latencyMs: 0, status: 0, error: 'invalid_tcp_address' };
  }

  return new Promise(resolve => {
    const started = Date.now();
    const socket = net.createConnection({ host, port });

    const finish = (ok, error) => {
      socket.destroy();
      resolve({
        ok,
        latencyMs: Date.now() - started,
        status: ok ? 1 : 0,
        error: error || null
      });
    };

    socket.setTimeout(REQUEST_TIMEOUT_MS, () => finish(false, 'timeout'));
    socket.on('connect', () => finish(true));
    socket.on('error', err => finish(false, err.code || err.message));
  });
}

async function probeService(name, spec = {}) {
  const target = spec.url || spec.target || '';
  const critical = Boolean(spec.critical);
  const type = spec.type || (target.startsWith('http') ? 'http' : 'tcp');

  if (!target) {
    return {
      ok: false,
      critical,
      target,
      type,
      latencyMs: 0,
      status: 0,
      error: 'missing_target',
      lastChecked: new Date().toISOString()
    };
  }

  const result = type === 'http' ? await checkHttp(target) : await checkTcp(target);

  return {
    ok: Boolean(result.ok),
    critical,
    target,
    type,
    latencyMs: result.latencyMs,
    status: result.status,
    error: result.error,
    lastChecked: new Date().toISOString()
  };
}

async function pollServices() {
  if (shuttingDown) return;

  const config = await readConfig();
  if (config && typeof config === 'object') {
    currentConfig = config;
  }

  const entries = Object.entries(currentConfig || {});

  // Remove services not present anymore
  for (const key of Array.from(serviceState.keys())) {
    if (!currentConfig[key]) {
      serviceState.delete(key);
    }
  }

  await Promise.all(entries.map(async ([name, spec]) => {
    const state = await probeService(name, spec);
    serviceState.set(name, state);
  }));

  lastUpdated = new Date();
}

function toJson() {
  const services = {};
  let allOk = true;

  for (const [name, info] of serviceState.entries()) {
    services[name] = info;
    if (info.critical && !info.ok) {
      allOk = false;
    }
  }

  return {
    ok: allOk,
    updatedAt: lastUpdated ? lastUpdated.toISOString() : null,
    services
  };
}

function renderMetrics() {
  const lines = [];
  lines.push('# HELP service_up Service availability status (1=up,0=down)');
  lines.push('# TYPE service_up gauge');

  for (const [name, info] of serviceState.entries()) {
    const critical = info.critical ? 'true' : 'false';
    lines.push(`service_up{service="${name}",critical="${critical}"} ${info.ok ? 1 : 0}`);
  }

  lines.push('');
  lines.push('# HELP service_latency_ms Observed latency in milliseconds for the last probe');
  lines.push('# TYPE service_latency_ms gauge');

  for (const [name, info] of serviceState.entries()) {
    const latency = Number.isFinite(info.latencyMs) ? info.latencyMs : 0;
    lines.push(`service_latency_ms{service="${name}"} ${latency}`);
  }

  lines.push('');
  lines.push('# HELP health_proxy_last_update Timestamp of the last successful poll (unix seconds)');
  lines.push('# TYPE health_proxy_last_update gauge');
  lines.push(`health_proxy_last_update ${lastUpdated ? Math.floor(lastUpdated.getTime() / 1000) : 0}`);

  return lines.join('\n');
}

function handleRequest(req, res) {
  if (req.url === '/health' || req.url === '/healthz') {
    const payload = toJson();
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(payload, null, 2));
    return;
  }

  if (req.url === '/metrics') {
    res.writeHead(200, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end(renderMetrics());
    return;
  }

  if (req.url === '/state') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      configPath: CONFIG_PATH,
      services: Array.from(serviceState.entries()),
      pollIntervalMs: POLL_INTERVAL_MS
    }, null, 2));
    return;
  }

  res.writeHead(404, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ error: 'not_found' }));
}

async function start() {
  await pollServices();
  pollTimer = setInterval(pollServices, POLL_INTERVAL_MS);

  const server = http.createServer(handleRequest);
  server.listen(PORT, () => {
    console.log(`[HealthProxy] Listening on port ${PORT}`);
  });

  const shutdown = () => {
    if (shuttingDown) return;
    shuttingDown = true;
    clearInterval(pollTimer);
    console.log('[HealthProxy] Shutting down');
    server.close(() => process.exit(0));
  };

  process.on('SIGINT', shutdown);
  process.on('SIGTERM', shutdown);
}

start().catch(err => {
  console.error('[HealthProxy] Failed to start:', err);
  process.exit(1);
});
