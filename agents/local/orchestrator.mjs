#!/usr/bin/env node
/**
 * Phase 7.2: Local Orchestrator & Delegation (ESM edition)
 * CLS-compatible orchestrator that exposes async helpers for manual + automatic runtimes.
 */

import { spawn } from 'node:child_process';
import { promises as fs } from 'node:fs';
import path from 'node:path';
import { setTimeout as delay } from 'node:timers/promises';
import { fileURLToPath } from 'node:url';

import POLICY from './policy.cjs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const REPO_ROOT = path.resolve(__dirname, '../..');
const Q = path.join(REPO_ROOT, 'queue');
const INBOX = path.join(Q, 'inbox');
const RUNNING = path.join(Q, 'running');
const DONE = path.join(Q, 'done');
const FAILED = path.join(Q, 'failed');
const TELEMETRY_DIR = path.join(REPO_ROOT, 'g', 'telemetry');
const LOGS_DIR = path.join(REPO_ROOT, 'g', 'logs');

const DEFAULT_INTERVAL_MS = 5000;

const envDefaults = Object.freeze({
  CLS_SHELL: process.env.CLS_SHELL || '/bin/bash',
  CLS_FS_ALLOW:
    process.env.CLS_FS_ALLOW || `/Volumes/lukadata:/Volumes/hd2:${process.env.HOME || ''}`
});

const CLI_ARGS = process.argv.slice(2);
const CLI_OPTS = {
  once: CLI_ARGS.includes('--once'),
  verbose: CLI_ARGS.includes('--verbose')
};

const consoleLogger = {
  info: (...args) => console.log(...args),
  warn: (...args) => console.warn(...args),
  error: (...args) => console.error(...args)
};

function getLogger(logger) {
  if (!logger) return consoleLogger;
  return {
    info: (...args) => (logger.info ? logger.info(...args) : console.log(...args)),
    warn: (...args) => (logger.warn ? logger.warn(...args) : console.warn(...args)),
    error: (...args) => (logger.error ? logger.error(...args) : console.error(...args))
  };
}

function withDefaults(env = {}) {
  return { ...process.env, ...envDefaults, ...env };
}

function spawnAsync(cmd, argv = [], options = {}) {
  const {
    timeout = 120_000,
    cwd = REPO_ROOT,
    env = {},
    logger,
    verbose = false
  } = options;

  const log = getLogger(logger);
  if (verbose) {
    log.info(`[sh] ${cmd} ${argv.join(' ')}`.trim());
  }

  return new Promise((resolve) => {
    const child = spawn(cmd, argv, {
      cwd,
      env: withDefaults(env),
      shell: false,
      stdio: ['ignore', 'pipe', 'pipe']
    });

    let stdout = '';
    let stderr = '';
    let settled = false;

    const finish = (code, extraStderr = '') => {
      if (settled) return;
      settled = true;
      resolve({
        status: typeof code === 'number' ? code : 1,
        stdout,
        stderr: (stderr + extraStderr).trim()
      });
    };

    const timer = setTimeout(() => {
      stderr += `\n[timeout after ${timeout}ms]`;
      child.kill('SIGTERM');
    }, timeout);
    timer.unref?.();

    child.stdout?.setEncoding('utf8');
    child.stderr?.setEncoding('utf8');

    child.stdout?.on('data', (chunk) => {
      stdout += chunk;
    });

    child.stderr?.on('data', (chunk) => {
      stderr += chunk;
    });

    child.on('error', (error) => {
      clearTimeout(timer);
      finish(1, `\n${error.message}`);
    });

    child.on('close', (code) => {
      clearTimeout(timer);
      finish(code ?? 0);
    });
  });
}

async function ensureDir(dir) {
  await fs.mkdir(dir, { recursive: true });
}

async function safeRead(fp) {
  try {
    return await fs.readFile(fp, 'utf8');
  } catch (error) {
    return '';
  }
}

async function writeTelemetry(entry, options = {}) {
  try {
    const log = getLogger(options.logger);
    const payload = {
      ts: new Date().toISOString(),
      task: 'local_exec',
      pass: 0,
      warn: 0,
      fail: 0,
      duration_ms: 0,
      ...entry
    };

    await ensureDir(TELEMETRY_DIR);
    const today = new Date().toISOString().slice(0, 10).replace(/-/g, '');
    const logFile = path.join(TELEMETRY_DIR, `${today}.log`);
    await fs.appendFile(logFile, JSON.stringify(payload) + '\n', 'utf8');

    if (options.verbose) {
      log.info('[telemetry]', payload);
    }
  } catch (error) {
    console.error('⚠️  Failed to write telemetry:', error.message);
  }
}

async function remember(kind, text, meta = {}, options = {}) {
  try {
    const memoryScript = path.join(REPO_ROOT, 'memory', 'index.cjs');
    const stat = await fs
      .access(memoryScript)
      .then(() => true)
      .catch(() => false);

    if (!stat) {
      if (options.verbose) {
        getLogger(options.logger).info('[memory] Script not found, skipping');
      }
      return;
    }

    const metaJson = JSON.stringify(meta);
    const result = await spawnAsync(
      'node',
      [memoryScript, '--remember', kind, text, '--meta', metaJson],
      {
        timeout: 10_000,
        verbose: options.verbose,
        logger: options.logger
      }
    );

    if (result.status !== 0 && options.verbose) {
      getLogger(options.logger).warn('[memory] Failed:', result.stderr);
    } else if (options.verbose) {
      getLogger(options.logger).info(
        `[memory] Recorded ${kind}: ${text.slice(0, 50)}...`
      );
    }
  } catch (error) {
    if (options.verbose) {
      getLogger(options.logger).error('[memory] Error:', error.message);
    }
  }
}

async function move(fp, dir) {
  const base = path.basename(fp);
  const target = path.join(dir, base);
  await fs.rename(fp, target);
  return target;
}

async function runSkill(step, taskId, options = {}) {
  const { skill, args = [], optional = false, timeout } = step;
  const { verbose = false, logger } = options;
  const log = getLogger(logger);

  if (verbose) {
    log.info(`[skill] ${skill} ${args.join(' ')}`.trim());
  }

  let result;
  switch (skill) {
    case 'bash':
      result = await spawnAsync('bash', args, { timeout, verbose, logger });
      break;
    case 'node':
      result = await spawnAsync('node', args, { timeout, verbose, logger });
      break;
    case 'git': {
      const gitScript = path.join(__dirname, 'skills', 'git.sh');
      result = await spawnAsync('bash', [gitScript, ...args], {
        timeout,
        verbose,
        logger
      });
      break;
    }
    case 'http': {
      const httpScript = path.join(__dirname, 'skills', 'http.cjs');
      result = await spawnAsync('node', [httpScript, ...args], {
        timeout,
        verbose,
        logger
      });
      break;
    }
    case 'ops_atomic': {
      const opsScript = path.join(REPO_ROOT, 'run', 'ops_atomic.sh');
      result = await spawnAsync('bash', [opsScript, ...args], {
        timeout: timeout || 30_000,
        verbose,
        logger
      });
      break;
    }
    case 'reportbot': {
      const reportbot = path.join(REPO_ROOT, 'agents', 'reportbot', 'index.cjs');
      result = await spawnAsync('node', [reportbot, ...args], {
        timeout,
        verbose,
        logger
      });
      break;
    }
    case 'self_review': {
      const selfReview = path.join(
        REPO_ROOT,
        'agents',
        'reflection',
        'self_review.cjs'
      );
      result = await spawnAsync('node', [selfReview, ...args], {
        timeout: timeout || 30_000,
        verbose,
        logger
      });
      break;
    }
    default:
      result = {
        status: 127,
        stdout: '',
        stderr: `Unknown skill: ${skill}`
      };
  }

  return {
    step: skill,
    args,
    code: result.status,
    stdout: result.stdout,
    stderr: result.stderr,
    optional
  };
}

async function execTask(fp, options = {}) {
  const { verbose = false, logger } = options;
  const log = getLogger(logger);
  const raw = await safeRead(fp);
  if (!raw) {
    return { status: 'invalid', reason: 'empty_file' };
  }

  let task;
  try {
    if (raw.trim().startsWith('{')) {
      task = JSON.parse(raw);
    } else {
      try {
        const yamlModule = await import('yaml');
        const yaml = yamlModule?.default || yamlModule;
        task = yaml.parse(raw);
      } catch (error) {
        task = JSON.parse(raw);
      }
    }
  } catch (error) {
    return { status: 'invalid', reason: 'parse_error', error: error.message };
  }

  const decision = POLICY.assess(task);
  if (decision.blocked) {
    await writeTelemetry(
      {
        pass: 0,
        warn: 1,
        fail: 1,
        meta: {
          reason: 'policy_block',
          id: task.id,
          policy_reason: decision.reason
        }
      },
      { verbose, logger }
    );
    return { status: 'blocked', reason: decision.reason };
  }

  const start = Date.now();
  const results = [];
  let failed = false;

  for (const step of task.steps || []) {
    const result = await runSkill(step, task.id, { verbose, logger });
    results.push(result);

    if (result.code !== 0 && !step.optional) {
      failed = true;
      const dur = Date.now() - start;

      await writeTelemetry(
        {
          pass: 0,
          warn: 0,
          fail: 1,
          duration_ms: dur,
          meta: {
            id: task.id,
            title: task.title,
            step: result.step,
            exit_code: result.code
          }
        },
        { verbose, logger }
      );

      await remember(
        'error',
        `Task "${task.title}" failed at step ${result.step}`,
        {
          id: task.id,
          exit_code: result.code,
          stderr: result.stderr.slice(0, 200)
        },
        { verbose, logger }
      );

      return { status: 'failed', results, failedAt: result.step };
    }
  }

  const acceptance = (task.acceptance || []).map((rule) => {
    let ok = true;
    if (rule.includes('exists under')) {
      const match = rule.match(/exists under (.+)/);
      if (match) {
        const pattern = match[1].trim();
        const dir = path.dirname(pattern);
        const file = path.basename(pattern);
        ok = fs
          .readdir(path.join(REPO_ROOT, dir))
          .then((files) => files.some((f) => f.includes(file.replace('*', ''))))
          .catch(() => false);
      }
    }
    return { rule, ok };
  });

  const resolvedAcceptance = await Promise.all(
    acceptance.map(async (entry) => ({ ...entry, ok: await entry.ok }))
  );
  const allPassed = resolvedAcceptance.every((a) => a.ok);
  const dur = Date.now() - start;

  await writeTelemetry(
    {
      pass: allPassed ? 1 : 0,
      warn: allPassed ? 0 : 1,
      fail: 0,
      duration_ms: dur,
      meta: {
        id: task.id,
        title: task.title,
        steps_count: results.length,
        acceptance_passed: allPassed
      }
    },
    { verbose, logger }
  );

  if (task.memory?.text) {
    await remember(
      task.memory.kind || 'solution',
      task.memory.text,
      {
        id: task.id,
        title: task.title,
        duration_ms: dur
      },
      { verbose, logger }
    );
  }

  return {
    status: allPassed ? 'ok' : 'partial',
    results,
    acceptance: resolvedAcceptance,
    duration_ms: dur
  };
}

async function processQueue(options = {}) {
  const { verbose = false, logger } = options;
  const log = getLogger(logger);

  await Promise.all(
    [Q, INBOX, RUNNING, DONE, FAILED, LOGS_DIR, TELEMETRY_DIR].map((dir) => ensureDir(dir))
  );

  let items = [];
  try {
    items = (await fs.readdir(INBOX)).filter((f) => /\.(json|ya?ml)$/i.test(f));
  } catch (error) {
    if (verbose) log.warn('Failed to read inbox:', error.message);
  }

  if (!items.length) {
    if (verbose) log.info('📭 Queue empty');
    return { processed: 0, items: [] };
  }

  log.info(`\n=== Local Orchestrator: Processing ${items.length} task(s) ===\n`);
  const processedItems = [];

  for (const file of items) {
    const fp = path.join(INBOX, file);
    const runningFp = path.join(RUNNING, file);

    await fs.rename(fp, runningFp);
    log.info(`🔄 Executing: ${file}`);

    let result;
    try {
      result = await execTask(runningFp, { verbose, logger });
    } catch (error) {
      result = { status: 'crashed', error: String(error), stack: error.stack };
    }

    let finalPath;
    if (result.status === 'ok' || result.status === 'partial') {
      finalPath = await move(runningFp, DONE);
      log.info(`✅ ${file}: ${result.status.toUpperCase()}`);
    } else {
      finalPath = await move(runningFp, FAILED);
      log.warn(
        `❌ ${file}: ${result.status.toUpperCase()} - ${result.reason || result.error || ''}`
      );
    }

    const logFile = path.join(
      LOGS_DIR,
      `local_${Date.now()}_${path.basename(file, path.extname(file))}.json`
    );
    await fs.writeFile(logFile, JSON.stringify(result, null, 2), 'utf8');

    if (verbose) {
      log.info(`📝 Log: ${logFile}`);
    }

    processedItems.push({ file, result, logFile, finalPath });
  }

  log.info(`\n=== Processed ${processedItems.length} task(s) ===\n`);
  return { processed: processedItems.length, items: processedItems };
}

async function runLoop(options = {}) {
  const {
    intervalMs = DEFAULT_INTERVAL_MS,
    signal,
    logger,
    verbose = false,
    onCycle
  } = options;

  const log = getLogger(logger);
  let active = true;

  const abortHandler = () => {
    active = false;
  };
  signal?.addEventListener('abort', abortHandler, { once: true });

  try {
    while (active && !signal?.aborted) {
      const cycleResult = await processQueue({ verbose, logger });
      onCycle?.(cycleResult);

      if (!active || signal?.aborted) break;

      try {
        await delay(intervalMs, undefined, { signal });
      } catch {
        break;
      }
    }
  } finally {
    signal?.removeEventListener('abort', abortHandler);
    log.info('🛑 Orchestrator loop stopped');
  }
}

export { execTask, processQueue, runLoop };

async function cliMain() {
  const logger = getLogger(consoleLogger);
  logger.info('🚀 Phase 7.2: Local Orchestrator & Delegation');
  logger.info(`Mode: ${CLI_OPTS.once ? 'ONCE' : 'CONTINUOUS'}`);
  logger.info(`Verbose: ${CLI_OPTS.verbose ? 'ON' : 'OFF'}`);
  logger.info('');

  if (CLI_OPTS.once) {
    await processQueue({ verbose: CLI_OPTS.verbose, logger });
    return;
  }

  logger.info('👀 Watching queue/inbox/ (Ctrl+C to stop)');
  logger.info('');

  const controller = new AbortController();
  const stop = () => controller.abort();
  process.on('SIGINT', stop);
  process.on('SIGTERM', stop);

  try {
    await runLoop({
      verbose: CLI_OPTS.verbose,
      logger,
      signal: controller.signal
    });
  } finally {
    process.off('SIGINT', stop);
    process.off('SIGTERM', stop);
  }
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  cliMain().catch((error) => {
    console.error('❌ Orchestrator crashed:', error);
    process.exitCode = 1;
  });
}

export default {
  execTask,
  processQueue,
  runLoop
};
