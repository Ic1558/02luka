#!/usr/bin/env node
/**
 * Alert Manager with Cooldowns
 * Prevents alert fatigue by rate-limiting notifications
 */

const fs = require('fs');
const path = require('path');

const STATE_FILE = path.join(
  process.env.HOME,
  'Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My Drive/02luka/02luka-repo',
  'g/state/alert_state.json'
);

const ALERT_LEVELS = {
  CRITICAL: {
    threshold: 3,        // Alert after 3 consecutive failures
    cooldown: 3600000,   // 1 hour cooldown
    channels: ['discord', 'log']
  },
  WARNING: {
    threshold: 5,
    cooldown: 7200000,   // 2 hours
    channels: ['log']
  },
  INFO: {
    threshold: 10,
    cooldown: 86400000,  // 24 hours
    channels: ['log']
  }
};

class AlertManager {
  constructor() {
    this.state = this.loadState();
  }

  loadState() {
    try {
      if (fs.existsSync(STATE_FILE)) {
        return JSON.parse(fs.readFileSync(STATE_FILE, 'utf8'));
      }
    } catch (err) {
      // Ignore
    }
    return {};
  }

  saveState() {
    try {
      const dir = path.dirname(STATE_FILE);
      if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
      }
      fs.writeFileSync(STATE_FILE, JSON.stringify(this.state, null, 2));
    } catch (err) {
      console.error(`Alert state save failed: ${err.message}`);
    }
  }

  shouldAlert(alertKey, level = 'WARNING', consecutiveFailures = 1) {
    const config = ALERT_LEVELS[level];
    if (!config) {
      console.error(`Unknown alert level: ${level}`);
      return false;
    }

    // Check threshold
    if (consecutiveFailures < config.threshold) {
      return false;
    }

    // Check cooldown
    const alert = this.state[alertKey] || {};
    const now = Date.now();
    
    if (alert.lastSent && (now - alert.lastSent) < config.cooldown) {
      const remaining = Math.ceil((config.cooldown - (now - alert.lastSent)) / 60000);
      console.log(`Alert cooldown active for ${alertKey}: ${remaining} minutes remaining`);
      return false;
    }

    return true;
  }

  markAlertSent(alertKey, level = 'WARNING') {
    const alert = this.state[alertKey] || {};
    alert.lastSent = Date.now();
    alert.level = level;
    alert.count = (alert.count || 0) + 1;
    this.state[alertKey] = alert;
    this.saveState();
  }

  getAlertChannels(level = 'WARNING') {
    const config = ALERT_LEVELS[level];
    return config ? config.channels : ['log'];
  }

  getAlertState(alertKey) {
    return this.state[alertKey] || null;
  }

  resetAlert(alertKey) {
    delete this.state[alertKey];
    this.saveState();
  }
}

module.exports = AlertManager;
