#!/usr/bin/env node
/**
 * Health Dashboard Aggregator
 *
 * Combines health history, metrics, and circuit breaker status
 * to provide comprehensive system health overview
 *
 * Phase 3 - Observability
 */

const fs = require('fs');
const path = require('path');
const HealthHistory = require('./lib/health_history.cjs');
const MetricsCollector = require('./lib/metrics_collector.cjs');

class HealthDashboard {
  constructor() {
    this.history = new HealthHistory();
    this.metrics = new MetricsCollector();
  }

  /**
   * Get overall system health score (0-100)
   *
   * Factors:
   * - Service uptime (40%)
   * - Response times (30%)
   * - Error rates (20%)
   * - Circuit breaker state (10%)
   */
  getSystemHealthScore() {
    const services = ['redis', 'api', 'mcp', 'health_proxy'];
    const scores = {
      uptime: this.calculateUptimeScore(services),
      latency: this.calculateLatencyScore(services),
      errors: this.calculateErrorScore(services),
      circuits: this.calculateCircuitScore()
    };

    const weights = {
      uptime: 0.4,
      latency: 0.3,
      errors: 0.2,
      circuits: 0.1
    };

    let totalScore = 0;
    let totalWeight = 0;

    for (const [component, score] of Object.entries(scores)) {
      if (score !== null) {
        totalScore += score * weights[component];
        totalWeight += weights[component];
      }
    }

    const finalScore = totalWeight > 0 ? totalScore / totalWeight : 0;

    return {
      overall: Math.round(finalScore),
      breakdown: scores,
      weights
    };
  }

  /**
   * Calculate uptime component score
   */
  calculateUptimeScore(services) {
    const uptimes = services
      .map(svc => this.history.getUptime(svc, 1))
      .filter(u => u !== null);

    if (uptimes.length === 0) return null;

    const avgUptime = uptimes.reduce((sum, u) => sum + u, 0) / uptimes.length;
    return Math.round(avgUptime);
  }

  /**
   * Calculate latency component score
   */
  calculateLatencyScore(services) {
    const latencies = [];

    for (const service of services) {
      const summary = this.metrics.getSummary(`${service}.latency`, 1);
      if (summary && summary.avg !== null) {
        latencies.push(summary.avg);
      }
    }

    if (latencies.length === 0) return null;

    const avgLatency = latencies.reduce((sum, l) => sum + l, 0) / latencies.length;

    // Score based on latency thresholds
    if (avgLatency < 50) return 100;
    if (avgLatency < 100) return 90;
    if (avgLatency < 200) return 75;
    if (avgLatency < 500) return 50;
    if (avgLatency < 1000) return 25;
    return 0;
  }

  /**
   * Calculate error rate component score
   */
  calculateErrorScore(services) {
    let totalRequests = 0;
    let totalErrors = 0;

    for (const service of services) {
      const requests = this.metrics.getSummary(`${service}.requests`, 1);
      const errors = this.metrics.getSummary(`${service}.errors`, 1);

      if (requests) totalRequests += requests.totalCount;
      if (errors) totalErrors += errors.totalCount;
    }

    if (totalRequests === 0) return null;

    const errorRate = (totalErrors / totalRequests) * 100;

    // Score based on error rate
    if (errorRate < 0.1) return 100;
    if (errorRate < 1) return 90;
    if (errorRate < 5) return 70;
    if (errorRate < 10) return 40;
    return 0;
  }

  /**
   * Calculate circuit breaker health score
   */
  calculateCircuitScore() {
    try {
      const stateFile = 'g/state/circuit_breakers.json';
      if (!fs.existsSync(stateFile)) return null;

      const data = JSON.parse(fs.readFileSync(stateFile, 'utf8'));
      const circuits = Object.values(data);

      if (circuits.length === 0) return null;

      const closedCount = circuits.filter(c => c.state === 'CLOSED').length;
      const halfOpenCount = circuits.filter(c => c.state === 'HALF_OPEN').length;
      const openCount = circuits.filter(c => c.state === 'OPEN').length;

      // Perfect score if all closed
      if (openCount === 0 && halfOpenCount === 0) return 100;

      // Partial score based on open/half-open ratio
      const healthyRatio = (closedCount + (halfOpenCount * 0.5)) / circuits.length;
      return Math.round(healthyRatio * 100);
    } catch (err) {
      return null;
    }
  }

  /**
   * Get comprehensive dashboard data
   */
  getDashboard() {
    const services = ['redis', 'api', 'mcp', 'health_proxy', 'boss_api'];
    const dashboard = {
      timestamp: new Date().toISOString(),
      systemScore: this.getSystemHealthScore(),
      services: {},
      patterns: {},
      alerts: this.getRecentAlerts(),
      metrics: this.metrics.getAllSummaries(1)
    };

    // Per-service health details
    for (const service of services) {
      const uptime = this.history.getUptime(service, 24);
      const score = this.history.getHealthScore(service, 1);
      const patterns = this.history.detectPatterns(service, 1);
      const latencySummary = this.metrics.getSummary(`${service}.latency`, 1);

      dashboard.services[service] = {
        uptime24h: uptime,
        healthScore: score,
        avgLatency: latencySummary ? Math.round(latencySummary.avg) : null,
        p95Latency: latencySummary ? latencySummary.p95 : null,
        patterns: {
          flapping: patterns.flapping || false,
          degradation: patterns.degradation || false,
          recovery: patterns.recovery || false
        }
      };

      // Collect patterns
      if (patterns.flapping) {
        dashboard.patterns[service] = dashboard.patterns[service] || [];
        dashboard.patterns[service].push('flapping');
      }
      if (patterns.degradation) {
        dashboard.patterns[service] = dashboard.patterns[service] || [];
        dashboard.patterns[service].push('degradation');
      }
      if (patterns.recovery) {
        dashboard.patterns[service] = dashboard.patterns[service] || [];
        dashboard.patterns[service].push('recovery');
      }
    }

    return dashboard;
  }

  /**
   * Get recent alerts from alert manager
   */
  getRecentAlerts() {
    try {
      const alertFile = 'g/state/alert_state.json';
      if (!fs.existsSync(alertFile)) return [];

      const data = JSON.parse(fs.readFileSync(alertFile, 'utf8'));
      const alerts = [];

      for (const [key, state] of Object.entries(data)) {
        if (state.lastSent && Date.now() - state.lastSent < 3600000) { // Last hour
          alerts.push({
            key,
            level: state.level,
            count: state.count,
            lastSent: new Date(state.lastSent).toISOString()
          });
        }
      }

      return alerts.sort((a, b) => b.lastSent.localeCompare(a.lastSent));
    } catch (err) {
      return [];
    }
  }

  /**
   * Get historical trends
   */
  getTrends(service, hours = 24) {
    const history = this.history.getHistory(service, {
      since: Date.now() - (hours * 60 * 60 * 1000)
    });

    // Group by hour
    const hourlyBuckets = {};

    for (const entry of history) {
      const hour = Math.floor(entry.timestamp / 3600000) * 3600000;

      if (!hourlyBuckets[hour]) {
        hourlyBuckets[hour] = {
          timestamp: hour,
          total: 0,
          successes: 0,
          failures: 0,
          latencies: []
        };
      }

      hourlyBuckets[hour].total++;

      if (entry.ok) {
        hourlyBuckets[hour].successes++;
        if (entry.latency) hourlyBuckets[hour].latencies.push(entry.latency);
      } else {
        hourlyBuckets[hour].failures++;
      }
    }

    // Calculate metrics for each bucket
    const trends = Object.values(hourlyBuckets).map(bucket => {
      const uptime = (bucket.successes / bucket.total) * 100;
      const avgLatency = bucket.latencies.length > 0
        ? bucket.latencies.reduce((sum, l) => sum + l, 0) / bucket.latencies.length
        : null;

      return {
        timestamp: new Date(bucket.timestamp).toISOString(),
        uptime: Math.round(uptime * 100) / 100,
        avgLatency: avgLatency ? Math.round(avgLatency) : null,
        totalChecks: bucket.total
      };
    });

    return trends.sort((a, b) => a.timestamp.localeCompare(b.timestamp));
  }

  /**
   * Export dashboard data to file
   */
  export(outputFile = 'g/reports/health_dashboard.json') {
    const dashboard = this.getDashboard();

    const dir = path.dirname(outputFile);
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }

    fs.writeFileSync(outputFile, JSON.stringify(dashboard, null, 2));

    console.log(`Dashboard exported to ${outputFile}`);

    return dashboard;
  }

  /**
   * Generate text summary
   */
  getTextSummary() {
    const dashboard = this.getDashboard();
    const lines = [];

    lines.push('=== System Health Dashboard ===');
    lines.push(`Updated: ${dashboard.timestamp}`);
    lines.push('');

    lines.push(`Overall Health Score: ${dashboard.systemScore.overall}/100`);
    lines.push(`  - Uptime: ${dashboard.systemScore.breakdown.uptime || 'N/A'}/100`);
    lines.push(`  - Latency: ${dashboard.systemScore.breakdown.latency || 'N/A'}/100`);
    lines.push(`  - Errors: ${dashboard.systemScore.breakdown.errors || 'N/A'}/100`);
    lines.push(`  - Circuits: ${dashboard.systemScore.breakdown.circuits || 'N/A'}/100`);
    lines.push('');

    lines.push('Services:');
    for (const [service, data] of Object.entries(dashboard.services)) {
      const status = data.uptime24h !== null && data.uptime24h >= 99 ? '✅' :
                     data.uptime24h !== null && data.uptime24h >= 90 ? '⚠️' : '❌';

      lines.push(`  ${status} ${service}`);
      lines.push(`     Uptime (24h): ${data.uptime24h !== null ? data.uptime24h + '%' : 'N/A'}`);
      lines.push(`     Health Score: ${data.healthScore !== null ? data.healthScore + '/100' : 'N/A'}`);
      lines.push(`     Avg Latency: ${data.avgLatency !== null ? data.avgLatency + 'ms' : 'N/A'}`);

      if (data.patterns.flapping) lines.push(`     ⚠️ FLAPPING detected`);
      if (data.patterns.degradation) lines.push(`     ⚠️ DEGRADATION detected`);
      if (data.patterns.recovery) lines.push(`     ✅ RECOVERY detected`);
    }

    if (dashboard.alerts.length > 0) {
      lines.push('');
      lines.push('Recent Alerts (last hour):');
      for (const alert of dashboard.alerts) {
        lines.push(`  - [${alert.level}] ${alert.key} (count: ${alert.count})`);
      }
    }

    return lines.join('\n');
  }
}

module.exports = HealthDashboard;

// CLI Usage
if (require.main === module) {
  const dashboard = new HealthDashboard();
  const command = process.argv[2];

  switch (command) {
    case 'show':
      console.log(dashboard.getTextSummary());
      break;

    case 'score':
      const score = dashboard.getSystemHealthScore();
      console.log(JSON.stringify(score, null, 2));
      break;

    case 'export':
      const file = process.argv[3] || 'g/reports/health_dashboard.json';
      dashboard.export(file);
      break;

    case 'trends':
      const service = process.argv[3];
      const hours = parseInt(process.argv[4]) || 24;
      if (!service) {
        console.error('Usage: health_dashboard.cjs trends <service> [hours]');
        process.exit(1);
      }
      console.log(JSON.stringify(dashboard.getTrends(service, hours), null, 2));
      break;

    default:
      console.log('Usage: health_dashboard.cjs <show|score|export|trends> [args]');
      console.log('');
      console.log('Commands:');
      console.log('  show              - Display text dashboard');
      console.log('  score             - Show health scores');
      console.log('  export [file]     - Export dashboard JSON');
      console.log('  trends <svc> [h]  - Show hourly trends');
      process.exit(1);
  }
}
