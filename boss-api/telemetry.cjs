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
 * Read telemetry for a specific time range (N days back from endDate)
 *
 * Phase 7.1: Enhanced helper for self-review engine
 *
 * @param {object} options - Range options
 * @param {number} [options.days=7] - Number of days to look back
 * @param {Date} [options.endDate] - End date (defaults to now)
 * @returns {Array} Array of telemetry entries
 */
function readRange({ days = 7, endDate = new Date() } = {}) {
  const until = endDate;
  const since = new Date(endDate.getTime() - days * 24 * 60 * 60 * 1000);

  return read({ since, until });
}

/**
 * Calculate percentile from sorted array
 *
 * @param {Array<number>} sorted - Sorted array of numbers
 * @param {number} percentile - Percentile (0-100)
 * @returns {number} Percentile value
 */
function calculatePercentile(sorted, percentile) {
  if (sorted.length === 0) return 0;
  const index = Math.ceil((percentile / 100) * sorted.length) - 1;
  return sorted[Math.max(0, index)];
}

/**
 * Advanced analytics for telemetry entries
 *
 * Phase 7.1: Computes success rate, p95, flakiness, top failures, etc.
 *
 * @param {Array} entries - Telemetry entries to analyze
 * @returns {object} Advanced analytics results
 */
function analyze(entries) {
  if (!entries || entries.length === 0) {
    return {
      totalRuns: 0,
      successRate: 0,
      failRate: 0,
      warnRate: 0,
      avgDuration: 0,
      p95Duration: 0,
      p99Duration: 0,
      totalTests: 0,
      topFailures: [],
      slowTasks: [],
      flakiness: 0,
      byTask: {}
    };
  }

  const totalRuns = entries.length;
  const totalTests = entries.reduce((sum, e) => sum + e.pass + e.warn + e.fail, 0);
  const totalPass = entries.reduce((sum, e) => sum + e.pass, 0);
  const totalWarn = entries.reduce((sum, e) => sum + e.warn, 0);
  const totalFail = entries.reduce((sum, e) => sum + e.fail, 0);

  const successRate = totalTests > 0 ? totalPass / totalTests : 0;
  const failRate = totalTests > 0 ? totalFail / totalTests : 0;
  const warnRate = totalTests > 0 ? totalWarn / totalTests : 0;

  // Duration metrics
  const durations = entries.map(e => e.duration_ms).filter(d => d > 0).sort((a, b) => a - b);
  const avgDuration = durations.length > 0
    ? durations.reduce((a, b) => a + b, 0) / durations.length
    : 0;
  const p95Duration = calculatePercentile(durations, 95);
  const p99Duration = calculatePercentile(durations, 99);

  // Top failures (tasks with most fails)
  const failuresByTask = {};
  entries.forEach(e => {
    if (e.fail > 0) {
      if (!failuresByTask[e.task]) {
        failuresByTask[e.task] = { task: e.task, count: 0, totalFails: 0 };
      }
      failuresByTask[e.task].count++;
      failuresByTask[e.task].totalFails += e.fail;
    }
  });

  const topFailures = Object.values(failuresByTask)
    .sort((a, b) => b.totalFails - a.totalFails)
    .slice(0, 5);

  // Slow tasks (p95 duration by task)
  const byTask = {};
  entries.forEach(e => {
    if (!byTask[e.task]) {
      byTask[e.task] = {
        runs: 0,
        pass: 0,
        warn: 0,
        fail: 0,
        durations: []
      };
    }
    byTask[e.task].runs++;
    byTask[e.task].pass += e.pass;
    byTask[e.task].warn += e.warn;
    byTask[e.task].fail += e.fail;
    if (e.duration_ms > 0) {
      byTask[e.task].durations.push(e.duration_ms);
    }
  });

  const slowTasks = Object.entries(byTask)
    .map(([task, data]) => {
      const sorted = data.durations.sort((a, b) => a - b);
      return {
        task,
        runs: data.runs,
        p95: calculatePercentile(sorted, 95),
        avg: sorted.length > 0 ? sorted.reduce((a, b) => a + b, 0) / sorted.length : 0
      };
    })
    .filter(t => t.p95 > 0)
    .sort((a, b) => b.p95 - a.p95)
    .slice(0, 5);

  // Flakiness: tasks that sometimes pass, sometimes fail
  const flakinessScores = Object.entries(byTask)
    .filter(([_, data]) => data.runs > 1 && data.fail > 0 && data.pass > 0)
    .map(([task, data]) => {
      const failureRate = data.fail / (data.pass + data.warn + data.fail);
      return { task, failureRate, runs: data.runs };
    });

  const flakiness = flakinessScores.length > 0
    ? flakinessScores.reduce((sum, s) => sum + s.failureRate, 0) / flakinessScores.length
    : 0;

  // Compute final byTask summary with success rates
  const byTaskSummary = {};
  Object.entries(byTask).forEach(([task, data]) => {
    const total = data.pass + data.warn + data.fail;
    byTaskSummary[task] = {
      runs: data.runs,
      pass: data.pass,
      warn: data.warn,
      fail: data.fail,
      successRate: total > 0 ? data.pass / total : 0,
      avgDuration: data.durations.length > 0
        ? data.durations.reduce((a, b) => a + b, 0) / data.durations.length
        : 0
    };
  });

  return {
    totalRuns,
    successRate,
    failRate,
    warnRate,
    avgDuration,
    p95Duration,
    p99Duration,
    totalTests,
    topFailures,
    slowTasks,
    flakiness,
    flakyTasks: flakinessScores,
    byTask: byTaskSummary
  };
}

/**
 * Compare two analysis results to detect trends
 *
 * Phase 7.1: Trend detection for self-review
 *
 * @param {object} current - Current period analysis
 * @param {object} previous - Previous period analysis
 * @returns {object} Trend comparison
 */
function compareTrends(current, previous) {
  if (!previous || previous.totalRuns === 0) {
    return {
      trending: 'insufficient_data',
      successRateDelta: 0,
      p95DurationDelta: 0,
      failRateDelta: 0
    };
  }

  const successRateDelta = current.successRate - previous.successRate;
  const p95DurationDelta = current.p95Duration - previous.p95Duration;
  const failRateDelta = current.failRate - previous.failRate;

  let trending = 'stable';
  if (successRateDelta > 0.05) trending = 'improving';
  else if (successRateDelta < -0.05) trending = 'declining';

  return {
    trending,
    successRateDelta,
    p95DurationDelta,
    failRateDelta,
    p95DurationPct: previous.p95Duration > 0
      ? ((current.p95Duration - previous.p95Duration) / previous.p95Duration) * 100
      : 0
  };
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
  cleanup,
  // Phase 7.1: Advanced analytics
  readRange,
  analyze,
  compareTrends
};
