#!/usr/bin/env node
/**
 * OPS-Atomic Monitor - 5-Minute Heartbeat
 *
 * Continuous health monitoring for 02luka infrastructure
 * Runs every 5 minutes via LaunchAgent
 *
 * Health Checks:
 * - Redis connectivity
 * - Database responsiveness
 * - API endpoint availability
 * - Service health
 *
 * Outputs:
 * - Timestamped reports to g/reports/ops_atomic/
 * - Logs to g/logs/ops_monitor.log
 * - Discord notifications on failures
 */

const { execSync, exec } = require('child_process');
const fs = require('fs');
const path = require('path');

// Configuration
const CONFIG = {
  repoRoot: process.env.REPO_ROOT || path.join(__dirname, '..'),
  reportsDir: 'g/reports/ops_atomic',
  logsDir: 'g/logs',
  redisHost: '127.0.0.1',
  redisPort: 6379,
  redisPassword: 'changeme-02luka',
  apiEndpoints: [
    { name: 'API Health', url: 'http://127.0.0.1:4000/healthz', timeout: 5000 },
  ],
  discordWebhook: process.env.DISCORD_OPS_WEBHOOK,
  alertThreshold: 3, // Alert after 3 consecutive failures
};

// State tracking
let consecutiveFailures = 0;
const startTime = new Date();

// Utility: Execute command with timeout
function execCommand(cmd, options = {}) {
  try {
    const result = execSync(cmd, {
      timeout: options.timeout || 5000,
      encoding: 'utf8',
      stdio: options.silent ? 'pipe' : 'inherit',
      ...options,
    });
    return { success: true, output: result };
  } catch (error) {
    return {
      success: false,
      error: error.message,
      output: error.stdout || error.stderr || '',
    };
  }
}

// Utility: Log to file
function log(message, level = 'INFO') {
  const timestamp = new Date().toISOString();
  const logMessage = `[${timestamp}] [${level}] ${message}\n`;

  const logPath = path.join(CONFIG.repoRoot, CONFIG.logsDir, 'ops_monitor.log');
  fs.appendFileSync(logPath, logMessage);

  if (level === 'ERROR' || level === 'WARN') {
    console.error(logMessage.trim());
  } else {
    console.log(logMessage.trim());
  }
}

// Health Check: Redis connectivity
async function checkRedis() {
  log('Checking Redis connectivity...');

  const result = execCommand(`redis-cli -h ${CONFIG.redisHost} -p ${CONFIG.redisPort} -a ${CONFIG.redisPassword} ping`, {
    silent: true,
    timeout: 3000,
  });

  if (result.success && result.output.includes('PONG')) {
    log('✅ Redis: OK');
    return { status: 'ok', message: 'Redis responding' };
  } else {
    log('❌ Redis: FAILED', 'ERROR');
    return { status: 'error', message: `Redis not responding: ${result.error}` };
  }
}

// Health Check: Database responsiveness
async function checkDatabase() {
  log('Checking database responsiveness...');

  // Check if database file exists
  const dbPath = path.join(CONFIG.repoRoot, 'knowledge', '02luka.db');
  const checkCmd = `test -f "${dbPath}" && echo "OK" || echo "MISSING"`;

  const result = execCommand(checkCmd, { silent: true, timeout: 2000 });

  if (result.success && result.output.includes('OK')) {
    log('✅ Database: OK');
    return { status: 'ok', message: 'Database file exists' };
  } else {
    log('❌ Database: FAILED', 'ERROR');
    return { status: 'error', message: 'Database file not found' };
  }
}

// Health Check: API endpoints
async function checkAPIEndpoints() {
  log('Checking API endpoints...');

  const results = [];

  for (const endpoint of CONFIG.apiEndpoints) {
    const curlCmd = `curl -fsS -m ${endpoint.timeout / 1000} "${endpoint.url}"`;
    const result = execCommand(curlCmd, { silent: true });

    if (result.success) {
      log(`✅ ${endpoint.name}: OK`);
      results.push({ name: endpoint.name, status: 'ok', message: 'Endpoint responding' });
    } else {
      log(`⚠️  ${endpoint.name}: WARN (may be down)`, 'WARN');
      results.push({ name: endpoint.name, status: 'warn', message: 'Endpoint not responding' });
    }
  }

  return results;
}

// Health Check: LaunchAgent status
async function checkLaunchAgents() {
  log('Checking critical LaunchAgents...');

  const agents = ['com.02luka.optimizer', 'com.02luka.digest'];
  const results = [];

  for (const agent of agents) {
    const result = execCommand(`launchctl list | grep ${agent}`, { silent: true });

    if (result.success && result.output.trim()) {
      log(`✅ ${agent}: Loaded`);
      results.push({ name: agent, status: 'ok', message: 'LaunchAgent loaded' });
    } else {
      log(`❌ ${agent}: NOT LOADED`, 'ERROR');
      results.push({ name: agent, status: 'error', message: 'LaunchAgent not loaded' });
    }
  }

  return results;
}

// Generate health report
async function generateReport(checks) {
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const reportFile = `heartbeat_${timestamp.split('T')[0]}_${timestamp.split('T')[1].substring(0, 8)}.md`;
  const reportPath = path.join(CONFIG.repoRoot, CONFIG.reportsDir, reportFile);

  // Ensure reports directory exists
  const reportsFullPath = path.join(CONFIG.repoRoot, CONFIG.reportsDir);
  if (!fs.existsSync(reportsFullPath)) {
    fs.mkdirSync(reportsFullPath, { recursive: true });
  }

  // Calculate overall status
  const hasErrors = checks.some(c =>
    (Array.isArray(c.result) && c.result.some(r => r.status === 'error')) ||
    (!Array.isArray(c.result) && c.result.status === 'error')
  );

  const hasWarnings = checks.some(c =>
    (Array.isArray(c.result) && c.result.some(r => r.status === 'warn')) ||
    (!Array.isArray(c.result) && c.result.status === 'warn')
  );

  const overallStatus = hasErrors ? '❌ CRITICAL' : hasWarnings ? '⚠️  WARNINGS' : '✅ HEALTHY';

  // Generate report content
  const report = `# OPS-Atomic Monitor Heartbeat

**Timestamp:** ${new Date().toISOString()}
**Status:** ${overallStatus}
**Duration:** ${Date.now() - startTime.getTime()}ms

---

## Health Checks

${checks.map(check => {
  if (Array.isArray(check.result)) {
    return `### ${check.name}

${check.result.map(r => `- **${r.name || 'Check'}:** ${r.status === 'ok' ? '✅' : r.status === 'warn' ? '⚠️' : '❌'} ${r.message}`).join('\n')}`;
  } else {
    return `### ${check.name}

- **Status:** ${check.result.status === 'ok' ? '✅' : '❌'} ${check.result.message}`;
  }
}).join('\n\n')}

---

## Summary

${hasErrors ? '🔴 **CRITICAL ISSUES DETECTED** - Immediate attention required' :
  hasWarnings ? '🟡 **WARNINGS PRESENT** - Review recommended' :
  '🟢 **ALL SYSTEMS OPERATIONAL**'}

**Next Check:** 5 minutes from now

---

*Generated by ops_atomic_monitor.cjs*
`;

  fs.writeFileSync(reportPath, report);
  log(`Report generated: ${reportFile}`);

  return { reportPath, reportFile, overallStatus };
}

// Send Discord notification (only on failures)
async function sendDiscordNotification(reportInfo, checks) {
  if (!CONFIG.discordWebhook) {
    log('Discord webhook not configured, skipping notification');
    return;
  }

  const hasErrors = checks.some(c =>
    (Array.isArray(c.result) && c.result.some(r => r.status === 'error')) ||
    (!Array.isArray(c.result) && c.result.status === 'error')
  );

  if (!hasErrors) {
    log('No errors detected, skipping Discord notification');
    return;
  }

  consecutiveFailures++;

  if (consecutiveFailures < CONFIG.alertThreshold) {
    log(`Failure ${consecutiveFailures}/${CONFIG.alertThreshold}, not alerting yet`);
    return;
  }

  log('Sending Discord notification for critical issues...');

  const errorDetails = checks
    .filter(c =>
      (Array.isArray(c.result) && c.result.some(r => r.status === 'error')) ||
      (!Array.isArray(c.result) && c.result.status === 'error')
    )
    .map(c => {
      if (Array.isArray(c.result)) {
        return `• ${c.name}: ${c.result.filter(r => r.status === 'error').map(r => r.message).join(', ')}`;
      } else {
        return `• ${c.name}: ${c.result.message}`;
      }
    })
    .join('\n');

  const payload = {
    content: `🚨 **OPS-Atomic Monitor Alert**`,
    embeds: [{
      title: '❌ Critical System Issues Detected',
      description: `Consecutive failures: ${consecutiveFailures}\n\n${errorDetails}`,
      color: 0xff0000,
      timestamp: new Date().toISOString(),
      footer: { text: 'OPS-Atomic Monitor' },
    }],
  };

  const curlCmd = `curl -X POST -H "Content-Type: application/json" -d '${JSON.stringify(payload)}' "${CONFIG.discordWebhook}"`;
  execCommand(curlCmd, { silent: true });

  log('Discord notification sent');
}

// Main execution
async function main() {
  log('=== OPS-Atomic Monitor Starting ===');

  try {
    // Run all health checks
    const checks = [
      { name: 'Redis', result: await checkRedis() },
      { name: 'Database', result: await checkDatabase() },
      { name: 'API Endpoints', result: await checkAPIEndpoints() },
      { name: 'LaunchAgents', result: await checkLaunchAgents() },
    ];

    // Generate report
    const reportInfo = await generateReport(checks);

    // Send Discord notification if needed
    await sendDiscordNotification(reportInfo, checks);

    // Reset consecutive failures if all healthy
    const hasErrors = checks.some(c =>
      (Array.isArray(c.result) && c.result.some(r => r.status === 'error')) ||
      (!Array.isArray(c.result) && c.result.status === 'error')
    );

    if (!hasErrors) {
      if (consecutiveFailures > 0) {
        log('System recovered, resetting failure counter');
      }
      consecutiveFailures = 0;
    }

    log(`=== Monitor Complete: ${reportInfo.overallStatus} ===`);

    // Exit with appropriate code
    process.exit(hasErrors ? 1 : 0);

  } catch (error) {
    log(`Fatal error: ${error.message}`, 'ERROR');
    log(error.stack, 'ERROR');
    process.exit(1);
  }
}

// Run monitor
main().catch(error => {
  log(`Unhandled error: ${error.message}`, 'ERROR');
  process.exit(1);
});
