/* High-precision timing utilities */

/**
 * Get current high-resolution timestamp
 * @returns {bigint} - Nanosecond timestamp
 */
function now() {
  return process.hrtime.bigint();
}

/**
 * Calculate milliseconds elapsed since start
 * @param {bigint} start - Start timestamp from now()
 * @returns {number} - Elapsed milliseconds (float)
 */
function msSince(start) {
  const ns = Number(process.hrtime.bigint() - start);
  return ns / 1e6;
}

/**
 * Calculate microseconds elapsed since start
 * @param {bigint} start - Start timestamp from now()
 * @returns {number} - Elapsed microseconds (float)
 */
function usSince(start) {
  const ns = Number(process.hrtime.bigint() - start);
  return ns / 1e3;
}

/**
 * Time an async function execution
 * @param {Function} fn - Async function to time
 * @returns {Promise<{result: any, elapsed_ms: number}>}
 */
async function time(fn) {
  const start = now();
  const result = await fn();
  const elapsed_ms = msSince(start);
  return { result, elapsed_ms };
}

/**
 * Calculate statistics from array of numbers
 * @param {number[]} values - Array of values
 * @returns {object} - Stats (min, max, mean, median, p95, p99)
 */
function stats(values) {
  if (values.length === 0) {
    return { count: 0, min: 0, max: 0, mean: 0, median: 0, p95: 0, p99: 0 };
  }

  const sorted = [...values].sort((a, b) => a - b);
  const sum = values.reduce((a, b) => a + b, 0);

  return {
    count: values.length,
    min: sorted[0],
    max: sorted[sorted.length - 1],
    mean: sum / values.length,
    median: sorted[Math.floor(sorted.length / 2)],
    p95: sorted[Math.floor(sorted.length * 0.95)],
    p99: sorted[Math.floor(sorted.length * 0.99)]
  };
}

module.exports = {
  now,
  msSince,
  usSince,
  time,
  stats
};
