#!/usr/bin/env node
/**
 * Health History Tracker
 *
 * Tracks health check results over time with 24h rolling window
 * Provides historical analysis and pattern detection
 *
 * Phase 3 - Observability
 */

const fs = require('fs');
const path = require('path');

class HealthHistory {
  constructor(options = {}) {
    this.stateFile = options.stateFile || 'g/state/health_history.json';
    this.retentionHours = options.retentionHours || 24;
    this.maxEntriesPerService = options.maxEntriesPerService || 1000;

    this.history = this.loadState();
  }

  /**
   * Load historical state from disk
   */
  loadState() {
    try {
      if (fs.existsSync(this.stateFile)) {
        const data = fs.readFileSync(this.stateFile, 'utf8');
        return JSON.parse(data);
      }
    } catch (err) {
      console.error(`[HealthHistory] Error loading state: ${err.message}`);
    }

    return {};
  }

  /**
   * Save state to disk
   */
  saveState() {
    try {
      const dir = path.dirname(this.stateFile);
      if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
      }

      fs.writeFileSync(this.stateFile, JSON.stringify(this.history, null, 2));
    } catch (err) {
      console.error(`[HealthHistory] Error saving state: ${err.message}`);
    }
  }

  /**
   * Record a health check result
   *
   * @param {string} service - Service name (e.g., 'redis', 'api', 'mcp')
   * @param {object} result - Health check result
   * @param {boolean} result.ok - Whether check passed
   * @param {number} result.latency - Response time in ms
   * @param {string} result.error - Error message if failed
   */
  record(service, result) {
    if (!this.history[service]) {
      this.history[service] = [];
    }

    const entry = {
      timestamp: Date.now(),
      ok: result.ok,
      latency: result.latency || null,
      error: result.error || null
    };

    this.history[service].push(entry);

    // Trim old entries (beyond retention period)
    this.trimHistory(service);

    // Enforce max entries limit
    if (this.history[service].length > this.maxEntriesPerService) {
      this.history[service] = this.history[service].slice(-this.maxEntriesPerService);
    }

    this.saveState();
  }

  /**
   * Remove entries older than retention period
   */
  trimHistory(service) {
    const cutoff = Date.now() - (this.retentionHours * 60 * 60 * 1000);

    if (this.history[service]) {
      this.history[service] = this.history[service].filter(
        entry => entry.timestamp > cutoff
      );
    }
  }

  /**
   * Get history for a service
   */
  getHistory(service, options = {}) {
    if (!this.history[service]) {
      return [];
    }

    let entries = [...this.history[service]];

    // Filter by time range if specified
    if (options.since) {
      entries = entries.filter(e => e.timestamp >= options.since);
    }

    if (options.until) {
      entries = entries.filter(e => e.timestamp <= options.until);
    }

    // Limit number of results
    if (options.limit) {
      entries = entries.slice(-options.limit);
    }

    return entries;
  }

  /**
   * Calculate uptime percentage for a service
   *
   * @param {string} service - Service name
   * @param {number} hours - Hours to look back (default: 24)
   * @returns {number} Uptime percentage (0-100)
   */
  getUptime(service, hours = 24) {
    const since = Date.now() - (hours * 60 * 60 * 1000);
    const entries = this.getHistory(service, { since });

    if (entries.length === 0) {
      return null; // No data
    }

    const successCount = entries.filter(e => e.ok).length;
    return Math.round((successCount / entries.length) * 100 * 100) / 100;
  }

  /**
   * Calculate average latency for a service
   */
  getAverageLatency(service, hours = 24) {
    const since = Date.now() - (hours * 60 * 60 * 1000);
    const entries = this.getHistory(service, { since });

    const validLatencies = entries
      .filter(e => e.ok && e.latency !== null)
      .map(e => e.latency);

    if (validLatencies.length === 0) {
      return null;
    }

    const sum = validLatencies.reduce((acc, val) => acc + val, 0);
    return Math.round(sum / validLatencies.length);
  }

  /**
   * Get current health status summary for all services
   */
  getSummary(hours = 24) {
    const summary = {};

    for (const service of Object.keys(this.history)) {
      const uptime = this.getUptime(service, hours);
      const avgLatency = this.getAverageLatency(service, hours);
      const recent = this.getHistory(service, { limit: 10 });
      const current = recent.length > 0 ? recent[recent.length - 1] : null;

      summary[service] = {
        uptime,
        avgLatency,
        currentStatus: current ? (current.ok ? 'UP' : 'DOWN') : 'UNKNOWN',
        lastCheck: current ? new Date(current.timestamp).toISOString() : null,
        checkCount: this.history[service].length
      };
    }

    return summary;
  }

  /**
   * Detect patterns in health history
   *
   * @returns {object} Detected patterns (flapping, degradation, etc.)
   */
  detectPatterns(service, hours = 1) {
    const since = Date.now() - (hours * 60 * 60 * 1000);
    const entries = this.getHistory(service, { since });

    if (entries.length < 5) {
      return { detected: false, reason: 'insufficient_data' };
    }

    const patterns = {
      flapping: this.detectFlapping(entries),
      degradation: this.detectDegradation(entries),
      recovery: this.detectRecovery(entries)
    };

    return patterns;
  }

  /**
   * Detect service flapping (rapid state changes)
   */
  detectFlapping(entries) {
    if (entries.length < 10) return false;

    let stateChanges = 0;
    for (let i = 1; i < entries.length; i++) {
      if (entries[i].ok !== entries[i - 1].ok) {
        stateChanges++;
      }
    }

    // If more than 40% of checks resulted in state change
    return (stateChanges / entries.length) > 0.4;
  }

  /**
   * Detect performance degradation (latency increase)
   */
  detectDegradation(entries) {
    const validEntries = entries.filter(e => e.ok && e.latency !== null);

    if (validEntries.length < 10) return false;

    const midpoint = Math.floor(validEntries.length / 2);
    const firstHalf = validEntries.slice(0, midpoint);
    const secondHalf = validEntries.slice(midpoint);

    const avgFirst = firstHalf.reduce((sum, e) => sum + e.latency, 0) / firstHalf.length;
    const avgSecond = secondHalf.reduce((sum, e) => sum + e.latency, 0) / secondHalf.length;

    // If latency increased by more than 50%
    return avgSecond > (avgFirst * 1.5);
  }

  /**
   * Detect service recovery (consecutive successes after failures)
   */
  detectRecovery(entries) {
    if (entries.length < 5) return false;

    const recent = entries.slice(-5);
    const hasFailure = recent.some(e => !e.ok);
    const allRecentSuccess = recent.slice(-3).every(e => e.ok);

    return hasFailure && allRecentSuccess;
  }

  /**
   * Get health score (0-100) based on recent history
   */
  getHealthScore(service, hours = 1) {
    const entries = this.getHistory(service, {
      since: Date.now() - (hours * 60 * 60 * 1000)
    });

    if (entries.length === 0) {
      return null;
    }

    // Base score from uptime
    const uptime = this.getUptime(service, hours);
    let score = uptime;

    // Penalty for flapping
    const patterns = this.detectPatterns(service, hours);
    if (patterns.flapping) {
      score -= 20;
    }

    // Penalty for degradation
    if (patterns.degradation) {
      score -= 15;
    }

    // Bonus for recovery
    if (patterns.recovery) {
      score += 5;
    }

    // Ensure score is in 0-100 range
    return Math.max(0, Math.min(100, Math.round(score)));
  }

  /**
   * Clear history for a service or all services
   */
  clear(service = null) {
    if (service) {
      delete this.history[service];
    } else {
      this.history = {};
    }
    this.saveState();
  }
}

module.exports = HealthHistory;

// CLI Usage
if (require.main === module) {
  const history = new HealthHistory();
  const command = process.argv[2];

  switch (command) {
    case 'summary':
      console.log(JSON.stringify(history.getSummary(), null, 2));
      break;

    case 'uptime':
      const service = process.argv[3];
      const hours = parseInt(process.argv[4]) || 24;
      if (!service) {
        console.error('Usage: health_history.cjs uptime <service> [hours]');
        process.exit(1);
      }
      console.log(`${service} uptime (${hours}h): ${history.getUptime(service, hours)}%`);
      break;

    case 'score':
      const scoreSvc = process.argv[3];
      if (!scoreSvc) {
        console.error('Usage: health_history.cjs score <service>');
        process.exit(1);
      }
      console.log(`${scoreSvc} health score: ${history.getHealthScore(scoreSvc)}/100`);
      break;

    default:
      console.log('Usage: health_history.cjs <summary|uptime|score> [args]');
      process.exit(1);
  }
}
