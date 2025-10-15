#!/usr/bin/env node

/**
 * Reportbot Agent - Alert Notifications for WARN/FAIL
 * 
 * This agent monitors system status and sends alert notifications
 * for WARN and FAIL conditions detected in the 02LUKA system.
 */

const fs = require('fs').promises;
const path = require('path');
const { exec } = require('child_process');
const { promisify } = require('util');

const execAsync = promisify(exec);

// Configuration
const REPO_ROOT = path.resolve(__dirname, '../..');
const BOSS_ROOT = path.join(REPO_ROOT, 'boss');
const REPORTS_DIR = path.join(BOSS_ROOT, 'reports');
const ALERTS_DIR = path.join(BOSS_ROOT, 'alerts');

// Alert levels
const ALERT_LEVELS = {
  INFO: 'info',
  WARN: 'warn', 
  FAIL: 'fail',
  CRITICAL: 'critical'
};

// Alert notification methods
class AlertNotifier {
  constructor() {
    this.alertHistory = [];
    this.maxHistorySize = 100;
  }

  /**
   * Send alert notification
   * @param {string} level - Alert level (WARN, FAIL, etc.)
   * @param {string} message - Alert message
   * @param {Object} context - Additional context data
   */
  async notify(level, message, context = {}) {
    const alert = {
      timestamp: new Date().toISOString(),
      level: level.toUpperCase(),
      message,
      context,
      id: this.generateAlertId()
    };

    // Add to history
    this.alertHistory.unshift(alert);
    if (this.alertHistory.length > this.maxHistorySize) {
      this.alertHistory = this.alertHistory.slice(0, this.maxHistorySize);
    }

    // Log alert
    console.log(`[${alert.level}] ${alert.timestamp}: ${message}`);
    if (Object.keys(context).length > 0) {
      console.log('Context:', JSON.stringify(context, null, 2));
    }

    // Save to alerts directory
    await this.saveAlert(alert);

    // Send to external systems if configured
    await this.sendExternalAlert(alert);

    return alert;
  }

  /**
   * Generate unique alert ID
   */
  generateAlertId() {
    return `alert_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  /**
   * Save alert to file system
   */
  async saveAlert(alert) {
    try {
      await fs.mkdir(ALERTS_DIR, { recursive: true });
      const alertFile = path.join(ALERTS_DIR, `${alert.id}.json`);
      await fs.writeFile(alertFile, JSON.stringify(alert, null, 2));
    } catch (error) {
      console.error('Failed to save alert:', error.message);
    }
  }

  /**
   * Send alert to external systems (webhooks, Slack, etc.)
   */
  async sendExternalAlert(alert) {
    // Check for webhook configuration
    const webhookUrl = process.env.ALERT_WEBHOOK_URL;
    if (webhookUrl && (alert.level === 'FAIL' || alert.level === 'CRITICAL')) {
      try {
        const fetch = (await import('node-fetch')).default;
        await fetch(webhookUrl, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            text: `🚨 ${alert.level}: ${alert.message}`,
            timestamp: alert.timestamp,
            context: alert.context
          })
        });
        console.log(`Alert sent to webhook: ${alert.id}`);
      } catch (error) {
        console.error('Failed to send webhook alert:', error.message);
      }
    }
  }

  /**
   * Get recent alerts
   */
  getRecentAlerts(limit = 10) {
    return this.alertHistory.slice(0, limit);
  }
}

// System monitoring functions
class SystemMonitor {
  constructor(notifier) {
    this.notifier = notifier;
  }

  /**
   * Check smoke test results
   */
  async checkSmokeTests() {
    try {
      const { stdout } = await execAsync('bash ./run/smoke_api_ui.sh', { 
        cwd: REPO_ROOT,
        timeout: 30000 
      });
      
      // Parse smoke test output for WARN/FAIL
      const lines = stdout.split('\n');
      let hasWarnings = false;
      let hasFailures = false;
      
      for (const line of lines) {
        if (line.includes('❌ FAIL')) {
          hasFailures = true;
          await this.notifier.notify(ALERT_LEVELS.FAIL, 
            'Smoke test failure detected', 
            { line: line.trim() }
          );
        } else if (line.includes('⚠️  WARN')) {
          hasWarnings = true;
          await this.notifier.notify(ALERT_LEVELS.WARN, 
            'Smoke test warning detected', 
            { line: line.trim() }
          );
        }
      }
      
      if (!hasFailures && !hasWarnings) {
        await this.notifier.notify(ALERT_LEVELS.INFO, 
          'All smoke tests passed', 
          { testOutput: stdout }
        );
      }
      
    } catch (error) {
      await this.notifier.notify(ALERT_LEVELS.FAIL, 
        'Smoke test execution failed', 
        { error: error.message }
      );
    }
  }

  /**
   * Check service health
   */
  async checkServiceHealth() {
    const services = [
      { name: 'API', url: 'http://127.0.0.1:4000/api/capabilities' },
      { name: 'UI', url: 'http://127.0.0.1:5173' },
      { name: 'MCP FS', url: 'http://127.0.0.1:8765/health' }
    ];

    for (const service of services) {
      try {
        const fetch = (await import('node-fetch')).default;
        const response = await fetch(service.url, { 
          method: 'GET',
          timeout: 5000 
        });
        
        if (!response.ok) {
          await this.notifier.notify(ALERT_LEVELS.WARN, 
            `Service ${service.name} returned ${response.status}`, 
            { url: service.url, status: response.status }
          );
        }
      } catch (error) {
        await this.notifier.notify(ALERT_LEVELS.FAIL, 
          `Service ${service.name} is unreachable`, 
          { url: service.url, error: error.message }
        );
      }
    }
  }
}

// Main execution
async function main() {
  console.log('🤖 Reportbot Agent starting...');
  
  const notifier = new AlertNotifier();
  const monitor = new SystemMonitor(notifier);
  
  try {
    // Run system checks
    await monitor.checkServiceHealth();
    await monitor.checkSmokeTests();
    
    // Show recent alerts
    const recentAlerts = notifier.getRecentAlerts(5);
    if (recentAlerts.length > 0) {
      console.log('\n📊 Recent alerts:');
      recentAlerts.forEach(alert => {
        console.log(`  [${alert.level}] ${alert.message}`);
      });
    }
    
    console.log('\n✅ Reportbot Agent completed successfully');
    
  } catch (error) {
    await notifier.notify(ALERT_LEVELS.CRITICAL, 
      'Reportbot Agent execution failed', 
      { error: error.message, stack: error.stack }
    );
    console.error('❌ Reportbot Agent failed:', error.message);
    process.exit(1);
  }
}

// Run if called directly
if (require.main === module) {
  main().catch(console.error);
}

module.exports = { AlertNotifier, SystemMonitor, ALERT_LEVELS };
