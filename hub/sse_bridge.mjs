#!/usr/bin/env node
/**
 * SSE Bridge - Phase 20.5
 * Subscribe to Redis pub/sub channels and fan-out events to SSE clients
 *
 * Features:
 * - Redis subscriber with automatic reconnection
 * - SSE endpoint with keepalive and retry
 * - Fan-out to multiple clients
 * - Backoff/retry logic built-in
 */

import { createClient } from 'redis';
import EventEmitter from 'events';

export class SSEBridge extends EventEmitter {
  constructor(config) {
    super();
    this.config = config;
    this.clients = new Set();
    this.redisClient = null;
    this.keepaliveInterval = null;
    this.reconnectAttempts = 0;
    this.maxReconnectAttempts = 10;
  }

  /**
   * Initialize Redis subscriber
   */
  async init() {
    const redisConfig = this.config.redis;

    // Create Redis client for subscribing
    this.redisClient = createClient({
      url: redisConfig.url,
      password: redisConfig.password,
    });

    // Error handling
    this.redisClient.on('error', (err) => {
      console.error('[SSE Bridge] Redis error:', err.message);
      this.emit('redis:error', err);
    });

    // Connection events
    this.redisClient.on('connect', () => {
      console.log('[SSE Bridge] Redis connected');
      this.reconnectAttempts = 0;
    });

    this.redisClient.on('reconnecting', () => {
      this.reconnectAttempts++;
      console.log(`[SSE Bridge] Redis reconnecting... (attempt ${this.reconnectAttempts})`);

      if (this.reconnectAttempts >= this.maxReconnectAttempts) {
        console.error('[SSE Bridge] Max reconnection attempts reached');
        this.redisClient.disconnect();
      }
    });

    // Connect to Redis
    await this.redisClient.connect();

    // Subscribe to channels
    for (const channel of redisConfig.channels) {
      await this.redisClient.subscribe(channel, (message, channelName) => {
        this.handleRedisMessage(channelName, message);
      });
      console.log(`[SSE Bridge] Subscribed to channel: ${channel}`);
    }

    // Start keepalive
    this.startKeepalive();

    return this;
  }

  /**
   * Handle incoming Redis messages
   */
  handleRedisMessage(channel, message) {
    try {
      const data = typeof message === 'string' ? JSON.parse(message) : message;

      const event = {
        channel,
        timestamp: new Date().toISOString(),
        data,
      };

      console.log(`[SSE Bridge] Event from ${channel}:`, data.type || 'unknown');

      // Fan-out to all connected SSE clients
      this.broadcast(event);

      // Emit for other listeners
      this.emit('event', event);
    } catch (err) {
      console.error('[SSE Bridge] Failed to parse message:', err.message);
    }
  }

  /**
   * Broadcast event to all SSE clients
   */
  broadcast(event) {
    const sseData = this.formatSSE(event);

    this.clients.forEach((client) => {
      try {
        client.write(sseData);
      } catch (err) {
        console.error('[SSE Bridge] Failed to write to client:', err.message);
        this.clients.delete(client);
      }
    });
  }

  /**
   * Format event as SSE data
   */
  formatSSE(event) {
    const lines = [
      `event: ${event.channel}`,
      `data: ${JSON.stringify(event)}`,
      '',
      '',
    ];
    return lines.join('\n');
  }

  /**
   * Add SSE client
   */
  addClient(res) {
    // Set SSE headers
    res.writeHead(200, {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive',
      'Access-Control-Allow-Origin': '*',
    });

    // Send retry interval
    const retryMs = this.config.server.sse?.retry_interval_ms || 3000;
    res.write(`retry: ${retryMs}\n\n`);

    // Add to clients
    this.clients.add(res);
    console.log(`[SSE Bridge] Client connected (total: ${this.clients.size})`);

    // Send welcome message
    res.write(this.formatSSE({
      channel: 'system',
      timestamp: new Date().toISOString(),
      data: { type: 'connected', message: 'SSE bridge ready' },
    }));

    // Handle client disconnect
    res.on('close', () => {
      this.clients.delete(res);
      console.log(`[SSE Bridge] Client disconnected (total: ${this.clients.size})`);
    });
  }

  /**
   * Start keepalive (heartbeat) for SSE clients
   */
  startKeepalive() {
    const interval = this.config.server.sse?.keepalive_interval_ms || 30000;

    this.keepaliveInterval = setInterval(() => {
      const keepalive = `: keepalive ${Date.now()}\n\n`;

      this.clients.forEach((client) => {
        try {
          client.write(keepalive);
        } catch (err) {
          this.clients.delete(client);
        }
      });
    }, interval);
  }

  /**
   * Cleanup and disconnect
   */
  async close() {
    if (this.keepaliveInterval) {
      clearInterval(this.keepaliveInterval);
    }

    // Close all SSE clients
    this.clients.forEach((client) => {
      try {
        client.end();
      } catch (err) {
        // Ignore errors
      }
    });
    this.clients.clear();

    // Disconnect Redis
    if (this.redisClient) {
      await this.redisClient.disconnect();
    }

    console.log('[SSE Bridge] Closed');
  }
}

/**
 * Create and initialize SSE bridge
 */
export async function createSSEBridge(config) {
  const bridge = new SSEBridge(config);
  await bridge.init();
  return bridge;
}
