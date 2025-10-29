#!/usr/bin/env node
/**
 * Dashboard Updater
 *
 * Runs periodically to update dashboard JSON
 * Phase 3 - Observability
 */

const HealthDashboard = require('./health_dashboard.cjs');

const dashboard = new HealthDashboard();

console.log('[Dashboard] Updating dashboard...');

try {
  const data = dashboard.export('g/reports/health_dashboard.json');

  console.log(`[Dashboard] System Health Score: ${data.systemScore.overall}/100`);
  console.log(`[Dashboard] Services tracked: ${Object.keys(data.services).length}`);
  console.log(`[Dashboard] Alerts (last hour): ${data.alerts.length}`);

  // Also save text summary
  const textSummary = dashboard.getTextSummary();
  require('fs').writeFileSync('g/reports/health_dashboard.txt', textSummary);

  console.log('[Dashboard] Update complete');
  process.exit(0);
} catch (err) {
  console.error(`[Dashboard] Error: ${err.message}`);
  process.exit(1);
}
