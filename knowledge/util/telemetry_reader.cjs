#!/usr/bin/env node
/**
 * Telemetry Feed Reader for CLC Optimization
 * Reads rollup data from Phase 9.2-E for optimization decisions
 */

const fs = require('fs');
const path = require('path');

const ROOT = process.cwd();
const ROLLUP_PATH = path.join(ROOT, 'g/telemetry/rollup_daily.ndjson');
const LATEST_PATH = path.join(ROOT, 'g/telemetry/latest_rollup.ndjson');

function readLatestRollup() {
  try {
    const rollupPath = fs.existsSync(LATEST_PATH) ? LATEST_PATH : ROLLUP_PATH;
    if (!fs.existsSync(rollupPath)) {
      console.warn('No telemetry rollup found');
      return [];
    }
    
    const content = fs.readFileSync(rollupPath, 'utf8');
    return content.trim().split('\n')
      .filter(Boolean)
      .map(line => {
        try {
          return JSON.parse(line);
        } catch (e) {
          console.warn('Invalid JSON line:', line);
          return null;
        }
      })
      .filter(Boolean);
  } catch (error) {
    console.error('Error reading telemetry rollup:', error.message);
    return [];
  }
}

function getMetricValue(metrics, metricName) {
  const metric = metrics.find(m => m.metric === metricName);
  return metric ? metric.value : null;
}

function getLatestMetrics() {
  const metrics = readLatestRollup();
  if (metrics.length === 0) {
    return {
      cache_hit_rate: 0,
      query_avg_ms: 0,
      query_p95_ms: 0,
      autoheal_events: 0,
      alerts_total: 0,
      alerts_warn: 0,
      alerts_error: 0
    };
  }
  
  return {
    cache_hit_rate: getMetricValue(metrics, 'cache_hit_rate') || 0,
    query_avg_ms: getMetricValue(metrics, 'query_avg_ms') || 0,
    query_p95_ms: getMetricValue(metrics, 'query_p95_ms') || 0,
    autoheal_events: getMetricValue(metrics, 'autoheal_events') || 0,
    alerts_total: getMetricValue(metrics, 'alerts_total') || 0,
    alerts_warn: getMetricValue(metrics, 'alerts_warn') || 0,
    alerts_error: getMetricValue(metrics, 'alerts_error') || 0
  };
}

// CLI usage
if (require.main === module) {
  const metrics = getLatestMetrics();
  console.log(JSON.stringify(metrics, null, 2));
}

module.exports = {
  readLatestRollup,
  getMetricValue,
  getLatestMetrics
};
