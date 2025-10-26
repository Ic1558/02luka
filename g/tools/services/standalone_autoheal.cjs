#!/usr/bin/env node
/**
 * Standalone Auto-Heal Daemon for Docker-Free Environment
 * Monitors critical processes and restarts them on failure
 */

const { exec, spawn } = require('child_process');
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '../../..');
const LOGS = p => path.join(ROOT, 'g', 'telemetry', p);
const STATE = p => path.join(ROOT, 'g', 'state', p);

// Configuration
const MONITOR_PROCESSES = ['cloudflared', 'node.*http_redis_bridge'];
const HEALTH_ENDPOINTS = [
  { name: 'worker', url: 'https://ops-02luka.ittipong-c.workers.dev/api/ping' },
  { name: 'governance', url: 'https://ops-02luka.ittipong-c.workers.dev/ops/governance' }
];
const ALERT_URL = 'https://ops-02luka.ittipong-c.workers.dev/ops/alert';
const MONITOR_INTERVAL_MS = 30000; // 30 seconds
const RESTART_RETRIES = 3;
const RESTART_DELAY_MS = 5000;

// Ensure directories exist
fs.mkdirSync(LOGS(''), { recursive: true });
fs.mkdirSync(STATE(''), { recursive: true });

let processStates = {};

function logEvent(type, message, details = {}) {
  const logEntry = {
    timestamp: new Date().toISOString(),
    type,
    message,
    ...details
  };
  
  const logLine = JSON.stringify(logEntry) + '\n';
  fs.appendFileSync(LOGS('autoheal.log'), logLine);
  console.log(`[${logEntry.timestamp}] [${type}] ${message}`);
}

async function sendAlert(severity, source, title, details = {}) {
  try {
    const payload = {
      severity,
      source,
      title,
      details,
      dedupeKey: `${source}:${title}:${severity}`
    };
    
    const response = await fetch(ALERT_URL, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(payload)
    });
    
    const result = await response.json();
    logEvent('alert', `Alert sent: ${title}`, { severity, result });
    return result;
  } catch (error) {
    logEvent('error', 'Failed to send alert', { error: error.message });
  }
}

async function getProcessPid(processName) {
  return new Promise((resolve) => {
    exec(`pgrep -f "${processName}"`, (error, stdout) => {
      if (error) {
        resolve(null);
      } else {
        const pids = stdout.trim().split('\n').filter(Boolean);
        resolve(pids.length > 0 ? pids[0] : null);
      }
    });
  });
}

async function restartProcess(processName) {
  logEvent('info', `Attempting to restart ${processName}`);
  
  try {
    switch (processName) {
      case 'cloudflared':
        // Kill existing cloudflared
        exec('pkill -f cloudflared || true');
        
        // Start new cloudflared tunnel
        const cloudflared = spawn('cloudflared', ['tunnel', '--url', 'http://127.0.0.1:8788'], {
          detached: true,
          stdio: 'ignore'
        });
        cloudflared.unref();
        
        logEvent('info', 'cloudflared restarted');
        await sendAlert('warn', 'autoheal', 'Process restarted', { process: 'cloudflared' });
        break;
        
      case 'node.*http_redis_bridge':
        // For bridge, we'd need to restart the Docker stack
        // For now, just log that it would be restarted
        logEvent('info', 'http_redis_bridge would be restarted (requires Docker)');
        await sendAlert('warn', 'autoheal', 'Bridge restart required', { process: 'http_redis_bridge', note: 'requires Docker' });
        break;
        
      default:
        logEvent('warn', `Unknown process to restart: ${processName}`);
    }
    
    return true;
  } catch (error) {
    logEvent('error', `Failed to restart ${processName}`, { error: error.message });
    await sendAlert('error', 'autoheal', 'Process restart failed', { process: processName, error: error.message });
    return false;
  }
}

async function checkHealth() {
  for (const { name, url } of HEALTH_ENDPOINTS) {
    try {
      const response = await fetch(url, { timeout: 10000 });
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }
      logEvent('debug', `Health check OK for ${name}`, { url });
    } catch (error) {
      logEvent('error', `Health check FAILED for ${name}`, { url, error: error.message });
      await sendAlert('error', 'autoheal', 'Health check failed', { service: name, url, error: error.message });
    }
  }
}

async function monitorProcesses() {
  for (const processName of MONITOR_PROCESSES) {
    const currentPid = await getProcessPid(processName);
    
    if (!currentPid) {
      logEvent('warn', `${processName} process not found`);
      
      if (!processStates[processName]) {
        processStates[processName] = { failures: 0, lastRestart: 0 };
      }
      
      processStates[processName].failures++;
      const now = Date.now();
      
      if (processStates[processName].failures <= RESTART_RETRIES && 
          (now - processStates[processName].lastRestart) > RESTART_DELAY_MS) {
        
        const restarted = await restartProcess(processName);
        if (restarted) {
          processStates[processName].lastRestart = now;
          processStates[processName].failures = 0;
        }
      } else if (processStates[processName].failures > RESTART_RETRIES) {
        logEvent('error', `${processName} failed to restart after ${RESTART_RETRIES} attempts`);
        await sendAlert('error', 'autoheal', 'Process restart failed repeatedly', { 
          process: processName, 
          failures: processStates[processName].failures 
        });
      }
    } else {
      // Process is running, reset failures
      if (processStates[processName]) {
        processStates[processName].failures = 0;
      }
      logEvent('debug', `${processName} process running with PID ${currentPid}`);
    }
  }
}

// Main monitoring loop
async function startMonitoring() {
  logEvent('info', 'Standalone Auto-Heal Daemon started', {
    MONITOR_PROCESSES,
    HEALTH_ENDPOINTS: HEALTH_ENDPOINTS.map(e => e.url),
    MONITOR_INTERVAL_MS
  });
  
  // Initial health check
  await checkHealth();
  await monitorProcesses();
  
  // Start monitoring loop
  setInterval(async () => {
    await checkHealth();
    await monitorProcesses();
  }, MONITOR_INTERVAL_MS);
}

// Handle graceful shutdown
process.on('SIGINT', () => {
  logEvent('info', 'Auto-Heal Daemon shutting down');
  process.exit(0);
});

process.on('SIGTERM', () => {
  logEvent('info', 'Auto-Heal Daemon shutting down');
  process.exit(0);
});

// Start the daemon
startMonitoring().catch(error => {
  logEvent('error', 'Auto-Heal Daemon failed to start', { error: error.message });
  process.exit(1);
});
