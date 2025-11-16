#!/usr/bin/env node
/**
 * Agent Heartbeat Map & Auto-Alert
 *
 * Collects Redis pub/sub heartbeats from agents (Mary/Lisa/Paula/Hybrid)
 * and monitors their status. Sends Telegram alerts if agent is offline > 300s.
 *
 * Channels:
 * - agents:heartbeat:mary
 * - agents:heartbeat:lisa
 * - agents:heartbeat:paula
 * - agents:heartbeat:hybrid
 *
 * Output:
 * - hub/agent_heartbeat.json (agent status map)
 * - Telegram alerts for offline agents
 *
 * Dispatch: agent:heartbeat
 */

import { createClient } from 'redis';
import { writeFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import https from 'https';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Configuration
const CONFIG = {
  redisUrl: process.env.LUKA_REDIS_URL || 'redis://127.0.0.1:6379',
  telegramBotToken: process.env.TELEGRAM_BOT_TOKEN,
  telegramChatId: process.env.TELEGRAM_CHAT_ID,
  offlineThreshold: 300, // seconds (5 minutes)
  checkInterval: 60000, // 1 minute
  outputFile: join(__dirname, 'agent_heartbeat.json'),

  agents: [
    { id: 'mary', name: 'Mary', channel: 'agents:heartbeat:mary' },
    { id: 'lisa', name: 'Lisa', channel: 'agents:heartbeat:lisa' },
    { id: 'paula', name: 'Paula', channel: 'agents:heartbeat:paula' },
    { id: 'hybrid', name: 'Hybrid', channel: 'agents:heartbeat:hybrid' },
  ],
};

// Agent state tracking
const agentState = new Map();

// Initialize agent states
CONFIG.agents.forEach(agent => {
  agentState.set(agent.id, {
    id: agent.id,
    name: agent.name,
    channel: agent.channel,
    status: 'unknown',
    last_heartbeat: null,
    seconds_since_heartbeat: null,
    last_alert_sent: null,
    metadata: {},
  });
});

/**
 * Send Telegram notification
 */
async function sendTelegramAlert(message) {
  if (!CONFIG.telegramBotToken || !CONFIG.telegramChatId) {
    console.warn('[WARN] Telegram credentials not configured, skipping alert');
    return false;
  }

  const payload = JSON.stringify({
    chat_id: CONFIG.telegramChatId,
    text: message,
    parse_mode: 'Markdown',
  });

  const options = {
    hostname: 'api.telegram.org',
    port: 443,
    path: `/bot${CONFIG.telegramBotToken}/sendMessage`,
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(payload),
    },
  };

  return new Promise((resolve, reject) => {
    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        if (res.statusCode === 200) {
          console.log('[INFO] Telegram alert sent successfully');
          resolve(true);
        } else {
          console.error(`[ERROR] Telegram API error: ${res.statusCode} ${data}`);
          resolve(false);
        }
      });
    });

    req.on('error', (error) => {
      console.error('[ERROR] Telegram request failed:', error.message);
      resolve(false);
    });

    req.write(payload);
    req.end();
  });
}

/**
 * Update agent heartbeat
 */
function updateHeartbeat(agentId, heartbeatData = {}) {
  const agent = agentState.get(agentId);
  if (!agent) {
    console.warn(`[WARN] Unknown agent: ${agentId}`);
    return;
  }

  const now = new Date();
  agent.last_heartbeat = now.toISOString();
  agent.seconds_since_heartbeat = 0;
  agent.status = 'online';
  agent.metadata = { ...agent.metadata, ...heartbeatData };

  console.log(`[HEARTBEAT] ${agent.name} (${agentId}) - ${agent.last_heartbeat}`);
}

/**
 * Check agent status and send alerts
 */
async function checkAgentStatus() {
  const now = Date.now();
  const alerts = [];

  for (const [agentId, agent] of agentState.entries()) {
    if (!agent.last_heartbeat) {
      agent.status = 'unknown';
      agent.seconds_since_heartbeat = null;
      continue;
    }

    // Calculate time since last heartbeat
    const lastHeartbeatTime = new Date(agent.last_heartbeat).getTime();
    const secondsSince = Math.floor((now - lastHeartbeatTime) / 1000);
    agent.seconds_since_heartbeat = secondsSince;

    // Update status based on threshold
    if (secondsSince > CONFIG.offlineThreshold) {
      agent.status = 'offline';

      // Send alert if not already sent in the last 30 minutes
      const shouldAlert = !agent.last_alert_sent ||
        (now - new Date(agent.last_alert_sent).getTime()) > 30 * 60 * 1000;

      if (shouldAlert) {
        const alertMessage = `🔴 *Agent Alert*\n\n` +
          `*Agent*: ${agent.name} (${agentId})\n` +
          `*Status*: Offline\n` +
          `*Last Heartbeat*: ${agent.last_heartbeat}\n` +
          `*Time Offline*: ${secondsSince}s (threshold: ${CONFIG.offlineThreshold}s)\n` +
          `*Time*: ${new Date().toISOString()}`;

        const sent = await sendTelegramAlert(alertMessage);
        if (sent) {
          agent.last_alert_sent = new Date().toISOString();
          alerts.push({
            agent_id: agentId,
            agent_name: agent.name,
            seconds_offline: secondsSince,
            alert_time: agent.last_alert_sent,
            message: `Agent ${agent.name} offline for ${secondsSince}s`,
          });
        }
      }
    } else {
      agent.status = 'online';
    }
  }

  return alerts;
}

/**
 * Generate and save heartbeat map
 */
async function saveHeartbeatMap() {
  const alerts = await checkAgentStatus();

  // Build agents map
  const agents = {};
  for (const [agentId, agent] of agentState.entries()) {
    agents[agentId] = {
      id: agent.id,
      name: agent.name,
      status: agent.status,
      last_heartbeat: agent.last_heartbeat,
      seconds_since_heartbeat: agent.seconds_since_heartbeat,
      channel: agent.channel,
      metadata: agent.metadata,
    };
  }

  // Calculate summary
  const summary = {
    total_agents: CONFIG.agents.length,
    online_agents: Array.from(agentState.values()).filter(a => a.status === 'online').length,
    offline_agents: Array.from(agentState.values()).filter(a => a.status === 'offline').length,
    unknown_agents: Array.from(agentState.values()).filter(a => a.status === 'unknown').length,
  };

  const heartbeatMap = {
    timestamp: new Date().toISOString(),
    agents,
    alerts,
    summary,
  };

  // Write to file
  try {
    writeFileSync(CONFIG.outputFile, JSON.stringify(heartbeatMap, null, 2));
    console.log(`[INFO] Heartbeat map saved to ${CONFIG.outputFile}`);
    console.log(`[INFO] Summary: ${summary.online_agents} online, ${summary.offline_agents} offline, ${summary.unknown_agents} unknown`);
  } catch (error) {
    console.error('[ERROR] Failed to write heartbeat map:', error.message);
  }
}

/**
 * Main function
 */
async function main() {
  console.log('[INFO] Agent Heartbeat Monitor starting...');
  console.log(`[INFO] Redis URL: ${CONFIG.redisUrl}`);
  console.log(`[INFO] Offline threshold: ${CONFIG.offlineThreshold}s`);
  console.log(`[INFO] Check interval: ${CONFIG.checkInterval}ms`);
  console.log(`[INFO] Monitoring agents: ${CONFIG.agents.map(a => a.name).join(', ')}`);

  // Create Redis subscriber
  const subscriber = createClient({ url: CONFIG.redisUrl });
  subscriber.on('error', (err) => console.error('[ERROR] Redis subscriber error:', err));

  try {
    await subscriber.connect();
    console.log('[INFO] Connected to Redis');

    // Subscribe to all agent heartbeat channels
    for (const agent of CONFIG.agents) {
      await subscriber.subscribe(agent.channel, (message) => {
        try {
          const data = JSON.parse(message);
          updateHeartbeat(agent.id, data);
        } catch (error) {
          console.error(`[ERROR] Failed to parse heartbeat from ${agent.channel}:`, error.message);
          // Still update heartbeat even if parse fails
          updateHeartbeat(agent.id);
        }
      });
      console.log(`[INFO] Subscribed to ${agent.channel}`);
    }

    // Periodic status check and map generation
    setInterval(async () => {
      await saveHeartbeatMap();
    }, CONFIG.checkInterval);

    // Initial save
    await saveHeartbeatMap();

    console.log('[INFO] Agent Heartbeat Monitor is running');
  } catch (error) {
    console.error('[ERROR] Failed to start monitor:', error);
    process.exit(1);
  }
}

// Handle graceful shutdown
process.on('SIGINT', () => {
  console.log('\n[INFO] Shutting down...');
  saveHeartbeatMap().then(() => process.exit(0));
});

process.on('SIGTERM', () => {
  console.log('\n[INFO] Shutting down...');
  saveHeartbeatMap().then(() => process.exit(0));
});

// Start the monitor
main().catch(error => {
  console.error('[ERROR] Fatal error:', error);
  process.exit(1);
});
