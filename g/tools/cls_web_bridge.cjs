#!/usr/bin/env node
/**
 * CLS Web Bridge - Phase 20
 *
 * Bridges Claude Code Sessions (CLS) with web interface for load testing
 * and concurrent orchestration via Redis event bus.
 *
 * Features:
 * - Event routing and dispatching
 * - Session lifecycle management
 * - Load balancing and concurrency control
 * - Health checks and watchdog integration
 * - Telemetry and metrics collection
 *
 * @module cls_web_bridge
 */

const { createClient } = require('redis');
const { EventEmitter } = require('events');
const fs = require('fs').promises;
const path = require('path');

// Configuration
const CONFIG = {
  redis: {
    host: process.env.REDIS_HOST || '127.0.0.1',
    port: parseInt(process.env.REDIS_PORT || '6379', 10),
    password: process.env.REDIS_PASSWORD || '',
    db: parseInt(process.env.REDIS_DB || '0', 10),
  },
  bridge: {
    maxConcurrentSessions: parseInt(process.env.CLS_MAX_CONCURRENT || '10', 10),
    sessionTimeout: parseInt(process.env.CLS_SESSION_TIMEOUT || '300000', 10), // 5 min
    healthCheckInterval: parseInt(process.env.CLS_HEALTH_INTERVAL || '30000', 10), // 30s
    eventQueueName: process.env.CLS_EVENT_QUEUE || 'cls:events',
    sessionKeyPrefix: process.env.CLS_SESSION_PREFIX || 'cls:session:',
    metricsKeyPrefix: process.env.CLS_METRICS_PREFIX || 'cls:metrics:',
  },
  logging: {
    reportDir: process.env.CLS_REPORT_DIR || 'g/reports/cls_web',
    logLevel: process.env.CLS_LOG_LEVEL || 'info',
  },
};

// Logger
class Logger {
  constructor(level = 'info') {
    this.levels = { debug: 0, info: 1, warn: 2, error: 3 };
    this.level = this.levels[level] || 1;
  }

  _log(level, message, meta = {}) {
    if (this.levels[level] >= this.level) {
      const timestamp = new Date().toISOString();
      const metaStr = Object.keys(meta).length > 0 ? ` ${JSON.stringify(meta)}` : '';
      console.log(`[${timestamp}] [${level.toUpperCase()}] ${message}${metaStr}`);
    }
  }

  debug(msg, meta) { this._log('debug', msg, meta); }
  info(msg, meta) { this._log('info', msg, meta); }
  warn(msg, meta) { this._log('warn', msg, meta); }
  error(msg, meta) { this._log('error', msg, meta); }
}

// Session Manager
class SessionManager extends EventEmitter {
  constructor(redis, config, logger) {
    super();
    this.redis = redis;
    this.config = config;
    this.logger = logger;
    this.sessions = new Map();
    this.metrics = {
      totalSessions: 0,
      activeSessions: 0,
      completedSessions: 0,
      failedSessions: 0,
      eventsProcessed: 0,
      errors: 0,
    };
  }

  async createSession(sessionId, metadata = {}) {
    if (this.sessions.has(sessionId)) {
      this.logger.warn('Session already exists', { sessionId });
      return false;
    }

    if (this.sessions.size >= this.config.bridge.maxConcurrentSessions) {
      this.logger.warn('Max concurrent sessions reached', {
        current: this.sessions.size,
        max: this.config.bridge.maxConcurrentSessions,
      });
      return false;
    }

    const session = {
      id: sessionId,
      startTime: Date.now(),
      lastActivity: Date.now(),
      status: 'active',
      metadata,
      eventsProcessed: 0,
    };

    this.sessions.set(sessionId, session);
    this.metrics.totalSessions++;
    this.metrics.activeSessions++;

    // Store in Redis
    const key = `${this.config.bridge.sessionKeyPrefix}${sessionId}`;
    await this.redis.set(key, JSON.stringify(session), {
      EX: Math.floor(this.config.bridge.sessionTimeout / 1000),
    });

    this.logger.info('Session created', { sessionId, metadata });
    this.emit('session:created', session);
    return true;
  }

  async updateSession(sessionId, updates = {}) {
    const session = this.sessions.get(sessionId);
    if (!session) {
      this.logger.warn('Session not found', { sessionId });
      return false;
    }

    Object.assign(session, updates, { lastActivity: Date.now() });

    // Update in Redis
    const key = `${this.config.bridge.sessionKeyPrefix}${sessionId}`;
    await this.redis.set(key, JSON.stringify(session), {
      EX: Math.floor(this.config.bridge.sessionTimeout / 1000),
    });

    this.emit('session:updated', session);
    return true;
  }

  async endSession(sessionId, status = 'completed') {
    const session = this.sessions.get(sessionId);
    if (!session) {
      this.logger.warn('Session not found', { sessionId });
      return false;
    }

    session.status = status;
    session.endTime = Date.now();
    session.duration = session.endTime - session.startTime;

    this.metrics.activeSessions--;
    if (status === 'completed') {
      this.metrics.completedSessions++;
    } else {
      this.metrics.failedSessions++;
    }

    // Remove from active sessions but keep in Redis for history
    this.sessions.delete(sessionId);

    const key = `${this.config.bridge.sessionKeyPrefix}${sessionId}`;
    await this.redis.set(key, JSON.stringify(session), { EX: 3600 }); // Keep for 1 hour

    this.logger.info('Session ended', { sessionId, status, duration: session.duration });
    this.emit('session:ended', session);
    return true;
  }

  getActiveSessionCount() {
    return this.sessions.size;
  }

  getMetrics() {
    return { ...this.metrics };
  }
}

// Event Coordinator
class EventCoordinator extends EventEmitter {
  constructor(redis, sessionManager, config, logger) {
    super();
    this.redis = redis;
    this.sessionManager = sessionManager;
    this.config = config;
    this.logger = logger;
    this.running = false;
  }

  async start() {
    if (this.running) {
      this.logger.warn('Event coordinator already running');
      return;
    }

    this.running = true;
    this.logger.info('Event coordinator starting', {
      queueName: this.config.bridge.eventQueueName,
    });

    // Start processing events
    this._processEvents();
  }

  async stop() {
    this.running = false;
    this.logger.info('Event coordinator stopped');
  }

  async _processEvents() {
    while (this.running) {
      try {
        // Block-pop from Redis list (BLPOP with 1 second timeout)
        const result = await this.redis.blPop(this.config.bridge.eventQueueName, 1);

        if (result) {
          const { element } = result;
          await this._handleEvent(JSON.parse(element));
        }
      } catch (error) {
        this.logger.error('Error processing event', { error: error.message });
        this.sessionManager.metrics.errors++;
        await new Promise(resolve => setTimeout(resolve, 1000)); // Back off on error
      }
    }
  }

  async _handleEvent(event) {
    this.logger.debug('Processing event', { event });
    this.sessionManager.metrics.eventsProcessed++;

    const { type, sessionId, data } = event;

    switch (type) {
      case 'session:create':
        await this.sessionManager.createSession(sessionId, data);
        break;

      case 'session:update':
        await this.sessionManager.updateSession(sessionId, data);
        break;

      case 'session:end':
        await this.sessionManager.endSession(sessionId, data?.status || 'completed');
        break;

      case 'health:check':
        await this._handleHealthCheck(data);
        break;

      default:
        this.logger.warn('Unknown event type', { type, event });
    }

    this.emit('event:processed', event);
  }

  async _handleHealthCheck(data) {
    const metrics = this.sessionManager.getMetrics();
    const health = {
      timestamp: new Date().toISOString(),
      status: 'healthy',
      activeSessions: this.sessionManager.getActiveSessionCount(),
      metrics,
    };

    // Store health data
    const key = `${this.config.bridge.metricsKeyPrefix}health:latest`;
    await this.redis.set(key, JSON.stringify(health), { EX: 300 });

    this.logger.info('Health check', health);
    this.emit('health:checked', health);
  }

  async publishEvent(event) {
    await this.redis.rPush(this.config.bridge.eventQueueName, JSON.stringify(event));
    this.logger.debug('Event published', { event });
  }
}

// CLS Web Bridge
class CLSWebBridge {
  constructor(config) {
    this.config = config;
    this.logger = new Logger(config.logging.logLevel);
    this.redis = null;
    this.sessionManager = null;
    this.coordinator = null;
    this.healthCheckTimer = null;
  }

  async initialize() {
    this.logger.info('Initializing CLS Web Bridge', {
      redisHost: this.config.redis.host,
      redisPort: this.config.redis.port,
    });

    // Create Redis client
    this.redis = createClient({
      socket: {
        host: this.config.redis.host,
        port: this.config.redis.port,
      },
      password: this.config.redis.password || undefined,
      database: this.config.redis.db,
    });

    this.redis.on('error', (err) => {
      this.logger.error('Redis error', { error: err.message });
    });

    await this.redis.connect();
    this.logger.info('Redis connected');

    // Create managers
    this.sessionManager = new SessionManager(this.redis, this.config, this.logger);
    this.coordinator = new EventCoordinator(
      this.redis,
      this.sessionManager,
      this.config,
      this.logger
    );

    // Set up event listeners
    this._setupEventListeners();

    // Ensure report directory exists
    await fs.mkdir(this.config.logging.reportDir, { recursive: true });

    this.logger.info('CLS Web Bridge initialized');
  }

  _setupEventListeners() {
    this.sessionManager.on('session:created', (session) => {
      this.logger.debug('Session created event', { sessionId: session.id });
    });

    this.sessionManager.on('session:ended', (session) => {
      this._writeSessionReport(session);
    });

    this.coordinator.on('health:checked', (health) => {
      this._writeHealthReport(health);
    });
  }

  async _writeSessionReport(session) {
    const reportPath = path.join(
      this.config.logging.reportDir,
      `session_${session.id}_${Date.now()}.json`
    );

    try {
      await fs.writeFile(reportPath, JSON.stringify(session, null, 2));
      this.logger.debug('Session report written', { reportPath });
    } catch (error) {
      this.logger.error('Failed to write session report', {
        error: error.message,
        reportPath,
      });
    }
  }

  async _writeHealthReport(health) {
    const reportPath = path.join(
      this.config.logging.reportDir,
      'phase20_health_latest.json'
    );

    try {
      await fs.writeFile(reportPath, JSON.stringify(health, null, 2));
    } catch (error) {
      this.logger.error('Failed to write health report', {
        error: error.message,
        reportPath,
      });
    }
  }

  async start() {
    this.logger.info('Starting CLS Web Bridge');

    // Start event coordinator
    await this.coordinator.start();

    // Start periodic health checks
    this.healthCheckTimer = setInterval(() => {
      this.coordinator.publishEvent({
        type: 'health:check',
        timestamp: Date.now(),
      });
    }, this.config.bridge.healthCheckInterval);

    this.logger.info('CLS Web Bridge started');
  }

  async stop() {
    this.logger.info('Stopping CLS Web Bridge');

    if (this.healthCheckTimer) {
      clearInterval(this.healthCheckTimer);
    }

    await this.coordinator.stop();
    await this.redis.quit();

    this.logger.info('CLS Web Bridge stopped');
  }

  getMetrics() {
    return this.sessionManager.getMetrics();
  }
}

// CLI interface
async function main() {
  const bridge = new CLSWebBridge(CONFIG);

  // Handle graceful shutdown
  const shutdown = async (signal) => {
    console.log(`\nReceived ${signal}, shutting down gracefully...`);
    await bridge.stop();
    process.exit(0);
  };

  process.on('SIGINT', () => shutdown('SIGINT'));
  process.on('SIGTERM', () => shutdown('SIGTERM'));

  try {
    await bridge.initialize();
    await bridge.start();

    // Keep running
    console.log('CLS Web Bridge is running. Press Ctrl+C to stop.');
  } catch (error) {
    console.error('Fatal error:', error);
    process.exit(1);
  }
}

// Export for testing and programmatic use
if (require.main === module) {
  main();
}

module.exports = { CLSWebBridge, CONFIG };
