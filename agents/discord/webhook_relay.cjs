#!/usr/bin/env node
/**
 * Discord Webhook Relay
 * Lightweight webhook client using Node.js native https module (zero dependencies)
 *
 * Usage:
 *   const { postDiscordWebhook } = require('./webhook_relay.cjs');
 *   await postDiscordWebhook('https://discord.com/api/webhooks/...', { content: 'Hello' });
 */

const http = require('http');
const https = require('https');

/**
 * Post a message to a Discord webhook
 * @param {string} url - Discord webhook URL
 * @param {object} payload - Discord webhook payload (at minimum: { content: string })
 * @returns {Promise<{ok: boolean}>} - Resolves if successful (2xx status)
 * @throws {Error} - Rejects with error.statusCode if Discord returns non-2xx
 */
function postDiscordWebhook(url, payload) {
  return new Promise((resolve, reject) => {
    if (!url || typeof url !== 'string') {
      return reject(new Error('Invalid webhook URL'));
    }

    if (!payload || typeof payload !== 'object') {
      return reject(new Error('Invalid payload (must be object)'));
    }

    if (!payload.content || typeof payload.content !== 'string') {
      return reject(new Error('Payload must contain "content" string'));
    }

    const data = JSON.stringify(payload);
    let parsedUrl;

    try {
      parsedUrl = new URL(url);
    } catch (err) {
      return reject(new Error(`Invalid URL: ${err.message}`));
    }

    if (!parsedUrl.protocol || !['https:', 'http:'].includes(parsedUrl.protocol)) {
      return reject(new Error(`Unsupported protocol: ${parsedUrl.protocol || 'unknown'}`));
    }

    const isHttps = parsedUrl.protocol === 'https:';
    const requester = isHttps ? https : http;

    const options = {
      hostname: parsedUrl.hostname,
      port: parsedUrl.port || (isHttps ? 443 : 80),
      path: (parsedUrl.pathname || '/') + (parsedUrl.search || ''),
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(data),
        'User-Agent': '02luka-webhook-relay/1.0'
      },
      timeout: 10000 // 10 second timeout
    };

    const req = requester.request(options, (res) => {
      let body = '';

      res.on('data', (chunk) => {
        body += chunk;
      });

      res.on('end', () => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          resolve({ ok: true });
        } else {
          const error = new Error(
            `Discord webhook returned ${res.statusCode}: ${body.substring(0, 200)}`
          );
          error.statusCode = res.statusCode;
          error.responseBody = body;
          reject(error);
        }
      });
    });

    req.on('error', (err) => {
      reject(new Error(`Network error: ${err.message}`));
    });

    req.on('timeout', () => {
      req.destroy();
      reject(new Error('Request timeout (10s)'));
    });

    req.write(data);
    req.end();
  });
}

module.exports = { postDiscordWebhook };
