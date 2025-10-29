#!/usr/bin/env node
/**
 * Auto-Healing Service
 * Attempts to restart failed services automatically
 */

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const REPO_ROOT = process.env.HOME + '/Library/CloudStorage/GoogleDrive-ittipong.c@gmail.com/My Drive/02luka/02luka-repo';
const STATE_FILE = path.join(REPO_ROOT, 'g/state/auto_heal_state.json');
const LOG_FILE = path.join(REPO_ROOT, 'g/logs/auto_heal.log');

const SERVICES = {
  'health.proxy.stub': {
    name: 'Health Proxy',
    plist: 'com.02luka.health.proxy.stub',
    port: 3002,
    critical: true
  },
  'mcp.bridge.stub': {
    name: 'MCP Bridge',
    plist: 'com.02luka.mcp.bridge.stub',
    port: 3003,
    critical: false
  },
  'boss.api.stub': {
    name: 'Boss API',
    plist: 'com.02luka.boss.api.stub',
    port: 4000,
    critical: true
  }
};

const HEAL_COOLDOWN = 300000; // 5 minutes between heal attempts
const MAX_HEALS_PER_HOUR = 3;

class AutoHealer {
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
      this.log(`Failed to save state: ${err.message}`, 'ERROR');
    }
  }

  log(message, level = 'INFO') {
    const timestamp = new Date().toISOString();
    const logLine = `${timestamp} [${level}] ${message}\n`;
    
    try {
      const dir = path.dirname(LOG_FILE);
      if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
      }
      fs.appendFileSync(LOG_FILE, logLine);
    } catch (err) {
      console.error(`Log write failed: ${err.message}`);
    }
    
    console.log(logLine.trim());
  }

  canHeal(serviceKey) {
    const now = Date.now();
    const svc = this.state[serviceKey] || { lastHeal: 0, healsInLastHour: [] };
    
    // Check cooldown
    if (now - svc.lastHeal < HEAL_COOLDOWN) {
      const remaining = Math.ceil((HEAL_COOLDOWN - (now - svc.lastHeal)) / 1000);
      this.log(`${serviceKey}: Cooldown active (${remaining}s remaining)`, 'WARN');
      return false;
    }
    
    // Check hourly limit
    const oneHourAgo = now - 3600000;
    svc.healsInLastHour = (svc.healsInLastHour || []).filter(t => t > oneHourAgo);
    
    if (svc.healsInLastHour.length >= MAX_HEALS_PER_HOUR) {
      this.log(`${serviceKey}: Max heals per hour reached (${MAX_HEALS_PER_HOUR})`, 'ERROR');
      return false;
    }
    
    return true;
  }

  async healService(serviceKey) {
    const service = SERVICES[serviceKey];
    if (!service) {
      this.log(`Unknown service: ${serviceKey}`, 'ERROR');
      return false;
    }

    if (!this.canHeal(serviceKey)) {
      return false;
    }

    this.log(`Attempting to heal: ${service.name}`, 'INFO');

    try {
      // Unload the LaunchAgent
      try {
        execSync(`launchctl unload ~/Library/LaunchAgents/${service.plist}.plist`, 
                 { stdio: 'pipe' });
        this.log(`  Unloaded ${service.plist}`, 'INFO');
      } catch (err) {
        // May already be unloaded
      }

      // Wait a moment
      await new Promise(resolve => setTimeout(resolve, 2000));

      // Load the LaunchAgent
      execSync(`launchctl load ~/Library/LaunchAgents/${service.plist}.plist`, 
               { stdio: 'pipe' });
      this.log(`  Loaded ${service.plist}`, 'INFO');

      // Wait for service to start
      await new Promise(resolve => setTimeout(resolve, 3000));

      // Verify it's up
      const isUp = this.checkPort(service.port);
      
      if (isUp) {
        this.log(`✅ ${service.name} healed successfully`, 'INFO');
        
        // Update state
        const svc = this.state[serviceKey] || { healsInLastHour: [] };
        svc.lastHeal = Date.now();
        svc.healsInLastHour.push(Date.now());
        svc.lastSuccess = Date.now();
        this.state[serviceKey] = svc;
        this.saveState();
        
        return true;
      } else {
        this.log(`❌ ${service.name} heal failed (port ${service.port} still down)`, 'ERROR');
        return false;
      }
      
    } catch (err) {
      this.log(`❌ ${service.name} heal error: ${err.message}`, 'ERROR');
      return false;
    }
  }

  checkPort(port) {
    try {
      execSync(`nc -z 127.0.0.1 ${port}`, { stdio: 'pipe', timeout: 2000 });
      return true;
    } catch (err) {
      return false;
    }
  }

  async healAllDown() {
    this.log('=== Auto-Heal Scan Starting ===', 'INFO');
    
    const results = [];
    for (const [key, service] of Object.entries(SERVICES)) {
      const isUp = this.checkPort(service.port);
      
      if (!isUp) {
        this.log(`${service.name} (port ${service.port}): DOWN`, 'WARN');
        const healed = await this.healService(key);
        results.push({ service: service.name, healed });
      } else {
        this.log(`${service.name} (port ${service.port}): UP`, 'INFO');
        results.push({ service: service.name, healed: null });
      }
    }
    
    this.log('=== Auto-Heal Scan Complete ===', 'INFO');
    return results;
  }
}

// Main execution
if (require.main === module) {
  const healer = new AutoHealer();
  healer.healAllDown()
    .then(results => {
      const healed = results.filter(r => r.healed === true).length;
      const failed = results.filter(r => r.healed === false).length;
      console.log(`\nSummary: ${healed} healed, ${failed} failed`);
      process.exit(failed > 0 ? 1 : 0);
    })
    .catch(err => {
      console.error(`Fatal error: ${err.message}`);
      process.exit(1);
    });
}

module.exports = AutoHealer;
