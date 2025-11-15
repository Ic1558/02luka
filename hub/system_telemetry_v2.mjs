#!/usr/bin/env node
/**
 * Phase 21.4 – System Telemetry Aggregator v2
 *
 * Unified telemetry collector that aggregates:
 * - MCP Health monitoring
 * - Delegation Watchdog (LaunchAgent monitoring)
 * - Bridge Self-Check (MCP WebBridge health)
 *
 * Outputs:
 * - hub/system_telemetry_v2.json (unified telemetry data)
 * - Grafana Loki push (optional)
 * - Telegram summary (optional)
 *
 * Usage:
 *   node hub/system_telemetry_v2.mjs [--config=path/to/config.yaml]
 */

import { execSync } from 'child_process';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import http from 'http';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Configuration
const CONFIG = {
  repoRoot: process.env.REPO_ROOT || path.join(__dirname, '..'),
  configPath: process.env.TELEMETRY_V2_CONFIG || path.join(__dirname, '../config/telemetry_v2.yaml'),
  schemaPath: path.join(__dirname, '../g/schemas/telemetry_v2.schema.json'),
  outputPath: path.join(__dirname, 'system_telemetry_v2.json'),
  version: '2.0.0',
};

// Utility: Execute command with error handling
function execCommand(cmd, options = {}) {
  try {
    const result = execSync(cmd, {
      encoding: 'utf8',
      timeout: options.timeout || 5000,
      ...options,
    });
    return { success: true, output: result.trim() };
  } catch (error) {
    return {
      success: false,
      error: error.message,
      output: error.stdout ? error.stdout.trim() : '',
    };
  }
}

// Utility: HTTP GET with timeout
function httpGet(url, timeoutMs = 5000) {
  return new Promise((resolve, reject) => {
    const startTime = Date.now();
    const parsedUrl = new URL(url);

    const options = {
      hostname: parsedUrl.hostname,
      port: parsedUrl.port || 80,
      path: parsedUrl.pathname,
      method: 'GET',
      timeout: timeoutMs,
    };

    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => data += chunk);
      res.on('end', () => {
        const responseTime = Date.now() - startTime;
        resolve({
          statusCode: res.statusCode,
          data: data,
          responseTime,
        });
      });
    });

    req.on('error', (err) => reject(err));
    req.on('timeout', () => {
      req.destroy();
      reject(new Error('Request timeout'));
    });

    req.end();
  });
}

// Utility: Get git commit hash
function getGitCommit() {
  const result = execCommand('git rev-parse --short HEAD', { cwd: CONFIG.repoRoot });
  return result.success ? result.output : 'unknown';
}

// Utility: Get system uptime
function getSystemUptime() {
  const result = execCommand('uptime | awk \'{print $3}\' | sed \'s/,//\'');
  // Convert uptime to seconds (this is a simplified version)
  return result.success ? 0 : 0; // TODO: Implement proper uptime parsing
}

const KNOWN_LAUNCHCTL_STATES = new Set([
  'running',
  'waiting',
  'stopped',
  'launching',
  'throttled',
  'suspended',
]);

function normalizeLaunchctlState(rawState) {
  if (!rawState) {
    return 'unknown';
  }

  const normalized = rawState.toLowerCase();
  if (KNOWN_LAUNCHCTL_STATES.has(normalized)) {
    return normalized;
  }

  return 'unknown';
}

// Source 1: MCP Health
async function collectMcpHealth() {
  const timestamp = new Date().toISOString();
  const services = [];
  let overallStatus = 'ok';

  const mcpServices = [
    'com.02luka.mcp.fs',
    'com.02luka.mcp.puppeteer',
  ];

  for (const serviceName of mcpServices) {
    const result = execCommand(`launchctl print gui/$(id -u)/${serviceName} 2>&1`);

    const service = {
      name: serviceName,
      state: 'unknown',
      pid: null,
      last_exit_code: null,
      error_logs: [],
    };

    if (result.success) {
      // Parse launchctl output
      const stateMatch = result.output.match(/state\s*=\s*(\w+)/i);
      const pidMatch = result.output.match(/pid\s*=\s*(\d+)/i);
      const exitCodeMatch = result.output.match(/last exit code\s*=\s*(\d+)/i);

      if (stateMatch) {
        service.state = normalizeLaunchctlState(stateMatch[1]);
      }
      if (pidMatch) {
        service.pid = parseInt(pidMatch[1], 10);
      }
      if (exitCodeMatch) {
        service.last_exit_code = parseInt(exitCodeMatch[1], 10);
      }

      // Get error logs
      const logFileName = serviceName.replace('com.02luka.mcp.', 'mcp_') + '.stderr.log';
      const logPath = path.join(CONFIG.repoRoot, 'logs', logFileName);

      if (fs.existsSync(logPath)) {
        const logResult = execCommand(`tail -n 5 "${logPath}"`);
        if (logResult.success) {
          service.error_logs = logResult.output.split('\n').filter(line => line.trim());
        }
      }

      if (service.state !== 'running') {
        overallStatus = 'error';
      }
    } else {
      overallStatus = 'error';
      service.state = 'not running';
    }

    services.push(service);
  }

  return {
    status: overallStatus,
    timestamp,
    services,
  };
}

// Source 2: Delegation Watchdog
async function collectDelegationWatchdog() {
  const timestamp = new Date().toISOString();
  const agents = [];
  let overallStatus = 'ok';

  const launchAgents = [
    'com.02luka.optimizer',
    'com.02luka.digest',
    'com.02luka.mcp.fs',
    'com.02luka.mcp.puppeteer',
  ];

  for (const agentName of launchAgents) {
    const result = execCommand(`launchctl print gui/$(id -u)/${agentName} 2>&1`);

    const agent = {
      name: agentName,
      state: 'unknown',
      pid: null,
      last_exit_code: null,
      respawn_count: 0,
    };

    if (result.success) {
      const stateMatch = result.output.match(/state\s*=\s*(\w+)/i);
      const pidMatch = result.output.match(/pid\s*=\s*(\d+)/i);
      const exitCodeMatch = result.output.match(/last exit code\s*=\s*(\d+)/i);

      if (stateMatch) {
        const state = stateMatch[1].toLowerCase();
        agent.state = state === 'running' ? 'running' : state === 'waiting' ? 'stopped' : 'unknown';
      }
      if (pidMatch) {
        agent.pid = parseInt(pidMatch[1], 10);
      }
      if (exitCodeMatch) {
        agent.last_exit_code = parseInt(exitCodeMatch[1], 10);
        if (agent.last_exit_code !== 0) {
          agent.state = 'failed';
          overallStatus = 'degraded';
        }
      }
    } else {
      agent.state = 'stopped';
      overallStatus = 'degraded';
    }

    agents.push(agent);
  }

  return {
    status: overallStatus,
    timestamp,
    agents,
  };
}

// Source 3: Bridge Self-Check
async function collectBridgeSelfcheck() {
  const timestamp = new Date().toISOString();
  let status = 'ok';
  let httpStatus = null;
  let responseTimeMs = null;
  let serviceHealth = null;
  let errorMessage = null;

  try {
    const response = await httpGet('http://127.0.0.1:3003/health', 5000);
    httpStatus = response.statusCode;
    responseTimeMs = response.responseTime;

    if (httpStatus === 200) {
      try {
        serviceHealth = JSON.parse(response.data);

        // Check container health
        if (serviceHealth.containers) {
          const { unhealthy = 0 } = serviceHealth.containers;
          if (unhealthy > 0) {
            status = 'degraded';
          }
        }

        // Check Redis health
        if (serviceHealth.redis && serviceHealth.redis.status !== 'connected') {
          status = 'degraded';
        }
      } catch (err) {
        status = 'error';
        errorMessage = 'Failed to parse health response: ' + err.message;
      }
    } else {
      status = 'error';
      errorMessage = `Health endpoint returned status ${httpStatus}`;
    }

    // Check response time
    if (responseTimeMs > 5000) {
      status = status === 'ok' ? 'degraded' : status;
    }
  } catch (err) {
    status = 'unavailable';
    errorMessage = err.message;
  }

  return {
    status,
    timestamp,
    http_status: httpStatus,
    response_time_ms: responseTimeMs,
    service_health: serviceHealth,
    error_message: errorMessage,
  };
}

// Alert evaluation
function evaluateAlerts(sources) {
  const alerts = [];
  const timestamp = new Date().toISOString();

  // MCP Health alerts
  if (sources.mcp_health.status === 'error') {
    for (const service of sources.mcp_health.services) {
      if (service.state !== 'running') {
        alerts.push({
          name: 'mcp_service_down',
          severity: 'critical',
          message: `MCP service ${service.name} is ${service.state}`,
          timestamp,
          source: 'mcp_health',
          context: { service_name: service.name, state: service.state },
        });
      }
    }
  }

  // Delegation Watchdog alerts
  if (sources.delegation_watchdog.status !== 'ok') {
    for (const agent of sources.delegation_watchdog.agents) {
      if (agent.state === 'failed') {
        alerts.push({
          name: 'delegation_agent_failed',
          severity: 'warning',
          message: `LaunchAgent ${agent.name} failed with exit code ${agent.last_exit_code}`,
          timestamp,
          source: 'delegation_watchdog',
          context: { agent_name: agent.name, exit_code: agent.last_exit_code },
        });
      }
    }
  }

  // Bridge Self-Check alerts
  if (sources.bridge_selfcheck.http_status !== 200) {
    alerts.push({
      name: 'bridge_unhealthy',
      severity: 'critical',
      message: `MCP WebBridge health check failed (status: ${sources.bridge_selfcheck.http_status || 'N/A'})`,
      timestamp,
      source: 'bridge_selfcheck',
      context: { http_status: sources.bridge_selfcheck.http_status },
    });
  }

  if (sources.bridge_selfcheck.response_time_ms && sources.bridge_selfcheck.response_time_ms > 5000) {
    alerts.push({
      name: 'bridge_slow_response',
      severity: 'warning',
      message: `MCP WebBridge response time (${sources.bridge_selfcheck.response_time_ms}ms) exceeds threshold`,
      timestamp,
      source: 'bridge_selfcheck',
      context: { response_time_ms: sources.bridge_selfcheck.response_time_ms },
    });
  }

  return alerts;
}

// Calculate summary
function calculateSummary(sources, alerts) {
  const statusValues = ['ok', 'degraded', 'error', 'unavailable'];
  const sourceStatuses = [
    sources.mcp_health.status,
    sources.delegation_watchdog.status,
    sources.bridge_selfcheck.status,
  ];

  // Determine overall status (worst status wins)
  let overallStatus = 'ok';
  for (const status of sourceStatuses) {
    if (statusValues.indexOf(status) > statusValues.indexOf(overallStatus)) {
      overallStatus = status;
    }
  }

  const summary = {
    overall_status: overallStatus === 'unavailable' ? 'error' : overallStatus,
    total_sources: 3,
    healthy_sources: sourceStatuses.filter(s => s === 'ok').length,
    degraded_sources: sourceStatuses.filter(s => s === 'degraded').length,
    error_sources: sourceStatuses.filter(s => s === 'error' || s === 'unavailable').length,
    active_alerts: alerts.length,
  };

  return summary;
}

// Main aggregation function
async function aggregateTelemetry() {
  console.log('🔄 Starting telemetry aggregation...\n');

  // Collect from all sources
  console.log('📊 Collecting MCP Health...');
  const mcpHealth = await collectMcpHealth();
  console.log(`   Status: ${mcpHealth.status}\n`);

  console.log('📊 Collecting Delegation Watchdog...');
  const delegationWatchdog = await collectDelegationWatchdog();
  console.log(`   Status: ${delegationWatchdog.status}\n`);

  console.log('📊 Collecting Bridge Self-Check...');
  const bridgeSelfcheck = await collectBridgeSelfcheck();
  console.log(`   Status: ${bridgeSelfcheck.status}\n`);

  // Build telemetry object
  const sources = {
    mcp_health: mcpHealth,
    delegation_watchdog: delegationWatchdog,
    bridge_selfcheck: bridgeSelfcheck,
  };

  const alerts = evaluateAlerts(sources);
  const summary = calculateSummary(sources, alerts);

  const telemetry = {
    metadata: {
      version: CONFIG.version,
      repository: '02luka',
      component: 'system-telemetry-aggregator',
      phase: '21.4',
      hostname: execCommand('hostname').output || 'unknown',
      git_commit: getGitCommit(),
      uptime_seconds: getSystemUptime(),
    },
    timestamp: new Date().toISOString(),
    sources,
    alerts,
    summary,
  };

  // Write output
  console.log('💾 Writing telemetry to:', CONFIG.outputPath);
  fs.writeFileSync(CONFIG.outputPath, JSON.stringify(telemetry, null, 2));

  // Print summary
  console.log('\n📈 Summary:');
  console.log(`   Overall Status: ${summary.overall_status.toUpperCase()}`);
  console.log(`   Healthy Sources: ${summary.healthy_sources}/${summary.total_sources}`);
  console.log(`   Active Alerts: ${summary.active_alerts}`);

  if (alerts.length > 0) {
    console.log('\n⚠️  Active Alerts:');
    for (const alert of alerts) {
      const icon = alert.severity === 'critical' ? '🔴' : '🟡';
      console.log(`   ${icon} [${alert.severity.toUpperCase()}] ${alert.message}`);
    }
  }

  console.log('\n✅ Telemetry aggregation complete!\n');

  return telemetry;
}

// Export to Grafana Loki
async function exportToLoki(telemetry) {
  // TODO: Implement Loki push
  console.log('📤 Loki export not yet implemented');
}

// Send Telegram summary
async function sendTelegramSummary(telemetry) {
  // TODO: Implement Telegram notification
  console.log('📤 Telegram summary not yet implemented');
}

// Main entry point
async function main() {
  try {
    const telemetry = await aggregateTelemetry();

    // Optional exports
    if (process.env.EXPORT_LOKI === 'true') {
      await exportToLoki(telemetry);
    }

    if (process.env.EXPORT_TELEGRAM === 'true') {
      await sendTelegramSummary(telemetry);
    }

    process.exit(telemetry.summary.overall_status === 'error' ? 1 : 0);
  } catch (error) {
    console.error('❌ Error during telemetry aggregation:', error);
    process.exit(1);
  }
}

// Run if executed directly
if (import.meta.url === `file://${process.argv[1]}`) {
  main();
}

export { aggregateTelemetry, collectMcpHealth, collectDelegationWatchdog, collectBridgeSelfcheck };
