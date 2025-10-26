#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const os = require('os');
const { redact, summarize } = require('./redact.cjs');

const ROOT_DIR = path.resolve(__dirname, '..', '..');
const REPORT_DIR = path.join(ROOT_DIR, 'g', 'reports');
const ACTION_LOG = path.join(REPORT_DIR, 'web_actions.jsonl');
const PERF_LOG = path.join(REPORT_DIR, 'query_perf.jsonl');
const CONFIG_DIR = path.join(ROOT_DIR, '02luka', 'config');
const ALLOWLIST_FILE = path.join(CONFIG_DIR, 'browseros.allow');
const QUOTA_FILE = path.join(CONFIG_DIR, 'browseros.quota.json');
const KILL_SWITCH_FILE = path.join(CONFIG_DIR, 'browseros.off');

const DEFAULT_QUOTAS = {
  CLS: 200,
  Mary: 100,
  Paula: 100,
  Lisa: 100,
  '*': 60,
};

let allowlistCache = { mtimeMs: 0, patterns: [], allowAll: false, raw: [] };
let quotaCache = { mtimeMs: 0, quotas: DEFAULT_QUOTAS };
const quotaWindowMs = 60 * 60 * 1000;
const quotaUsage = new Map();

function ensureDir(filePath) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
}

function escapeRegex(str) {
  return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function compileAllowEntry(entry) {
  const trimmed = entry.trim();
  if (!trimmed || trimmed.startsWith('#')) {
    return null;
  }
  if (trimmed === '*' || trimmed.toLowerCase() === 'all') {
    return { type: 'wildcard', value: '*' };
  }
  if (trimmed.startsWith('*.')) {
    return { type: 'suffix', value: trimmed.slice(1).toLowerCase() };
  }
  if (trimmed.startsWith('.')) {
    return { type: 'suffix', value: trimmed.toLowerCase() };
  }
  if (trimmed.includes('*')) {
    const regex = new RegExp(`^${trimmed.split('*').map((part) => escapeRegex(part)).join('.*')}$`, 'i');
    return { type: 'regex', value: regex };
  }
  return { type: 'exact', value: trimmed.toLowerCase() };
}

function loadAllowlist() {
  try {
    const stat = fs.statSync(ALLOWLIST_FILE);
    if (stat.mtimeMs !== allowlistCache.mtimeMs) {
      const raw = fs.readFileSync(ALLOWLIST_FILE, 'utf8').split(/\r?\n/);
      const patterns = raw
        .map((line) => compileAllowEntry(line))
        .filter(Boolean);
      const allowAll = patterns.some((p) => p.type === 'wildcard');
      allowlistCache = { mtimeMs: stat.mtimeMs, patterns, allowAll, raw };
    }
  } catch (err) {
    if (err.code === 'ENOENT') {
      allowlistCache = { mtimeMs: 0, patterns: [], allowAll: false, raw: [] };
    } else {
      throw err;
    }
  }
  return allowlistCache;
}

function loadQuotas() {
  try {
    const stat = fs.statSync(QUOTA_FILE);
    if (stat.mtimeMs !== quotaCache.mtimeMs) {
      const content = JSON.parse(fs.readFileSync(QUOTA_FILE, 'utf8'));
      quotaCache = { mtimeMs: stat.mtimeMs, quotas: { ...DEFAULT_QUOTAS, ...content } };
    }
  } catch (err) {
    if (err.code === 'ENOENT') {
      quotaCache = { mtimeMs: 0, quotas: DEFAULT_QUOTAS };
    } else {
      throw err;
    }
  }
  return quotaCache.quotas;
}

function isKillSwitchActive() {
  try {
    const raw = fs.readFileSync(KILL_SWITCH_FILE, 'utf8');
    const normalized = raw.trim().toLowerCase();
    if (!normalized) {
      return false;
    }
    return !['0', 'false', 'off', 'disable', 'disabled'].includes(normalized);
  } catch (err) {
    if (err.code === 'ENOENT') {
      return false;
    }
    throw err;
  }
}

function testDomainAgainstPattern(domain, pattern) {
  const host = domain.toLowerCase();
  switch (pattern.type) {
    case 'wildcard':
      return true;
    case 'exact':
      return host === pattern.value;
    case 'suffix': {
      const suffix = pattern.value.startsWith('.') ? pattern.value.slice(1) : pattern.value;
      return host === suffix || host.endsWith(`.${suffix}`);
    }
    case 'regex':
      return pattern.value.test(host);
    default:
      return false;
  }
}

function compilePatterns(items = []) {
  return items.map((entry) => compileAllowEntry(entry)).filter(Boolean);
}

function matchDomain(domain, patterns) {
  if (!patterns || patterns.length === 0) {
    return false;
  }
  return patterns.some((pattern) => testDomainAgainstPattern(domain, pattern));
}

function normalizeDomain(domain) {
  try {
    const trimmed = domain.trim();
    if (!trimmed) return null;
    const url = trimmed.includes('://') ? new URL(trimmed) : new URL(`https://${trimmed}`);
    return url.hostname.toLowerCase();
  } catch (err) {
    return null;
  }
}

function collectPlanDomains(tool, params = {}) {
  const domains = new Set();
  const recordDomain = (value) => {
    const normalized = normalizeDomain(value);
    if (normalized) {
      domains.add(normalized);
    }
  };

  const name = tool.replace(/^browseros\.?/, '').toLowerCase();
  if (name === 'workflow' && Array.isArray(params.plan)) {
    for (const step of params.plan) {
      if (!step || typeof step !== 'object') continue;
      if (step.url) {
        recordDomain(step.url);
      }
      if (step.link) {
        recordDomain(step.link);
      }
    }
  } else if (params.url) {
    recordDomain(params.url);
  }

  if (Array.isArray(params.allowDomains)) {
    for (const item of params.allowDomains) {
      const normalized = normalizeDomain(item);
      if (normalized) {
        domains.add(normalized);
      }
    }
  }

  return Array.from(domains);
}

function evaluateDomains(tool, params = {}) {
  const allowlist = loadAllowlist();
  const configPatterns = allowlist.patterns;
  const requestPatterns = compilePatterns(params.allowDomains || []);
  const planDomains = collectPlanDomains(tool, params);

  const blocked = [];
  const effectiveAllow = new Set();

  for (const pattern of requestPatterns) {
    if (pattern.type === 'exact') {
      effectiveAllow.add(pattern.value);
    } else if (pattern.type === 'suffix') {
      effectiveAllow.add(pattern.value.startsWith('.') ? pattern.value.slice(1) : pattern.value);
    }
  }

  for (const domain of planDomains) {
    const allowedByConfig = allowlist.allowAll || matchDomain(domain, configPatterns);
    const allowedByRequest = requestPatterns.length === 0 || matchDomain(domain, requestPatterns);
    if (!allowedByConfig) {
      blocked.push({ domain, reason: 'not_in_allowlist' });
    } else if (!allowedByRequest) {
      blocked.push({ domain, reason: 'not_in_request' });
    }
  }

  for (const domain of planDomains) {
    effectiveAllow.add(domain);
  }

  const disallowedRequested = [];
  for (const raw of params.allowDomains || []) {
    const normalized = normalizeDomain(raw);
    if (!normalized) continue;
    if (!(allowlist.allowAll || matchDomain(normalized, configPatterns))) {
      disallowedRequested.push(normalized);
    }
  }

  if (disallowedRequested.length > 0) {
    blocked.push(...disallowedRequested.map((domain) => ({ domain, reason: 'request_not_allowed' })));
  }

  return {
    planDomains,
    blocked,
    allowlist,
    effectiveAllow: Array.from(effectiveAllow),
  };
}

function pruneQuotaWindow(entries, now) {
  return entries.filter((ts) => ts > now - quotaWindowMs);
}

function checkQuota(caller, now = Date.now()) {
  const quotas = loadQuotas();
  const limit = quotas[caller] ?? quotas['*'];
  if (!limit || limit <= 0) {
    return { ok: true, used: 0, limit: null };
  }
  const existing = quotaUsage.get(caller) || [];
  const pruned = pruneQuotaWindow(existing, now);
  if (pruned.length >= limit) {
    quotaUsage.set(caller, pruned);
    return { ok: false, used: pruned.length, limit };
  }
  pruned.push(now);
  quotaUsage.set(caller, pruned);
  return { ok: true, used: pruned.length, limit };
}

function appendJsonl(filePath, data) {
  ensureDir(filePath);
  fs.appendFileSync(filePath, `${JSON.stringify(data)}${os.EOL}`);
}

function recordPerformance(entry) {
  const payload = {
    ts: entry.ts,
    id: entry.id,
    source: 'browseros',
    caller: entry.caller,
    tool: entry.tool,
    status: entry.status,
    totalMs: entry.ms,
    slow: entry.ms >= (entry.slowThreshold || 2000),
  };
  appendJsonl(PERF_LOG, payload);
}

function recordAction(entry) {
  const sanitized = {
    ts: entry.ts,
    id: entry.id,
    caller: entry.caller,
    tool: entry.tool,
    status: entry.status,
    ok: entry.ok,
    ms: entry.ms,
    domain: entry.domain || null,
    domains: entry.domains || [],
    allow: entry.allow || [],
    dryRun: Boolean(entry.dryRun),
    error: entry.error ? summarize(redact(entry.error), 300) : undefined,
    result: entry.result ? summarize(redact(entry.result), 300) : undefined,
    meta: entry.meta ? redact(entry.meta) : undefined,
  };
  appendJsonl(ACTION_LOG, sanitized);
  recordPerformance(sanitized);
  return sanitized;
}

module.exports = {
  ACTION_LOG,
  PERF_LOG,
  CONFIG_DIR,
  loadAllowlist,
  evaluateDomains,
  isKillSwitchActive,
  recordAction,
  checkQuota,
  collectPlanDomains,
};

if (require.main === module) {
  const preview = {
    ts: new Date().toISOString(),
    id: 'act_demo',
    caller: 'CLI',
    tool: 'browseros.workflow',
    status: 'ok',
    ok: true,
    ms: 1234,
    domain: 'example.com',
    domains: ['example.com'],
    allow: ['example.com'],
    dryRun: false,
    result: { data: 'demo' },
  };
  console.log('Writing sample log entry to', ACTION_LOG);
  recordAction(preview);
}
