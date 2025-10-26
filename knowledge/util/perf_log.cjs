// knowledge/util/perf_log.cjs
const fs = require('fs');
const path = require('path');

/**
 * Log query performance metrics to JSONL file
 * @param {object} entry - Log entry with query, mode, timings, resultCount, etc.
 */
function logQuery(entry) {
  const ROOT = path.resolve(__dirname, '..', '..');
  const logPath = path.join(ROOT, 'g', 'reports', 'query_perf.jsonl');

  // Ensure the directory exists
  const dir = path.dirname(logPath);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }

  // Create log entry with timestamp
  const line = JSON.stringify({
    ts: new Date().toISOString(),
    ...entry
  }) + '\n';

  // Append to file
  fs.appendFileSync(logPath, line);
}

module.exports = { logQuery };
