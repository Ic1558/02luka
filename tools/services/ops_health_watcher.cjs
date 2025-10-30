#!/usr/bin/env node
/* Ops Health Watcher - Lightweight monitoring for Ops UI */
const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');

const OPS_DOMAIN = process.env.OPS_DOMAIN || 'ops.theedges.work';
const METRICS_FILE = process.env.METRICS_FILE || '/app/g/metrics/ops_health.json';
const INTERVAL_MS = parseInt(process.env.HEALTH_INTERVAL || '300000'); // 5 minutes

function log(msg) {
  console.log(`[${new Date().toISOString()}] ${msg}`);
}

function execAsync(cmd) {
  return new Promise((resolve, reject) => {
    exec(cmd, (error, stdout, stderr) => {
      if (error) reject(error);
      else resolve({ stdout, stderr });
    });
  });
}

async function probeEndpoint(url, timeout = 10000) {
  const start = Date.now();
  try {
    const { stdout } = await execAsync(`curl -sS -m ${timeout/1000} "${url}"`);
    const latency = Date.now() - start;
    const data = JSON.parse(stdout);
    return { success: true, latency, data, error: null };
  } catch (error) {
    const latency = Date.now() - start;
    return { success: false, latency, data: null, error: error.message };
  }
}

async function runHealthCheck() {
  const timestamp = new Date().toISOString();
  log('Starting health check...');
  
  const endpoints = [
    { name: 'ping', url: `https://${OPS_DOMAIN}/api/ping` },
    { name: 'state', url: `https://${OPS_DOMAIN}/api/state` },
    { name: 'metrics', url: `https://${OPS_DOMAIN}/api/metrics` }
  ];
  
  const results = {};
  let totalSuccess = 0;
  let totalLatency = 0;
  
  for (const endpoint of endpoints) {
    log(`Probing ${endpoint.name}...`);
    const result = await probeEndpoint(endpoint.url);
    results[endpoint.name] = result;
    
    if (result.success) {
      totalSuccess++;
      totalLatency += result.latency;
    }
    
    log(`${endpoint.name}: ${result.success ? 'SUCCESS' : 'FAILED'} (${result.latency}ms)`);
  }
  
  const successRate = (totalSuccess / endpoints.length) * 100;
  const avgLatency = totalSuccess > 0 ? totalLatency / totalSuccess : 0;
  
  const healthData = {
    timestamp,
    success_rate: Math.round(successRate * 100) / 100,
    avg_latency_ms: Math.round(avgLatency),
    endpoints: results,
    uptime: process.uptime()
  };
  
  // Load existing metrics
  let metrics = { checks: [], summary: {} };
  try {
    if (fs.existsSync(METRICS_FILE)) {
      metrics = JSON.parse(fs.readFileSync(METRICS_FILE, 'utf8'));
    }
  } catch (error) {
    log(`Warning: Could not load existing metrics: ${error.message}`);
  }
  
  // Add new check
  metrics.checks.push(healthData);
  
  // Keep only last 100 checks (about 8 hours at 5-min intervals)
  if (metrics.checks.length > 100) {
    metrics.checks = metrics.checks.slice(-100);
  }
  
  // Calculate summary
  const recentChecks = metrics.checks.slice(-24); // Last 2 hours
  const recentSuccess = recentChecks.filter(c => c.success_rate === 100).length;
  const recentAvgLatency = recentChecks.reduce((sum, c) => sum + c.avg_latency_ms, 0) / recentChecks.length;
  
  metrics.summary = {
    last_check: timestamp,
    total_checks: metrics.checks.length,
    recent_success_rate: Math.round((recentSuccess / recentChecks.length) * 100),
    recent_avg_latency_ms: Math.round(recentAvgLatency),
    uptime_hours: Math.round(process.uptime() / 3600)
  };
  
  // Write metrics
  try {
    fs.mkdirSync(path.dirname(METRICS_FILE), { recursive: true });
    fs.writeFileSync(METRICS_FILE, JSON.stringify(metrics, null, 2));
    log(`Health check complete: ${successRate.toFixed(1)}% success, ${avgLatency.toFixed(0)}ms avg latency`);
  } catch (error) {
    log(`Error writing metrics: ${error.message}`);
  }
}

// Main loop
log(`Ops Health Watcher starting (${INTERVAL_MS/1000}s interval)`);
log(`Monitoring: https://${OPS_DOMAIN}`);
log(`Metrics file: ${METRICS_FILE}`);

// Run immediately
runHealthCheck().catch(error => {
  log(`Initial health check failed: ${error.message}`);
});

// Then run on interval
setInterval(() => {
  runHealthCheck().catch(error => {
    log(`Health check failed: ${error.message}`);
  });
}, INTERVAL_MS);

// Graceful shutdown
process.on('SIGTERM', () => {
  log('Shutting down gracefully...');
  process.exit(0);
});

process.on('SIGINT', () => {
  log('Shutting down gracefully...');
  process.exit(0);
});
