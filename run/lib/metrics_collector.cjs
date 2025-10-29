#!/usr/bin/env node
/**
 * Metrics Collector
 *
 * Collects and aggregates system metrics:
 * - Service response times
 * - Error rates
 * - Request counts
 * - Resource usage
 *
 * Phase 3 - Observability
 */

const fs = require('fs');
const path = require('path');

class MetricsCollector {
  constructor(options = {}) {
    this.metricsFile = options.metricsFile || 'g/state/metrics.json';
    this.aggregationInterval = options.aggregationInterval || 60000; // 1 minute
    this.retentionHours = options.retentionHours || 24;

    this.currentMetrics = {};
    this.aggregatedMetrics = this.loadMetrics();

    // Start aggregation loop if requested
    if (options.autoAggregate) {
      this.startAggregation();
    }
  }

  /**
   * Load metrics from disk
   */
  loadMetrics() {
    try {
      if (fs.existsSync(this.metricsFile)) {
        const data = fs.readFileSync(this.metricsFile, 'utf8');
        return JSON.parse(data);
      }
    } catch (err) {
      console.error(`[Metrics] Error loading metrics: ${err.message}`);
    }

    return { buckets: [] };
  }

  /**
   * Save metrics to disk
   */
  saveMetrics() {
    try {
      const dir = path.dirname(this.metricsFile);
      if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
      }

      fs.writeFileSync(this.metricsFile, JSON.stringify(this.aggregatedMetrics, null, 2));
    } catch (err) {
      console.error(`[Metrics] Error saving metrics: ${err.message}`);
    }
  }

  /**
   * Record a metric value
   *
   * @param {string} metric - Metric name (e.g., 'redis.latency', 'api.errors')
   * @param {number} value - Metric value
   * @param {object} tags - Optional tags for filtering
   */
  record(metric, value, tags = {}) {
    const timestamp = Date.now();

    if (!this.currentMetrics[metric]) {
      this.currentMetrics[metric] = {
        values: [],
        tags
      };
    }

    this.currentMetrics[metric].values.push({
      timestamp,
      value
    });
  }

  /**
   * Increment a counter metric
   */
  increment(metric, amount = 1, tags = {}) {
    const current = this.getCounter(metric) || 0;
    this.record(metric, current + amount, { ...tags, type: 'counter' });
  }

  /**
   * Get current counter value
   */
  getCounter(metric) {
    const latest = this.aggregatedMetrics.buckets
      .filter(b => b.metric === metric)
      .sort((a, b) => b.timestamp - a.timestamp)[0];

    return latest ? latest.sum : 0;
  }

  /**
   * Time an operation and record its duration
   */
  async time(metric, fn, tags = {}) {
    const start = Date.now();

    try {
      const result = await fn();
      const duration = Date.now() - start;

      this.record(metric, duration, { ...tags, type: 'timer' });

      return result;
    } catch (err) {
      const duration = Date.now() - start;

      this.record(metric, duration, { ...tags, type: 'timer', error: true });
      this.increment(`${metric}.errors`, 1, tags);

      throw err;
    }
  }

  /**
   * Aggregate current metrics into buckets
   */
  aggregate() {
    const timestamp = Date.now();
    const newBuckets = [];

    for (const [metric, data] of Object.entries(this.currentMetrics)) {
      if (data.values.length === 0) continue;

      const values = data.values.map(v => v.value);

      const bucket = {
        timestamp,
        metric,
        count: values.length,
        sum: values.reduce((a, b) => a + b, 0),
        min: Math.min(...values),
        max: Math.max(...values),
        avg: values.reduce((a, b) => a + b, 0) / values.length,
        tags: data.tags
      };

      // Calculate percentiles for timers
      if (data.tags.type === 'timer') {
        const sorted = values.sort((a, b) => a - b);
        bucket.p50 = this.percentile(sorted, 50);
        bucket.p95 = this.percentile(sorted, 95);
        bucket.p99 = this.percentile(sorted, 99);
      }

      newBuckets.push(bucket);
    }

    // Add new buckets to aggregated metrics
    this.aggregatedMetrics.buckets.push(...newBuckets);

    // Trim old buckets
    this.trimMetrics();

    // Clear current metrics
    this.currentMetrics = {};

    // Save to disk
    this.saveMetrics();

    return newBuckets;
  }

  /**
   * Calculate percentile from sorted array
   */
  percentile(sorted, p) {
    const index = Math.ceil((p / 100) * sorted.length) - 1;
    return sorted[Math.max(0, index)];
  }

  /**
   * Remove metrics older than retention period
   */
  trimMetrics() {
    const cutoff = Date.now() - (this.retentionHours * 60 * 60 * 1000);

    this.aggregatedMetrics.buckets = this.aggregatedMetrics.buckets.filter(
      bucket => bucket.timestamp > cutoff
    );
  }

  /**
   * Query metrics
   *
   * @param {string} metric - Metric name pattern (supports wildcards)
   * @param {object} options - Query options
   * @returns {array} Matching metric buckets
   */
  query(metric, options = {}) {
    let buckets = this.aggregatedMetrics.buckets;

    // Filter by metric name (support wildcards)
    if (metric) {
      const pattern = new RegExp('^' + metric.replace(/\*/g, '.*') + '$');
      buckets = buckets.filter(b => pattern.test(b.metric));
    }

    // Filter by time range
    if (options.since) {
      buckets = buckets.filter(b => b.timestamp >= options.since);
    }

    if (options.until) {
      buckets = buckets.filter(b => b.timestamp <= options.until);
    }

    // Filter by tags
    if (options.tags) {
      buckets = buckets.filter(b => {
        return Object.entries(options.tags).every(
          ([key, value]) => b.tags[key] === value
        );
      });
    }

    // Limit results
    if (options.limit) {
      buckets = buckets.slice(-options.limit);
    }

    return buckets;
  }

  /**
   * Get summary statistics for a metric
   */
  getSummary(metric, hours = 1) {
    const since = Date.now() - (hours * 60 * 60 * 1000);
    const buckets = this.query(metric, { since });

    if (buckets.length === 0) {
      return null;
    }

    const summary = {
      metric,
      period: `${hours}h`,
      dataPoints: buckets.length,
      totalCount: buckets.reduce((sum, b) => sum + b.count, 0),
      avg: buckets.reduce((sum, b) => sum + (b.avg * b.count), 0) /
           buckets.reduce((sum, b) => sum + b.count, 0),
      min: Math.min(...buckets.map(b => b.min)),
      max: Math.max(...buckets.map(b => b.max)),
      latest: buckets[buckets.length - 1]
    };

    // Add percentiles if available
    const withPercentiles = buckets.filter(b => b.p50 !== undefined);
    if (withPercentiles.length > 0) {
      summary.p50 = Math.round(
        withPercentiles.reduce((sum, b) => sum + b.p50, 0) / withPercentiles.length
      );
      summary.p95 = Math.round(
        withPercentiles.reduce((sum, b) => sum + b.p95, 0) / withPercentiles.length
      );
      summary.p99 = Math.round(
        withPercentiles.reduce((sum, b) => sum + b.p99, 0) / withPercentiles.length
      );
    }

    return summary;
  }

  /**
   * Get all metrics summary
   */
  getAllSummaries(hours = 1) {
    const metrics = [...new Set(this.aggregatedMetrics.buckets.map(b => b.metric))];
    const summaries = {};

    for (const metric of metrics) {
      summaries[metric] = this.getSummary(metric, hours);
    }

    return summaries;
  }

  /**
   * Start automatic aggregation
   */
  startAggregation() {
    if (this.aggregationTimer) {
      return; // Already running
    }

    this.aggregationTimer = setInterval(() => {
      this.aggregate();
    }, this.aggregationInterval);

    console.log(`[Metrics] Auto-aggregation started (interval: ${this.aggregationInterval}ms)`);
  }

  /**
   * Stop automatic aggregation
   */
  stopAggregation() {
    if (this.aggregationTimer) {
      clearInterval(this.aggregationTimer);
      this.aggregationTimer = null;
      console.log('[Metrics] Auto-aggregation stopped');
    }
  }

  /**
   * Export metrics in Prometheus format
   */
  exportPrometheus() {
    const lines = [];

    for (const bucket of this.aggregatedMetrics.buckets) {
      const tags = Object.entries(bucket.tags || {})
        .map(([k, v]) => `${k}="${v}"`)
        .join(',');

      const tagsStr = tags ? `{${tags}}` : '';

      lines.push(`# TYPE ${bucket.metric} summary`);
      lines.push(`${bucket.metric}_count${tagsStr} ${bucket.count}`);
      lines.push(`${bucket.metric}_sum${tagsStr} ${bucket.sum}`);

      if (bucket.p50 !== undefined) {
        lines.push(`${bucket.metric}{quantile="0.5",${tags}} ${bucket.p50}`);
        lines.push(`${bucket.metric}{quantile="0.95",${tags}} ${bucket.p95}`);
        lines.push(`${bucket.metric}{quantile="0.99",${tags}} ${bucket.p99}`);
      }
    }

    return lines.join('\n');
  }

  /**
   * Clear all metrics
   */
  clear() {
    this.currentMetrics = {};
    this.aggregatedMetrics = { buckets: [] };
    this.saveMetrics();
  }
}

module.exports = MetricsCollector;

// CLI Usage
if (require.main === module) {
  const metrics = new MetricsCollector();
  const command = process.argv[2];

  switch (command) {
    case 'summary':
      const metric = process.argv[3] || '*';
      const hours = parseInt(process.argv[4]) || 1;
      console.log(JSON.stringify(metrics.getSummary(metric, hours), null, 2));
      break;

    case 'all':
      const allHours = parseInt(process.argv[3]) || 1;
      console.log(JSON.stringify(metrics.getAllSummaries(allHours), null, 2));
      break;

    case 'export':
      console.log(metrics.exportPrometheus());
      break;

    case 'clear':
      metrics.clear();
      console.log('Metrics cleared');
      break;

    default:
      console.log('Usage: metrics_collector.cjs <summary|all|export|clear> [args]');
      process.exit(1);
  }
}
