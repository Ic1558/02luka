#!/usr/bin/env node

const { createRedisClient, createRedisSubscriber } = require('../util/redis_client.cjs');
const {
  evaluateDomains,
  isKillSwitchActive,
  recordAction,
  checkQuota,
} = require('../util/web_actions_log.cjs');

const fetch = (...args) => import('node-fetch').then(({ default: fetchImpl }) => fetchImpl(...args));

const REQUEST_CHANNEL = process.env.BROWSEROS_REQUEST_CHANNEL || 'ai.action.request';
const RESULT_CHANNEL = process.env.BROWSEROS_RESULT_CHANNEL || 'ai.action.result';
const DIRECT_ENDPOINT = process.env.BROWSEROS_ENDPOINT || 'http://127.0.0.1:8234/api/action';

async function invokeBrowserOS(tool, params) {
  if (params && params.validateOnly) {
    return {
      ok: true,
      dryRun: true,
      message: 'Plan validated without execution.',
    };
  }
  const response = await fetch(DIRECT_ENDPOINT, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ tool, params }),
  });
  const text = await response.text();
  let payload;
  try {
    payload = text ? JSON.parse(text) : {};
  } catch (err) {
    payload = { ok: false, raw: text };
  }
  const ok = response.ok && (payload.ok !== false);
  if (!ok) {
    const message = payload.error || `BrowserOS HTTP ${response.status}`;
    const error = new Error(message);
    error.details = payload;
    error.status = response.status;
    throw error;
  }
  return payload;
}

async function handleRequest(raw) {
  const started = Date.now();
  let request;
  try {
    request = JSON.parse(raw);
  } catch (err) {
    const finished = Date.now();
    recordAction({
      ts: new Date(finished).toISOString(),
      id: 'invalid',
      caller: 'unknown',
      tool: 'browseros.invalid',
      status: 'error',
      ok: false,
      ms: finished - started,
      domain: null,
      domains: [],
      allow: [],
      dryRun: false,
      error: `Invalid JSON payload: ${err.message}`,
      meta: { raw },
    });
    return {
      id: null,
      ok: false,
      error: `Invalid JSON payload: ${err.message}`,
      meta: { raw },
    };
  }

  const id = request.id || `act_${Date.now()}`;
  const caller = request.caller || 'unknown';
  const tool = request.tool || 'browseros.unknown';
  const params = request.params || {};

  let ok = true;
  let error;
  let result;
  let domainCheck = { planDomains: [], blocked: [], allowlist: { raw: [] }, effectiveAllow: [] };
  let quota = null;

  if (!request.tool) {
    ok = false;
    error = 'Missing tool name in request.';
  } else if (isKillSwitchActive()) {
    ok = false;
    error = 'BrowserOS kill-switch active (browseros.off present).';
  } else {
    quota = checkQuota(caller);
    if (!quota.ok) {
      ok = false;
      error = `Quota exceeded for caller ${caller} (${quota.used}/${quota.limit} per hour).`;
    } else {
      try {
        domainCheck = evaluateDomains(tool, params);
      } catch (err) {
        domainCheck = { planDomains: [], blocked: [], allowlist: { raw: [] }, effectiveAllow: [] };
        ok = false;
        error = `Failed to evaluate domain policy: ${err.message}`;
      }
      if (ok && domainCheck.blocked.length > 0) {
        ok = false;
        error = `Blocked domains: ${domainCheck.blocked.map((item) => `${item.domain}:${item.reason}`).join(', ')}`;
      }
      if (ok) {
        try {
          result = await invokeBrowserOS(tool, params);
        } catch (err) {
          ok = false;
          error = err.message || 'BrowserOS invocation failed.';
          result = err.details || null;
        }
      }
    }
  }

  const finished = Date.now();
  const entry = {
    ts: new Date(finished).toISOString(),
    id,
    caller,
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
      via: 'redis-worker',
      blocked: domainCheck.blocked,
      allowlistSource: domainCheck.allowlist.raw,
      quota,
    },
  };
  recordAction(entry);

  return {
    id,
    ok,
    result: ok ? result : undefined,
    error,
    meta: {
      durationMs: entry.ms,
      domains: entry.domains,
      allow: entry.allow,
      dryRun: entry.dryRun,
    },
  };
}

async function start() {
  const subscriber = createRedisSubscriber();
  const publisher = createRedisClient();
  await subscriber.connect();
  await subscriber.subscribe(REQUEST_CHANNEL);
  console.log(`[BrowserOS] Worker listening on ${REQUEST_CHANNEL}`);

  subscriber.on('message', async (channel, message) => {
    if (channel !== REQUEST_CHANNEL) {
      return;
    }
    let response;
    try {
      response = await handleRequest(message);
    } catch (err) {
      response = {
        id: null,
        ok: false,
        error: err.message || 'Unhandled BrowserOS worker error',
      };
    }
    try {
      await publisher.publish(RESULT_CHANNEL, JSON.stringify({
        ...response,
        ts: new Date().toISOString(),
      }));
    } catch (err) {
      console.error('Failed to publish BrowserOS result:', err);
    }
  });
}

if (require.main === module) {
  start().catch((err) => {
    console.error('BrowserOS worker failed to start:', err);
    process.exitCode = 1;
  });
}

module.exports = {
  start,
  handleRequest,
  invokeBrowserOS,
};
