#!/usr/bin/env node
/**
 * Lightweight telemetry module for 02luka agent runs
 *
 * Appends JSON lines to g/telemetry/*.log files
 * Format: {ts, task, pass, warn, fail, duration_ms}
 *
 * Usage:
 *   const telemetry = require('./boss-api/telemetry.cjs');
 *   telemetry.record('smoke_api_ui', { pass: 5, warn: 0, fail: 0, duration_ms: 1234 });
 *
 * CLI Usage:
 *   node boss-api/telemetry.cjs --task smoke_api_ui --pass 5 --warn 0 --fail 0 --duration 1234
 */

const fs = require('fs');
const path = require('path');

// Resolve repo root
const REPO_ROOT = path.resolve(__dirname, '..');
const TELEMETRY_DIR = path.join(REPO_ROOT, 'g', 'telemetry');

/**
 * Ensure telemetry directory exists
 */
function ensureTelemetryDir() {
  if (!fs.existsSync(TELEMETRY_DIR)) {
    fs.mkdirSync(TELEMETRY_DIR, { recursive: true });
  }
}

/**
 * Get log file path for current date
 * Format: g/telemetry/YYYYMMDD.log
 */
function getLogFilePath() {
  const now = new Date();
  const dateStr = now.toISOString().split('T')[0].replace(/-/g, '');
  return path.join(TELEMETRY_DIR, `${dateStr}.log`);
}

/**
 * Record telemetry event
 *
 * @param {string} task - Task name (e.g., 'smoke_api_ui', 'ops_atomic')
 * @param {object} data - Event data
 * @param {number} data.pass - Number of passed tests
 * @param {number} data.warn - Number of warnings
 * @param {number} data.fail - Number of failures
 * @param {number} data.duration_ms - Duration in milliseconds
 * @param {string} [data.ts] - Timestamp (ISO 8601), defaults to now
 * @param {object} [data.meta] - Additional metadata (optional)
 */
function record(task, data) {
  try {
    ensureTelemetryDir();

    const entry = {
      ts: data.ts || new Date().toISOString(),
      task,
      pass: parseInt(data.pass || 0, 10),
      warn: parseInt(data.warn || 0, 10),
      fail: parseInt(data.fail || 0, 10),
      duration_ms: parseInt(data.duration_ms || 0, 10)
    };

    // Add optional metadata
    if (data.meta) {
      entry.meta = data.meta;
    }

    const logFile = getLogFilePath();
    const line = JSON.stringify(entry) + '\n';

    // Append to log file (create if doesn't exist)
    fs.appendFileSync(logFile, line, { encoding: 'utf8' });

    return entry;
  } catch (error) {
    console.error('[telemetry] Failed to record event:', error.message);
    return null;
  }
}

/**
 * Read telemetry entries from log files
 *
 * @param {object} options - Query options
 * @param {Date} [options.since] - Start date (inclusive)
 * @param {Date} [options.until] - End date (inclusive)
 * @param {string} [options.task] - Filter by task name
 * @returns {Array} Array of telemetry entries
 */
function read(options = {}) {
  try {
    ensureTelemetryDir();

    const entries = [];
    const files = fs.readdirSync(TELEMETRY_DIR)
      .filter(f => /^\d{8}\.log$/.test(f))
      .sort();

    for (const file of files) {
      const filePath = path.join(TELEMETRY_DIR, file);
      const content = fs.readFileSync(filePath, 'utf8');
      const lines = content.trim().split('\n').filter(Boolean);

      for (const line of lines) {
        try {
          const entry = JSON.parse(line);

          // Filter by date range
          if (options.since && new Date(entry.ts) < options.since) continue;
          if (options.until && new Date(entry.ts) > options.until) continue;

          // Filter by task
          if (options.task && entry.task !== options.task) continue;

          entries.push(entry);
        } catch (parseError) {
          console.error('[telemetry] Failed to parse line:', line);
        }
      }
    }

    return entries;
  } catch (error) {
    console.error('[telemetry] Failed to read entries:', error.message);
    return [];
  }
}

/**
 * Get summary statistics for a time period
 *
 * @param {object} options - Query options
 * @param {Date} [options.since] - Start date (defaults to 24 hours ago)
 * @param {Date} [options.until] - End date (defaults to now)
 * @returns {object} Summary statistics
 */
function summary(options = {}) {
  const since = options.since || new Date(Date.now() - 24 * 60 * 60 * 1000);
  const until = options.until || new Date();

  const entries = read({ since, until });

  const stats = {
    period: {
      since: since.toISOString(),
      until: until.toISOString()
    },
    total_runs: entries.length,
    total_pass: 0,
    total_warn: 0,
    total_fail: 0,
    total_duration_ms: 0,
    by_task: {}
  };

  for (const entry of entries) {
    stats.total_pass += entry.pass;
    stats.total_warn += entry.warn;
    stats.total_fail += entry.fail;
    stats.total_duration_ms += entry.duration_ms;

    if (!stats.by_task[entry.task]) {
      stats.by_task[entry.task] = {
        runs: 0,
        pass: 0,
        warn: 0,
        fail: 0,
        duration_ms: 0
      };
    }

    const taskStats = stats.by_task[entry.task];
    taskStats.runs++;
    taskStats.pass += entry.pass;
    taskStats.warn += entry.warn;
    taskStats.fail += entry.fail;
    taskStats.duration_ms += entry.duration_ms;
  }

  return stats;
}

/**
 * Clean up old telemetry logs
 *
 * @param {number} daysToKeep - Number of days to retain (default: 30)
 */
function cleanup(daysToKeep = 30) {
  try {
    ensureTelemetryDir();

    const cutoffDate = new Date(Date.now() - daysToKeep * 24 * 60 * 60 * 1000);
    const cutoffStr = cutoffDate.toISOString().split('T')[0].replace(/-/g, '');

    const files = fs.readdirSync(TELEMETRY_DIR)
      .filter(f => /^\d{8}\.log$/.test(f));

    let deleted = 0;
    for (const file of files) {
      const dateStr = file.replace('.log', '');
      if (dateStr < cutoffStr) {
        fs.unlinkSync(path.join(TELEMETRY_DIR, file));
        deleted++;
      }
    }

    return { deleted, kept: files.length - deleted };
  } catch (error) {
    console.error('[telemetry] Failed to cleanup:', error.message);
    return { deleted: 0, kept: 0 };
  }
}

// CLI support
if (require.main === module) {
  const args = process.argv.slice(2);

  if (args.includes('--help') || args.includes('-h')) {
    console.log(`
Usage: node telemetry.cjs [options]

Options:
  --task <name>       Task name (required)
  --pass <n>          Number of passed tests (default: 0)
  --warn <n>          Number of warnings (default: 0)
  --fail <n>          Number of failures (default: 0)
  --duration <ms>     Duration in milliseconds (default: 0)
  --summary           Show summary statistics for last 24h
  --cleanup [days]    Clean up logs older than N days (default: 30)
  -h, --help          Show this help

Examples:
  node telemetry.cjs --task smoke_api_ui --pass 5 --warn 0 --fail 0 --duration 1234
  node telemetry.cjs --summary
  node telemetry.cjs --cleanup 30
`);
    process.exit(0);
  }

  if (args.includes('--summary')) {
    const stats = summary();
    console.log(JSON.stringify(stats, null, 2));
    process.exit(0);
  }

  if (args.includes('--cleanup')) {
    const daysIndex = args.indexOf('--cleanup') + 1;
    const days = args[daysIndex] && !args[daysIndex].startsWith('--')
      ? parseInt(args[daysIndex], 10)
      : 30;
    const result = cleanup(days);
    console.log(`Cleanup: deleted ${result.deleted} files, kept ${result.kept} files`);
    process.exit(0);
  }

  // Record telemetry
  const data = {};
  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--task') data.task = args[++i];
    else if (args[i] === '--pass') data.pass = args[++i];
    else if (args[i] === '--warn') data.warn = args[++i];
    else if (args[i] === '--fail') data.fail = args[++i];
    else if (args[i] === '--duration') data.duration_ms = args[++i];
  }

  if (!data.task) {
    console.error('Error: --task is required');
    process.exit(1);
  }

  const entry = record(data.task, data);
  if (entry) {
    console.log(JSON.stringify(entry));
    process.exit(0);
  } else {
    process.exit(1);
  }
}

module.exports = {
  record,
  read,
  summary,
  cleanup
};
