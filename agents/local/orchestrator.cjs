#!/usr/bin/env node
/**
 * Phase 7.2: Local Orchestrator & Delegation
 * Main execution loop - polls task queue, executes with guardrails, writes telemetry + memory
 *
 * CLC's new role: Write tiny task specs (JSON/YAML) to queue/inbox/
 * Local's role: Execute, learn, report back
 *
 * Usage:
 *   node agents/local/orchestrator.cjs [--once] [--verbose]
 *
 * Options:
 *   --once     Process one batch and exit (default: continuous polling)
 *   --verbose  Show detailed execution logs
 */

const fs = require('fs');
const cp = require('child_process');
const path = require('path');

// Load policy engine
const POLICY = require('./policy.cjs');

// Paths
const REPO_ROOT = path.resolve(__dirname, '../..');
const Q = path.join(REPO_ROOT, 'queue');
const INBOX = path.join(Q, 'inbox');
const RUNNING = path.join(Q, 'running');
const DONE = path.join(Q, 'done');
const FAILED = path.join(Q, 'failed');
const TELEMETRY_DIR = path.join(REPO_ROOT, 'g', 'telemetry');
const LOGS_DIR = path.join(REPO_ROOT, 'g', 'logs');

// CLI args
const args = process.argv.slice(2);
const ONCE = args.includes('--once');
const VERBOSE = args.includes('--verbose');

/**
 * Execute shell command with timeout and capture output
 */
function sh(cmd, argv = [], opts = {}) {
  const timeout = opts.timeout || 120000; // 2 minutes default
  const cwd = opts.cwd || REPO_ROOT;

  if (VERBOSE) {
    console.log(`[sh] ${cmd} ${argv.join(' ')}`);
  }

  try {
    return cp.spawnSync(cmd, argv, {
      stdio: 'pipe',
      encoding: 'utf8',
      timeout,
      cwd,
      shell: false
    });
  } catch (error) {
    return {
      status: 1,
      stdout: '',
      stderr: error.message
    };
  }
}

/**
 * Safe file read with fallback
 */
function safeRead(fp) {
  try {
    return fs.readFileSync(fp, 'utf8');
  } catch {
    return '';
  }
}

/**
 * Write telemetry entry (NDJSON format)
 */
function writeTelemetry(obj) {
  try {
    const entry = Object.assign({
      ts: new Date().toISOString(),
      task: 'local_exec',
      pass: 0,
      warn: 0,
      fail: 0,
      duration_ms: 0
    }, obj);

    const today = new Date().toISOString().slice(0, 10).replace(/-/g, '');
    const logFile = path.join(TELEMETRY_DIR, `${today}.log`);

    // Ensure directory exists
    if (!fs.existsSync(TELEMETRY_DIR)) {
      fs.mkdirSync(TELEMETRY_DIR, { recursive: true });
    }

    fs.appendFileSync(logFile, JSON.stringify(entry) + '\n');

    if (VERBOSE) {
      console.log('[telemetry]', entry);
    }
  } catch (error) {
    console.error('⚠️  Failed to write telemetry:', error.message);
  }
}

/**
 * Record memory entry via memory/index.cjs
 */
function remember(kind, text, meta = {}) {
  try {
    const memoryScript = path.join(REPO_ROOT, 'memory', 'index.cjs');
    if (!fs.existsSync(memoryScript)) {
      if (VERBOSE) console.log('[memory] Script not found, skipping');
      return;
    }

    const metaJson = JSON.stringify(meta);
    const result = sh('node', [
      memoryScript,
      '--remember',
      kind,
      text,
      '--meta',
      metaJson
    ], { timeout: 10000 });

    if (result.status !== 0 && VERBOSE) {
      console.log('[memory] Failed:', result.stderr);
    } else if (VERBOSE) {
      console.log(`[memory] Recorded ${kind}: ${text.slice(0, 50)}...`);
    }
  } catch (error) {
    if (VERBOSE) console.error('[memory] Error:', error.message);
  }
}

/**
 * Move file to target directory
 */
function move(fp, dir) {
  const base = path.basename(fp);
  const target = path.join(dir, base);
  fs.renameSync(fp, target);
  return target;
}

/**
 * Execute a single skill step
 */
function runSkill(step, taskId) {
  const { skill, args = [], optional = false, timeout } = step;

  if (VERBOSE) {
    console.log(`[skill] ${skill} ${args.join(' ')}`);
  }

  let result;

  switch (skill) {
    case 'bash':
      result = sh('bash', args, { timeout });
      break;

    case 'node':
      result = sh('node', args, { timeout });
      break;

    case 'git':
      const gitScript = path.join(__dirname, 'skills', 'git.sh');
      result = sh('bash', [gitScript, ...args], { timeout });
      break;

    case 'http':
      const httpScript = path.join(__dirname, 'skills', 'http.cjs');
      result = sh('node', [httpScript, ...args], { timeout });
      break;

    case 'ops_atomic':
      // Built-in integration with existing ops_atomic.sh
      const opsScript = path.join(REPO_ROOT, 'run', 'ops_atomic.sh');
      result = sh('bash', [opsScript, ...args], { timeout: timeout || 30000 });
      break;

    case 'reportbot':
      // Built-in integration with reportbot
      const reportbot = path.join(REPO_ROOT, 'agents', 'reportbot', 'index.cjs');
      result = sh('node', [reportbot, ...args], { timeout });
      break;

    case 'self_review':
      // Built-in integration with Phase 7.1
      const selfReview = path.join(REPO_ROOT, 'agents', 'reflection', 'self_review.cjs');
      result = sh('node', [selfReview, ...args], { timeout: timeout || 30000 });
      break;

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

/**
 * Execute a task from file
 */
function execTask(fp) {
  const raw = safeRead(fp);
  if (!raw) {
    return { status: 'invalid', reason: 'empty_file' };
  }

  let task;
  try {
    // Support both JSON and YAML (if yaml package available)
    if (raw.trim().startsWith('{')) {
      task = JSON.parse(raw);
    } else {
      // Try YAML (graceful fallback)
      try {
        const yaml = require('yaml');
        task = yaml.parse(raw);
      } catch {
        task = JSON.parse(raw); // Fall back to JSON
      }
    }
  } catch (error) {
    return { status: 'invalid', reason: 'parse_error', error: error.message };
  }

  // Policy check
  const decision = POLICY.assess(task);
  if (decision.blocked) {
    writeTelemetry({
      pass: 0,
      warn: 1,
      fail: 1,
      duration_ms: 0,
      meta: {
        reason: 'policy_block',
        id: task.id,
        policy_reason: decision.reason
      }
    });
    return { status: 'blocked', reason: decision.reason };
  }

  // Execute steps
  const start = Date.now();
  const results = [];
  let failed = false;

  for (const step of task.steps || []) {
    const result = runSkill(step, task.id);
    results.push(result);

    // Check for failure
    if (result.code !== 0 && !step.optional) {
      failed = true;
      const dur = Date.now() - start;

      writeTelemetry({
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
      });

      remember('error', `Task "${task.title}" failed at step ${result.step}`, {
        id: task.id,
        exit_code: result.code,
        stderr: result.stderr.slice(0, 200)
      });

      return { status: 'failed', results, failedAt: result.step };
    }
  }

  // Acceptance checks (lightweight - just check for existence/basic validation)
  const acceptance = (task.acceptance || []).map(rule => {
    // Simple existence checks for now
    let ok = true;
    if (rule.includes('exists under')) {
      const match = rule.match(/exists under (.+)/);
      if (match) {
        const pattern = match[1].trim();
        // Check if any files match the pattern
        const dir = path.dirname(pattern);
        const file = path.basename(pattern);
        try {
          const files = fs.readdirSync(path.join(REPO_ROOT, dir));
          ok = files.some(f => f.includes(file.replace('*', '')));
        } catch {
          ok = false;
        }
      }
    }
    return { rule, ok };
  });

  const allPassed = acceptance.every(a => a.ok);
  const dur = Date.now() - start;

  // Write success telemetry
  writeTelemetry({
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
  });

  // Record memory if specified
  if (task.memory?.text) {
    remember(
      task.memory.kind || 'solution',
      task.memory.text,
      {
        id: task.id,
        title: task.title,
        duration_ms: dur
      }
    );
  }

  return {
    status: allPassed ? 'ok' : 'partial',
    results,
    acceptance,
    duration_ms: dur
  };
}

/**
 * Process all tasks in inbox
 */
function processQueue() {
  // Ensure all directories exist
  [Q, INBOX, RUNNING, DONE, FAILED, LOGS_DIR, TELEMETRY_DIR].forEach(dir => {
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
  });

  // Get task files
  const items = fs.readdirSync(INBOX).filter(f =>
    /\.(json|ya?ml)$/i.test(f)
  );

  if (!items.length) {
    if (VERBOSE) console.log('📭 Queue empty');
    return 0;
  }

  console.log(`\n=== Local Orchestrator: Processing ${items.length} task(s) ===\n`);

  let processed = 0;
  for (const f of items) {
    const fp = path.join(INBOX, f);
    const runningFp = path.join(RUNNING, f);

    // Move to running
    fs.renameSync(fp, runningFp);

    console.log(`🔄 Executing: ${f}`);

    let result;
    try {
      result = execTask(runningFp);
    } catch (error) {
      result = {
        status: 'crashed',
        error: String(error),
        stack: error.stack
      };
    }

    // Move to done/failed
    let finalPath;
    if (result.status === 'ok' || result.status === 'partial') {
      finalPath = move(runningFp, DONE);
      console.log(`✅ ${f}: ${result.status.toUpperCase()}`);
    } else {
      finalPath = move(runningFp, FAILED);
      console.log(`❌ ${f}: ${result.status.toUpperCase()} - ${result.reason || result.error || ''}`);
    }

    // Write detailed log
    const logFile = path.join(LOGS_DIR, `local_${Date.now()}_${path.basename(f, path.extname(f))}.json`);
    fs.writeFileSync(logFile, JSON.stringify(result, null, 2));

    if (VERBOSE) {
      console.log(`📝 Log: ${logFile}`);
    }

    processed++;
  }

  console.log(`\n=== Processed ${processed} task(s) ===\n`);
  return processed;
}

/**
 * Main entry point
 */
function main() {
  console.log('🚀 Phase 7.2: Local Orchestrator & Delegation');
  console.log(`Mode: ${ONCE ? 'ONCE' : 'CONTINUOUS'}`);
  console.log(`Verbose: ${VERBOSE ? 'ON' : 'OFF'}`);
  console.log('');

  if (ONCE) {
    processQueue();
  } else {
    // Continuous mode (poll every 5 seconds)
    console.log('👀 Watching queue/inbox/ (Ctrl+C to stop)');
    console.log('');

    setInterval(() => {
      processQueue();
    }, 5000);

    // Also process immediately
    processQueue();
  }
}

// Run if called directly
if (require.main === module) {
  main();
}

module.exports = { execTask, processQueue };
