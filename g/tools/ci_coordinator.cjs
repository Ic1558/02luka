#!/usr/bin/env node
/**
 * CI Event Coordinator - Phase 20
 *
 * Enhanced event routing and coordination for CI/CD pipelines.
 * Integrates with Redis event bus for distributed orchestration.
 *
 * Features:
 * - Multi-lane CI coordination (GPT-4, Claude Web, Crude)
 * - Event priority queuing
 * - Retry logic with exponential backoff
 * - Dead letter queue handling
 * - Real-time metrics and observability
 * - Integration with CLS Web Bridge
 *
 * @module ci_coordinator
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
  coordinator: {
    // Event queues
    queues: {
      high: 'ci:queue:high',
      normal: 'ci:queue:normal',
      low: 'ci:queue:low',
      deadletter: 'ci:queue:dlq',
    },
    // Retry configuration
    maxRetries: parseInt(process.env.CI_MAX_RETRIES || '3', 10),
    retryDelayMs: parseInt(process.env.CI_RETRY_DELAY || '1000', 10),
    retryBackoffMultiplier: parseFloat(process.env.CI_RETRY_BACKOFF || '2.0'),
    // Lanes configuration
    lanes: {
      gpt4: { enabled: true, priority: 'high', concurrency: 5 },
      claude_web: { enabled: true, priority: 'normal', concurrency: 10 },
      crude: { enabled: true, priority: 'low', concurrency: 3 },
    },
    // Health check
    healthCheckInterval: parseInt(process.env.CI_HEALTH_INTERVAL || '30000', 10),
  },
  logging: {
    reportDir: process.env.CI_REPORT_DIR || 'g/reports/cls_web',
    logLevel: process.env.CI_LOG_LEVEL || 'info',
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
      console.log(`[${timestamp}] [CI-COORD] [${level.toUpperCase()}] ${message}${metaStr}`);
    }
  }

  debug(msg, meta) { this._log('debug', msg, meta); }
  info(msg, meta) { this._log('info', msg, meta); }
  warn(msg, meta) { this._log('warn', msg, meta); }
  error(msg, meta) { this._log('error', msg, meta); }
}

// Event Router
class EventRouter extends EventEmitter {
  constructor(redis, config, logger) {
    super();
    this.redis = redis;
    this.config = config;
    this.logger = logger;
    this.metrics = {
      totalEvents: 0,
      processedEvents: 0,
      failedEvents: 0,
      retriedEvents: 0,
      deadLetterEvents: 0,
      eventsByLane: {},
      eventsByPriority: { high: 0, normal: 0, low: 0 },
    };

    // Initialize lane metrics
    Object.keys(config.coordinator.lanes).forEach((lane) => {
      this.metrics.eventsByLane[lane] = 0;
    });
  }

  async routeEvent(event) {
    this.metrics.totalEvents++;
    const { lane, priority, type, data } = event;

    // Validate lane
    if (!this.config.coordinator.lanes[lane]) {
      this.logger.warn('Unknown lane, routing to default', { lane, event });
      event.lane = 'claude_web'; // Default lane
    }

    // Determine priority
    const laneConfig = this.config.coordinator.lanes[event.lane];
    const eventPriority = priority || laneConfig.priority || 'normal';
    event.priority = eventPriority;

    // Add routing metadata
    event.routedAt = Date.now();
    event.routeId = `${event.lane}-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;

    // Route to appropriate queue
    const queueName = this.config.coordinator.queues[eventPriority] ||
                      this.config.coordinator.queues.normal;

    await this.redis.rPush(queueName, JSON.stringify(event));

    this.metrics.eventsByLane[event.lane] = (this.metrics.eventsByLane[event.lane] || 0) + 1;
    this.metrics.eventsByPriority[eventPriority]++;

    this.logger.info('Event routed', {
      routeId: event.routeId,
      lane: event.lane,
      priority: eventPriority,
      type: event.type,
      queue: queueName,
    });

    this.emit('event:routed', event);
    return event;
  }

  async getQueueDepth(priority = 'normal') {
    const queueName = this.config.coordinator.queues[priority];
    return await this.redis.lLen(queueName);
  }

  async getDeadLetterQueueDepth() {
    return await this.redis.lLen(this.config.coordinator.queues.deadletter);
  }

  getMetrics() {
    return { ...this.metrics };
  }
}

// Event Processor
class EventProcessor extends EventEmitter {
  constructor(redis, router, config, logger) {
    super();
    this.redis = redis;
    this.router = router;
    this.config = config;
    this.logger = logger;
    this.running = false;
    this.processors = new Map();
  }

  async start() {
    if (this.running) {
      this.logger.warn('Event processor already running');
      return;
    }

    this.running = true;
    this.logger.info('Event processor starting');

    // Start processors for each priority queue
    ['high', 'normal', 'low'].forEach((priority) => {
      this._startQueueProcessor(priority);
    });
  }

  async stop() {
    this.running = false;
    this.logger.info('Event processor stopping');

    // Wait for all processors to finish
    await Promise.all(Array.from(this.processors.values()));
  }

  async _startQueueProcessor(priority) {
    const queueName = this.config.coordinator.queues[priority];
    this.logger.info('Starting queue processor', { priority, queueName });

    const processor = this._processQueue(priority, queueName);
    this.processors.set(priority, processor);
  }

  async _processQueue(priority, queueName) {
    while (this.running) {
      try {
        // Block-pop with timeout
        const result = await this.redis.blPop(queueName, 1);

        if (result) {
          const { element } = result;
          const event = JSON.parse(element);
          await this._processEvent(event);
        }
      } catch (error) {
        this.logger.error('Error in queue processor', {
          priority,
          queueName,
          error: error.message,
        });
        await new Promise(resolve => setTimeout(resolve, 1000));
      }
    }
  }

  async _processEvent(event) {
    const { routeId, type, lane, data } = event;

    this.logger.debug('Processing event', { routeId, type, lane });

    try {
      // Simulate event processing
      await this._handleEvent(event);

      this.router.metrics.processedEvents++;
      this.emit('event:processed', event);

      this.logger.info('Event processed successfully', { routeId, type, lane });
    } catch (error) {
      this.logger.error('Event processing failed', {
        routeId,
        type,
        lane,
        error: error.message,
      });

      await this._handleFailedEvent(event, error);
    }
  }

  async _handleEvent(event) {
    // This is where actual event handling logic would go
    // For now, we simulate processing
    const { type, lane, data } = event;

    switch (type) {
      case 'ci:build':
        await this._handleBuildEvent(event);
        break;

      case 'ci:test':
        await this._handleTestEvent(event);
        break;

      case 'ci:deploy':
        await this._handleDeployEvent(event);
        break;

      case 'ci:health':
        await this._handleHealthEvent(event);
        break;

      default:
        this.logger.warn('Unknown event type', { type, event });
    }
  }

  async _handleBuildEvent(event) {
    this.logger.debug('Handling build event', { event });
    // Simulate build time
    await new Promise(resolve => setTimeout(resolve, Math.random() * 100));
  }

  async _handleTestEvent(event) {
    this.logger.debug('Handling test event', { event });
    // Simulate test time
    await new Promise(resolve => setTimeout(resolve, Math.random() * 200));
  }

  async _handleDeployEvent(event) {
    this.logger.debug('Handling deploy event', { event });
    // Simulate deploy time
    await new Promise(resolve => setTimeout(resolve, Math.random() * 300));
  }

  async _handleHealthEvent(event) {
    this.logger.debug('Handling health event', { event });

    const health = {
      timestamp: new Date().toISOString(),
      coordinator: 'healthy',
      metrics: this.router.getMetrics(),
      queueDepths: {
        high: await this.router.getQueueDepth('high'),
        normal: await this.router.getQueueDepth('normal'),
        low: await this.router.getQueueDepth('low'),
        deadletter: await this.router.getDeadLetterQueueDepth(),
      },
    };

    // Store health data
    await this.redis.set('ci:health:latest', JSON.stringify(health), { EX: 300 });

    this.emit('health:checked', health);
  }

  async _handleFailedEvent(event, error) {
    const retryCount = event.retryCount || 0;

    if (retryCount < this.config.coordinator.maxRetries) {
      // Retry with exponential backoff
      event.retryCount = retryCount + 1;
      const delay = this.config.coordinator.retryDelayMs *
                    Math.pow(this.config.coordinator.retryBackoffMultiplier, retryCount);

      this.logger.info('Retrying event', {
        routeId: event.routeId,
        retryCount: event.retryCount,
        delayMs: delay,
      });

      // Schedule retry
      setTimeout(async () => {
        await this.router.routeEvent(event);
      }, delay);

      this.router.metrics.retriedEvents++;
    } else {
      // Move to dead letter queue
      this.logger.error('Event exhausted retries, moving to DLQ', {
        routeId: event.routeId,
        retryCount,
        error: error.message,
      });

      event.failedAt = Date.now();
      event.failureReason = error.message;

      await this.redis.rPush(
        this.config.coordinator.queues.deadletter,
        JSON.stringify(event)
      );

      this.router.metrics.failedEvents++;
      this.router.metrics.deadLetterEvents++;
      this.emit('event:dead_letter', event);
    }
  }
}

// CI Coordinator
class CICoordinator {
  constructor(config) {
    this.config = config;
    this.logger = new Logger(config.logging.logLevel);
    this.redis = null;
    this.router = null;
    this.processor = null;
    this.healthCheckTimer = null;
  }

  async initialize() {
    this.logger.info('Initializing CI Coordinator', {
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

    // Create router and processor
    this.router = new EventRouter(this.redis, this.config, this.logger);
    this.processor = new EventProcessor(this.redis, this.router, this.config, this.logger);

    // Set up event listeners
    this._setupEventListeners();

    // Ensure report directory exists
    await fs.mkdir(this.config.logging.reportDir, { recursive: true });

    this.logger.info('CI Coordinator initialized');
  }

  _setupEventListeners() {
    this.router.on('event:routed', (event) => {
      this.logger.debug('Event routed', { routeId: event.routeId });
    });

    this.processor.on('event:processed', (event) => {
      this.logger.debug('Event processed', { routeId: event.routeId });
    });

    this.processor.on('event:dead_letter', (event) => {
      this._writeDeadLetterReport(event);
    });

    this.processor.on('health:checked', (health) => {
      this._writeHealthReport(health);
    });
  }

  async _writeDeadLetterReport(event) {
    const reportPath = path.join(
      this.config.logging.reportDir,
      `dlq_${event.routeId}_${Date.now()}.json`
    );

    try {
      await fs.writeFile(reportPath, JSON.stringify(event, null, 2));
      this.logger.debug('Dead letter report written', { reportPath });
    } catch (error) {
      this.logger.error('Failed to write dead letter report', {
        error: error.message,
        reportPath,
      });
    }
  }

  async _writeHealthReport(health) {
    const reportPath = path.join(
      this.config.logging.reportDir,
      'coordinator_health_latest.json'
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
    this.logger.info('Starting CI Coordinator');

    // Start event processor
    await this.processor.start();

    // Start periodic health checks
    this.healthCheckTimer = setInterval(async () => {
      await this.router.routeEvent({
        type: 'ci:health',
        lane: 'claude_web',
        priority: 'high',
        timestamp: Date.now(),
      });
    }, this.config.coordinator.healthCheckInterval);

    this.logger.info('CI Coordinator started');
  }

  async stop() {
    this.logger.info('Stopping CI Coordinator');

    if (this.healthCheckTimer) {
      clearInterval(this.healthCheckTimer);
    }

    await this.processor.stop();
    await this.redis.quit();

    this.logger.info('CI Coordinator stopped');
  }

  async routeEvent(event) {
    return await this.router.routeEvent(event);
  }

  getMetrics() {
    return this.router.getMetrics();
  }
}

// CLI interface
async function main() {
  const coordinator = new CICoordinator(CONFIG);

  // Handle graceful shutdown
  const shutdown = async (signal) => {
    console.log(`\nReceived ${signal}, shutting down gracefully...`);
    await coordinator.stop();
    process.exit(0);
  };

  process.on('SIGINT', () => shutdown('SIGINT'));
  process.on('SIGTERM', () => shutdown('SIGTERM'));

  try {
    await coordinator.initialize();
    await coordinator.start();

    // Keep running
    console.log('CI Coordinator is running. Press Ctrl+C to stop.');
  } catch (error) {
    console.error('Fatal error:', error);
    process.exit(1);
  }
}

// Export for testing and programmatic use
if (require.main === module) {
  main();
}

module.exports = { CICoordinator, CONFIG };
