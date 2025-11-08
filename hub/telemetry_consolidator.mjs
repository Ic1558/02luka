#!/usr/bin/env node
/**
 * Telemetry Consolidator — Phase 20.4
 *
 * Consolidates telemetry from multiple sources:
 * - hub/mcp_health.json
 * - hub/health_dashboard.json (if exists)
 * - ~/02luka/g/telemetry_unified/*.jsonl
 *
 * Outputs: hub/telemetry_snapshot.json
 * Alerts: Redis (hub:alerts) + optional Telegram
 */

import fs from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';
import { createRequire } from 'module';
import { glob } from 'glob';
import yaml from 'js-yaml';
import { createClient } from 'redis';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const require = createRequire(import.meta.url);

// --- Configuration ---
const LUKA_HOME = process.env.LUKA_HOME || path.join(process.env.HOME, '02luka');
const HUB_DIR = path.join(LUKA_HOME, 'hub');
const CONFIG_PATH = path.join(LUKA_HOME, 'config', 'telemetry_rules.yaml');
const TELEMETRY_DIR = path.join(LUKA_HOME, 'g', 'telemetry_unified');
const OUTPUT_PATH = path.join(HUB_DIR, 'telemetry_snapshot.json');

// Redis configuration
const REDIS_URL = process.env.REDIS_URL ||
  `redis://:${process.env.REDIS_PASSWORD || 'gggclukaic'}@${process.env.REDIS_HOST || 'localhost'}:6379`;

// Telegram configuration
const TELEGRAM_TOKEN = process.env.TELEGRAM_TOKEN;
const TELEGRAM_CHAT_ID = process.env.TELEGRAM_CHAT_ID;

/**
 * Load and parse configuration
 */
async function loadConfig() {
  try {
    const content = await fs.readFile(CONFIG_PATH, 'utf8');
    const config = yaml.load(content);

    // Interpolate environment variables
    if (config.routing?.telegram?.chat_id) {
      config.routing.telegram.chat_id = config.routing.telegram.chat_id.replace(
        /\$\{(\w+)\}/g,
        (_, key) => process.env[key] || ''
      );
    }

    return config;
  } catch (error) {
    console.error('❌ Failed to load config:', error.message);
    process.exit(1);
  }
}

/**
 * Read JSON file safely
 */
async function readJSON(filePath) {
  try {
    const content = await fs.readFile(filePath, 'utf8');
    return JSON.parse(content);
  } catch (error) {
    if (error.code === 'ENOENT') {
      return null;
    }
    console.warn(`⚠️  Failed to read ${filePath}:`, error.message);
    return null;
  }
}

/**
 * Read JSONL files and parse lines
 */
async function readJSONL(filePath, windowMinutes) {
  const lines = [];
  const cutoffTime = Date.now() - windowMinutes * 60 * 1000;

  try {
    const content = await fs.readFile(filePath, 'utf8');
    const jsonLines = content.trim().split('\n').filter(line => line.trim());

    for (const line of jsonLines) {
      try {
        const entry = JSON.parse(line);
        const timestamp = entry.timestamp ? new Date(entry.timestamp).getTime() : 0;

        // Only include entries within the time window
        if (timestamp >= cutoffTime) {
          lines.push(entry);
        }
      } catch (err) {
        // Skip malformed lines
      }
    }
  } catch (error) {
    if (error.code !== 'ENOENT') {
      console.warn(`⚠️  Failed to read JSONL ${filePath}:`, error.message);
    }
  }

  return lines;
}

/**
 * Consolidate telemetry from all sources
 */
async function consolidateTelemetry(config) {
  const windowMinutes = config.window_minutes || 10;
  const telemetry = {
    _meta: {
      created_by: 'GG_Agent_02luka',
      created_at: new Date().toISOString(),
      source: 'telemetry_consolidator.mjs',
      window_minutes: windowMinutes,
    },
    summary: {
      mcp_unhealthy: 0,
      errors: 0,
      warnings: 0,
    },
    alerts: [],
    sources: {},
  };

  // 1. Read MCP health
  const mcpHealth = await readJSON(path.join(HUB_DIR, 'mcp_health.json'));
  if (mcpHealth) {
    telemetry.sources.mcp_health = mcpHealth;

    // Count unhealthy MCP services
    if (mcpHealth.services) {
      telemetry.summary.mcp_unhealthy = Object.values(mcpHealth.services).filter(
        s => s.status !== 'healthy' && s.status !== 'ok'
      ).length;
    }
  }

  // 2. Read health dashboard (if exists)
  const healthDashboard = await readJSON(path.join(HUB_DIR, 'health_dashboard.json'));
  if (healthDashboard) {
    telemetry.sources.health_dashboard = healthDashboard;
  }

  // 3. Read unified telemetry JSONL files
  const telemetryFiles = await glob('*.jsonl', { cwd: TELEMETRY_DIR, absolute: true });
  const allEntries = [];

  for (const file of telemetryFiles) {
    const entries = await readJSONL(file, windowMinutes);
    allEntries.push(...entries);
  }

  // Count errors and warnings
  for (const entry of allEntries) {
    if (entry.level === 'error' || entry.severity === 'error') {
      telemetry.summary.errors++;
    } else if (entry.level === 'warn' || entry.level === 'warning' || entry.severity === 'warn') {
      telemetry.summary.warnings++;
    }
  }

  telemetry.sources.unified_telemetry = {
    total_entries: allEntries.length,
    files_processed: telemetryFiles.length,
  };

  // 4. Check thresholds and generate alerts
  const thresholds = config.thresholds || {};

  // MCP unhealthy alert
  if (telemetry.summary.mcp_unhealthy >= (thresholds.mcp_unhealthy || 1)) {
    telemetry.alerts.push({
      type: 'mcp_unhealthy',
      level: 'critical',
      reason: `${telemetry.summary.mcp_unhealthy} MCP service(s) unhealthy`,
      fired: true,
      value: telemetry.summary.mcp_unhealthy,
      threshold: thresholds.mcp_unhealthy,
    });
  }

  // Error count alert
  if (telemetry.summary.errors >= (thresholds.error_count || 3)) {
    telemetry.alerts.push({
      type: 'error_burst',
      level: 'warning',
      reason: `${telemetry.summary.errors} errors in ${windowMinutes}m (threshold: ${thresholds.error_count})`,
      fired: true,
      value: telemetry.summary.errors,
      threshold: thresholds.error_count,
    });
  }

  // Warning count alert
  if (thresholds.warn_count && telemetry.summary.warnings >= thresholds.warn_count) {
    telemetry.alerts.push({
      type: 'warning_burst',
      level: 'info',
      reason: `${telemetry.summary.warnings} warnings in ${windowMinutes}m (threshold: ${thresholds.warn_count})`,
      fired: true,
      value: telemetry.summary.warnings,
      threshold: thresholds.warn_count,
    });
  }

  return telemetry;
}

/**
 * Send alert to Redis
 */
async function sendRedisAlert(config, telemetry) {
  const channel = config.routing?.redis_channel || 'hub:alerts';

  try {
    const client = createClient({ url: REDIS_URL });
    await client.connect();

    for (const alert of telemetry.alerts.filter(a => a.fired)) {
      const payload = {
        ...alert,
        timestamp: new Date().toISOString(),
        source: 'telemetry_consolidator',
        summary: telemetry.summary,
      };

      await client.publish(channel, JSON.stringify(payload));
      console.log(`✅ Alert published to Redis [${channel}]:`, alert.type);
    }

    await client.quit();
  } catch (error) {
    console.error('❌ Failed to publish to Redis:', error.message);
  }
}

/**
 * Send alert to Telegram
 */
async function sendTelegramAlert(config, telemetry) {
  if (!config.routing?.telegram?.enabled) {
    return;
  }

  if (!TELEGRAM_TOKEN || !config.routing.telegram.chat_id) {
    console.warn('⚠️  Telegram enabled but missing TOKEN or CHAT_ID');
    return;
  }

  const chatId = config.routing.telegram.chat_id;
  const firedAlerts = telemetry.alerts.filter(a => a.fired);

  if (firedAlerts.length === 0) {
    return;
  }

  const message = [
    '🚨 *Telemetry Alert*',
    '',
    `📊 *Summary (${telemetry._meta.window_minutes}m window)*`,
    `• MCP Unhealthy: ${telemetry.summary.mcp_unhealthy}`,
    `• Errors: ${telemetry.summary.errors}`,
    `• Warnings: ${telemetry.summary.warnings}`,
    '',
    '*Alerts Fired:*',
    ...firedAlerts.map(a => `${a.level === 'critical' ? '🔴' : a.level === 'warning' ? '🟡' : 'ℹ️'} ${a.reason}`),
    '',
    `⏰ ${telemetry._meta.created_at}`,
  ].join('\n');

  try {
    const url = `https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage`;
    const response = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        chat_id: chatId,
        text: message,
        parse_mode: 'Markdown',
      }),
    });

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${await response.text()}`);
    }

    console.log('✅ Alert sent to Telegram');
  } catch (error) {
    console.error('❌ Failed to send Telegram alert:', error.message);
  }
}

/**
 * Main execution
 */
async function main() {
  console.log('🔄 Telemetry Consolidator — Phase 20.4');
  console.log('━'.repeat(50));

  // Load configuration
  const config = await loadConfig();
  console.log(`📋 Config loaded: ${config.window_minutes}m window`);

  // Consolidate telemetry
  const telemetry = await consolidateTelemetry(config);
  console.log(`📊 Telemetry consolidated:`);
  console.log(`   • MCP Unhealthy: ${telemetry.summary.mcp_unhealthy}`);
  console.log(`   • Errors: ${telemetry.summary.errors}`);
  console.log(`   • Warnings: ${telemetry.summary.warnings}`);
  console.log(`   • Alerts: ${telemetry.alerts.filter(a => a.fired).length}`);

  // Write snapshot
  await fs.writeFile(OUTPUT_PATH, JSON.stringify(telemetry, null, 2));
  console.log(`✅ Snapshot written: ${OUTPUT_PATH}`);

  // Send alerts if any fired
  const firedAlerts = telemetry.alerts.filter(a => a.fired);
  if (firedAlerts.length > 0) {
    console.log(`\n🚨 ${firedAlerts.length} alert(s) fired — routing...`);
    await sendRedisAlert(config, telemetry);
    await sendTelegramAlert(config, telemetry);
  } else {
    console.log('\n✅ No alerts fired — all clear');
  }

  console.log('━'.repeat(50));
  console.log('✅ Telemetry consolidation complete');
}

main().catch(error => {
  console.error('❌ Fatal error:', error);
  process.exit(1);
});
