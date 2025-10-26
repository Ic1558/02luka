#!/usr/bin/env node
/**
 * CLS Phase 9.2 - Auto-Heal Daemon
 * Monitors critical processes and performs automatic recovery
 */

const fs = require('fs');
const path = require('path');
const { exec, spawn } = require('child_process');
const http = require('http');

const ROOT = path.resolve(__dirname, '../../..');
const LOGS = p => path.join(ROOT, 'g', 'logs', p);
const TELEMETRY = p => path.join(ROOT, 'g', 'telemetry', p);

// Configuration
const CONFIG = {
  // Process monitoring
  processes: [
    { name: 'cloudflared', cmd: 'cloudflared tunnel --url http://127.0.0.1:8788', pid: null },
    { name: 'bridge', cmd: 'node g/tools/services/http_redis_bridge.cjs', pid: null },
    { name: 'redis', cmd: 'redis-server', pid: null }
  ],
  
  // Health endpoints
  endpoints: [
    { name: 'worker', url: 'https://ops-02luka.ittipong-c.workers.dev/api/ping', timeout: 5000 },
    { name: 'bridge', url: 'http://127.0.0.1:8788/ping', timeout: 3000 }
  ],
  
  // Recovery settings
  maxRetries: 3,
  retryDelay: 5000,
  healthCheckInterval: 30000,
  
  // Alerting
  discordWebhook: process.env.DISCORD_WEBHOOK_URL || null,
  alertCooldown: 300000 // 5 minutes
};

// State tracking
const state = {
  lastAlert: 0,
  retryCount: {},
  processPids: {},
  healthStatus: {}
};

// Logging
function log(level, message, data = null) {
  const timestamp = new Date().toISOString();
  const logEntry = {
    timestamp,
    level,
    message,
    data
  };
  
  const logFile = TELEMETRY('autoheal.log');
  fs.appendFileSync(logFile, JSON.stringify(logEntry) + '\n');
  
  console.log(`[${timestamp}] [${level}] ${message}`, data ? JSON.stringify(data) : '');
}

// Process management
function findProcessPid(processName) {
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

function startProcess(processConfig) {
  return new Promise((resolve, reject) => {
    const [cmd, ...args] = processConfig.cmd.split(' ');
    const child = spawn(cmd, args, {
      detached: true,
      stdio: 'ignore'
    });
    
    child.unref();
    
    setTimeout(() => {
      resolve(child.pid);
    }, 1000);
  });
}

async function monitorProcess(processConfig) {
  const pid = await findProcessPid(processConfig.name);
  
  if (!pid) {
    log('WARN', `Process ${processConfig.name} not running, attempting restart`);
    
    try {
      const newPid = await startProcess(processConfig);
      log('INFO', `Process ${processConfig.name} restarted with PID ${newPid}`);
      
      // Send alert
      await sendAlert('WARN', `Process ${processConfig.name} was down and has been restarted`);
      
      return newPid;
    } catch (error) {
      log('ERROR', `Failed to restart process ${processConfig.name}`, error);
      await sendAlert('CRIT', `Failed to restart process ${processConfig.name}: ${error.message}`);
      return null;
    }
  }
  
  return pid;
}

// Health monitoring
async function checkHealth(endpoint) {
  return new Promise((resolve) => {
    const startTime = Date.now();
    
    const req = http.get(endpoint.url, { timeout: endpoint.timeout }, (res) => {
      const responseTime = Date.now() - startTime;
      
      if (res.statusCode === 200) {
        resolve({
          healthy: true,
          responseTime,
          statusCode: res.statusCode
        });
      } else {
        resolve({
          healthy: false,
          responseTime,
          statusCode: res.statusCode,
          error: `HTTP ${res.statusCode}`
        });
      }
    });
    
    req.on('error', (error) => {
      const responseTime = Date.now() - startTime;
      resolve({
        healthy: false,
        responseTime,
        error: error.message
      });
    });
    
    req.on('timeout', () => {
      req.destroy();
      resolve({
        healthy: false,
        responseTime: endpoint.timeout,
        error: 'Timeout'
      });
    });
  });
}

async function monitorHealth() {
  for (const endpoint of CONFIG.endpoints) {
    const health = await checkHealth(endpoint);
    state.healthStatus[endpoint.name] = health;
    
    if (!health.healthy) {
      log('WARN', `Health check failed for ${endpoint.name}`, health);
      await sendAlert('WARN', `Health check failed for ${endpoint.name}: ${health.error}`);
    } else {
      log('DEBUG', `Health check passed for ${endpoint.name}`, health);
    }
  }
}

// Alerting
async function sendAlert(severity, message) {
  const now = Date.now();
  
  // Cooldown check
  if (now - state.lastAlert < CONFIG.alertCooldown) {
    return;
  }
  
  state.lastAlert = now;
  
  if (CONFIG.discordWebhook) {
    try {
      const payload = {
        content: `🚨 **CLS Auto-Heal Alert**\n**Severity:** ${severity}\n**Message:** ${message}\n**Time:** ${new Date().toISOString()}`
      };
      
      const postData = JSON.stringify(payload);
      
      const options = {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(postData)
        }
      };
      
      const req = http.request(CONFIG.discordWebhook, options, (res) => {
        log('INFO', `Discord alert sent: ${res.statusCode}`);
      });
      
      req.on('error', (error) => {
        log('ERROR', `Failed to send Discord alert`, error);
      });
      
      req.write(postData);
      req.end();
    } catch (error) {
      log('ERROR', `Discord alert error`, error);
    }
  }
}

// Main monitoring loop
async function monitor() {
  log('INFO', 'Starting auto-heal monitoring cycle');
  
  // Monitor processes
  for (const process of CONFIG.processes) {
    const pid = await monitorProcess(process);
    if (pid) {
      state.processPids[process.name] = pid;
    }
  }
  
  // Monitor health endpoints
  await monitorHealth();
  
  // Log current state
  log('INFO', 'Auto-heal monitoring cycle complete', {
    processes: state.processPids,
    health: state.healthStatus
  });
}

// Signal handling
process.on('SIGINT', () => {
  log('INFO', 'Auto-heal daemon shutting down');
  process.exit(0);
});

process.on('SIGTERM', () => {
  log('INFO', 'Auto-heal daemon shutting down');
  process.exit(0);
});

// Start monitoring
log('INFO', 'CLS Auto-Heal Daemon starting', CONFIG);

// Initial monitoring
monitor();

// Set up interval
setInterval(monitor, CONFIG.healthCheckInterval);

log('INFO', 'Auto-heal daemon started successfully');
