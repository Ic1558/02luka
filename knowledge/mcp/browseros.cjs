#!/usr/bin/env node

const fs = require('fs');
const { createRedisClient, createRedisSubscriber } = require('../util/redis_client.cjs');
const {
  evaluateDomains,
  isKillSwitchActive,
  recordAction,
  checkQuota,
} = require('../util/web_actions_log.cjs');

const REQUEST_CHANNEL = process.env.BROWSEROS_REQUEST_CHANNEL || 'ai.action.request';
const RESULT_CHANNEL = process.env.BROWSEROS_RESULT_CHANNEL || 'ai.action.result';
const DEFAULT_TIMEOUT_MS = Number(process.env.BROWSEROS_TIMEOUT_MS || 60000);
const DIRECT_ENDPOINT = process.env.BROWSEROS_ENDPOINT || 'http://127.0.0.1:8234/api/action';

const fetch = (...args) => import('node-fetch').then(({ default: fetchImpl }) => fetchImpl(...args));

const TOOL_DEFINITIONS = [
  {
    name: 'browseros.navigate',
    description: 'Navigate to a specific URL inside BrowserOS.',
    schema: {
      type: 'object',
      required: ['url'],
      properties: {
        url: { type: 'string', format: 'uri' },
        allowDomains: { type: 'array', items: { type: 'string' } },
        timeoutMs: { type: 'number' },
      },
    },
  },
  {
    name: 'browseros.click',
    description: 'Click an element by selector or visible text.',
    schema: {
      type: 'object',
      required: ['selector'],
      properties: {
        selector: { type: 'string' },
        text: { type: 'string' },
        timeoutMs: { type: 'number' },
      },
    },
  },
  {
    name: 'browseros.type',
    description: 'Type into an input field, optionally pressing enter.',
    schema: {
      type: 'object',
      required: ['selector', 'text'],
      properties: {
        selector: { type: 'string' },
        text: { type: 'string' },
        enter: { type: 'boolean' },
        delayMs: { type: 'number' },
        timeoutMs: { type: 'number' },
      },
    },
  },
  {
    name: 'browseros.extract',
    description: 'Extract content from the current page.',
    schema: {
      type: 'object',
      properties: {
        selectors: { type: 'array', items: { type: 'string' } },
        region: { type: 'string' },
        timeoutMs: { type: 'number' },
      },
    },
  },
  {
    name: 'browseros.workflow',
    description: 'Execute a multi-step BrowserOS plan with guardrails.',
    schema: {
      type: 'object',
      required: ['plan'],
      properties: {
        plan: {
          type: 'array',
          items: {
            type: 'object',
            properties: {
              op: { type: 'string' },
              url: { type: 'string' },
              selector: { type: 'string' },
              text: { type: 'string' },
              enter: { type: 'boolean' },
            },
            required: ['op'],
          },
        },
        allowDomains: { type: 'array', items: { type: 'string' } },
        timeoutMs: { type: 'number' },
        validateOnly: { type: 'boolean' },
      },
    },
  },
];

function buildRequest(tool, params = {}, options = {}) {
  const id = options.id || `act_${new Date().toISOString().replace(/[-:.TZ]/g, '').slice(0, 14)}_${Math.random()
    .toString(16)
    .slice(2, 8)}`;
  return {
    id,
    caller: options.caller || process.env.MCP_CALLER || 'MCP',
    tool,
    params,
    ts: new Date().toISOString(),
  };
}

async function waitForResult(subscriber, id, timeoutMs = DEFAULT_TIMEOUT_MS) {
  await subscriber.subscribe(RESULT_CHANNEL);
  return new Promise((resolve, reject) => {
    let timer = setTimeout(() => {
      cleanup();
      reject(new Error(`Timed out waiting for BrowserOS result ${id}`));
    }, timeoutMs);

    const cleanup = () => {
      if (timer) {
        clearTimeout(timer);
        timer = null;
      }
      subscriber.removeListener('message', onMessage);
      subscriber.unsubscribe(RESULT_CHANNEL).catch(() => {});
    };

    const onMessage = (channel, message) => {
      if (channel !== RESULT_CHANNEL) {
        return;
      }
      try {
        const payload = JSON.parse(message);
        if (payload && payload.id === id) {
          cleanup();
          resolve(payload);
        }
      } catch (err) {
        cleanup();
        reject(err);
      }
    };

    subscriber.on('message', onMessage);
  });
}

async function callViaRedis(tool, params = {}, options = {}) {
  const request = buildRequest(tool, params, options);
  const redis = createRedisClient(options);
  const subscriber = createRedisSubscriber(options);
  try {
    await subscriber.connect();
    const waiter = waitForResult(subscriber, request.id, options.timeoutMs || DEFAULT_TIMEOUT_MS);
    await redis.publish(REQUEST_CHANNEL, JSON.stringify(request));
    const result = await waiter;
    return result;
  } finally {
    await subscriber.quit();
    await redis.quit();
  }
}

async function callDirect(tool, params = {}, options = {}) {
  const request = buildRequest(tool, params, options);
  const started = Date.now();
  let ok = true;
  let error;
  let result;
  let httpStatus = null;
  let domainCheck = { planDomains: [], blocked: [], allowlist: { raw: [] }, effectiveAllow: [] };
  let quota = null;

  if (isKillSwitchActive()) {
    ok = false;
    error = 'BrowserOS kill-switch enabled (browseros.off present).';
  } else {
    quota = checkQuota(request.caller || 'CLI');
    if (!quota.ok) {
      ok = false;
      error = `Quota exceeded for caller ${request.caller || 'CLI'} (${quota.used}/${quota.limit} actions this hour)`;
    } else {
      try {
        domainCheck = evaluateDomains(tool, params);
      } catch (err) {
        ok = false;
        error = `Failed to evaluate domain policy: ${err.message}`;
      }
      if (ok && domainCheck.blocked.length > 0) {
        const blocked = domainCheck.blocked.map((item) => `${item.domain}:${item.reason}`).join(', ');
        ok = false;
        error = `Domain policy violation: ${blocked}`;
      }
      if (ok) {
        try {
          const response = await fetch(DIRECT_ENDPOINT, {
            method: 'POST',
            headers: { 'content-type': 'application/json' },
            body: JSON.stringify({ tool, params }),
          });
          httpStatus = response.status;
          const text = await response.text();
          let data;
          try {
            data = text ? JSON.parse(text) : {};
          } catch (err) {
            data = { ok: false, raw: text };
          }
          const success = response.ok && (data.ok !== false);
          if (!success) {
            ok = false;
            error = data.error || `HTTP ${response.status}`;
            result = data;
          } else {
            result = data;
          }
        } catch (err) {
          ok = false;
          error = err.message || 'BrowserOS direct call failed';
        }
      }
    }
  }

  const finished = Date.now();
  const entry = {
    ts: new Date(finished).toISOString(),
    id: request.id,
    caller: request.caller,
    tool,
    status: ok ? 'ok' : 'error',
    ok,
    ms: finished - started,
    domain: domainCheck.planDomains[0] || null,
    domains: domainCheck.planDomains,
    allow: domainCheck.effectiveAllow,
    dryRun: Boolean(params.validateOnly),
    result: ok ? result : undefined,
    error,
    meta: {
      via: 'direct-cli',
      endpoint: DIRECT_ENDPOINT,
      httpStatus,
      quota,
      blocked: domainCheck.blocked,
    },
  };
  recordAction(entry);
  if (!ok) {
    const err = new Error(error || 'BrowserOS direct call failed');
    err.details = result;
    throw err;
  }
  return result;
}

function parseArgs(argv) {
  const args = {};
  for (let i = 2; i < argv.length; i += 1) {
    const token = argv[i];
    if (token === '--selftest') {
      args.selftest = true;
    } else if (token === '--direct') {
      args.direct = true;
      args.payload = argv[++i];
    } else if (token === '--tool') {
      args.tool = argv[++i];
    } else if (token === '--params') {
      args.params = argv[++i];
    } else if (token === '--caller') {
      args.caller = argv[++i];
    } else if (token === '--timeout') {
      args.timeoutMs = Number(argv[++i]);
    } else if (token === '--describe') {
      args.describe = true;
    }
  }
  return args;
}

async function runSelfTest() {
  const workflow = {
    plan: [
      { op: 'navigate', url: 'https://example.com' },
      { op: 'click', selector: 'a.demo' },
    ],
    allowDomains: ['example.com'],
    validateOnly: true,
  };
  const evaluation = evaluateDomains('browseros.workflow', workflow);
  if (evaluation.blocked.length > 0) {
    throw new Error('Selftest: domains unexpectedly blocked');
  }
  const quota = checkQuota('SELFTEST');
  if (!quota.ok) {
    throw new Error('Selftest: quota unexpectedly exceeded');
  }
  console.log('Selftest passed: domain evaluation and quota check.');
}

function describeTools() {
  return TOOL_DEFINITIONS.map((tool) => ({ name: tool.name, description: tool.description, schema: tool.schema }));
}

async function main() {
  const args = parseArgs(process.argv);
  if (args.describe) {
    console.log(JSON.stringify(describeTools(), null, 2));
    return;
  }
  if (args.selftest) {
    await runSelfTest();
    return;
  }
  if (args.direct) {
    const payloadRaw = args.payload || fs.readFileSync(0, 'utf8');
    const payload = JSON.parse(payloadRaw);
    const tool = payload.tool || args.tool;
    const params = payload.params || JSON.parse(args.params || '{}');
    const caller = payload.caller || args.caller || 'CLI';
    const result = await callDirect(tool, params, { caller, timeoutMs: args.timeoutMs });
    console.log(JSON.stringify(result, null, 2));
    return;
  }
  if (!args.tool) {
    throw new Error('Tool name required (use --tool).');
  }
  const params = args.params ? JSON.parse(args.params) : {};
  const result = await callViaRedis(args.tool, params, {
    caller: args.caller,
    timeoutMs: args.timeoutMs,
  });
  console.log(JSON.stringify(result, null, 2));
}

if (require.main === module) {
  main().catch((err) => {
    console.error(err.stack || err.message || err);
    process.exitCode = 1;
  });
}

module.exports = {
  TOOL_DEFINITIONS,
  callViaRedis,
  callDirect,
  buildRequest,
  describeTools,
};
