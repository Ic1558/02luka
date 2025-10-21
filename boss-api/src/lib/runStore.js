import { randomUUID } from 'node:crypto';
import { readStore, writeStore } from './db.js';

function clone(value) {
  return structuredClone(value);
}

function normalizeRun(run) {
  if (!run) return null;
  return {
    id: run.id,
    title: run.title,
    status: run.status,
    agent: run.agent,
    riskScore: Number(run.riskScore) || 0,
    createdAt: run.createdAt,
    startedAt: run.startedAt || null,
    completedAt: run.completedAt || null,
    summary: run.summary || null,
    tokensUsed: Number(run.tokensUsed) || 0,
    tokensSaved: Number(run.tokensSaved) || 0,
    durationMs: Number(run.durationMs) || 0,
    input: clone(run.input ?? {}),
    metadata: clone(run.metadata ?? {})
  };
}

function normalizeStep(step) {
  return {
    id: step.id,
    runId: step.runId,
    idx: Number.isInteger(step.idx) ? step.idx : 0,
    title: step.title,
    status: step.status || 'pending',
    startedAt: step.startedAt || null,
    completedAt: step.completedAt || null,
    log: step.log || null,
    artifacts: clone(step.artifacts ?? [])
  };
}

function normalizeLog(log) {
  return {
    id: log.id,
    runId: log.runId,
    timestamp: log.timestamp,
    level: log.level,
    message: log.message,
    data: clone(log.data ?? null)
  };
}

function normalizeMemoryHit(hit) {
  return {
    id: hit.id,
    runId: hit.runId,
    memoryId: hit.memoryId,
    title: hit.title,
    snippet: hit.snippet,
    score: Number(hit.score) || 0,
    kind: hit.kind || 'memory',
    createdAt: hit.createdAt
  };
}

function normalizeApproval(approval) {
  return {
    id: approval.id,
    runId: approval.runId,
    status: approval.status,
    requestedBy: approval.requestedBy,
    requestedAt: approval.requestedAt,
    reason: approval.reason || null,
    decidedAt: approval.decidedAt || null,
    decidedBy: approval.decidedBy || null,
    decisionNote: approval.decisionNote || null,
    riskScore: Number(approval.riskScore) || 0
  };
}

function ensureTimestamp(value) {
  if (!value) return null;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date.toISOString();
}

export async function createRun({
  title,
  agent = 'codex',
  riskScore = 0,
  summary = null,
  status = 'queued',
  input = {},
  metadata = {}
}) {
  if (!title || typeof title !== 'string') {
    throw new Error('title is required');
  }
  const id = randomUUID();
  const now = new Date().toISOString();
  const runRecord = {
    id,
    title,
    status,
    agent,
    riskScore: Number(riskScore) || 0,
    createdAt: now,
    startedAt: null,
    completedAt: null,
    summary: summary || null,
    tokensUsed: 0,
    tokensSaved: 0,
    durationMs: 0,
    input: clone(input ?? {}),
    metadata: clone(metadata ?? {})
  };

  await writeStore((store) => {
    store.runs.push(runRecord);
  });

  return normalizeRun(runRecord);
}

export async function updateRun(runId, updates = {}) {
  if (!updates || typeof updates !== 'object') {
    return getRunById(runId);
  }

  let found = false;
  await writeStore((store) => {
    const run = store.runs.find((item) => item.id === runId);
    if (!run) {
      return;
    }
    found = true;

    const fields = new Map([
      ['status', 'status'],
      ['agent', 'agent'],
      ['riskScore', 'riskScore'],
      ['summary', 'summary'],
      ['tokensUsed', 'tokensUsed'],
      ['tokensSaved', 'tokensSaved'],
      ['durationMs', 'durationMs'],
      ['startedAt', 'startedAt'],
      ['completedAt', 'completedAt'],
      ['input', 'input'],
      ['metadata', 'metadata']
    ]);

    for (const [key, field] of fields.entries()) {
      if (!(key in updates)) continue;
      let value = updates[key];
      if (['riskScore', 'tokensUsed', 'tokensSaved', 'durationMs'].includes(key)) {
        value = Number(value) || 0;
      } else if (['input', 'metadata'].includes(key)) {
        value = clone(value ?? {});
      } else if (['startedAt', 'completedAt'].includes(key)) {
        value = ensureTimestamp(value);
      }
      if (value === undefined) continue;
      run[field] = value;
    }
  });

  if (!found) {
    return null;
  }

  return getRunById(runId);
}

export async function listRuns({ limit = 50, status, agent, search } = {}) {
  return readStore((store) => {
    let collection = store.runs.slice();

    if (status) {
      collection = collection.filter((run) => run.status === status);
    }
    if (agent) {
      collection = collection.filter((run) => run.agent === agent);
    }
    if (search) {
      const query = search.toLowerCase();
      collection = collection.filter((run) => {
        return (
          (run.title || '').toLowerCase().includes(query) ||
          (run.id || '').toLowerCase().includes(query) ||
          (run.agent || '').toLowerCase().includes(query) ||
          (run.summary || '').toLowerCase().includes(query)
        );
      });
    }

    collection.sort((a, b) => {
      const left = new Date(a.createdAt || 0).getTime();
      const right = new Date(b.createdAt || 0).getTime();
      return right - left;
    });

    return collection.slice(0, Number(limit) || 50).map((item) => normalizeRun(item));
  });
}

export async function getRunById(runId, { includeLogs = 200 } = {}) {
  return readStore((store) => {
    const run = store.runs.find((item) => item.id === runId);
    if (!run) {
      return null;
    }

    const steps = store.runSteps
      .filter((step) => step.runId === runId)
      .sort((a, b) => a.idx - b.idx)
      .map((step) => normalizeStep(step));

    const logs = store.runLogs
      .filter((entry) => entry.runId === runId)
      .sort((a, b) => new Date(a.timestamp || 0) - new Date(b.timestamp || 0));

    const limitedLogs = logs.slice(-Math.max(0, Number(includeLogs) || 0)).map((entry) => normalizeLog(entry));

    const memoryHits = store.memoryHits
      .filter((hit) => hit.runId === runId)
      .sort((a, b) => {
        if (b.score !== a.score) {
          return b.score - a.score;
        }
        return new Date(b.createdAt || 0) - new Date(a.createdAt || 0);
      })
      .map((hit) => normalizeMemoryHit(hit));

    const approvals = store.approvals
      .filter((approval) => approval.runId === runId)
      .sort((a, b) => new Date(b.requestedAt || 0) - new Date(a.requestedAt || 0))
      .map((approval) => normalizeApproval(approval));

    return {
      ...normalizeRun(run),
      steps,
      logs: limitedLogs,
      memoryHits,
      approvals
    };
  });
}

export async function addRunSteps(runId, steps = []) {
  if (!Array.isArray(steps) || steps.length === 0) {
    return getRunById(runId);
  }

  let updated = false;
  await writeStore((store) => {
    const run = store.runs.find((item) => item.id === runId);
    if (!run) {
      return;
    }

    for (const step of steps) {
      const id = step.id || randomUUID();
      const record = {
        id,
        runId,
        idx: Number.isInteger(step.idx) ? step.idx : 0,
        title: step.title,
        status: step.status || 'pending',
        startedAt: ensureTimestamp(step.startedAt),
        completedAt: ensureTimestamp(step.completedAt),
        log: step.log || null,
        artifacts: clone(step.artifacts ?? [])
      };

      const existingIndex = store.runSteps.findIndex((item) => item.id === id);
      if (existingIndex >= 0) {
        store.runSteps[existingIndex] = record;
      } else {
        store.runSteps.push(record);
      }
      updated = true;
    }
  });

  if (!updated) {
    return null;
  }

  return getRunById(runId);
}

export async function appendRunLogs(runId, entries = []) {
  if (!Array.isArray(entries) || entries.length === 0) {
    return { inserted: 0 };
  }

  let inserted = 0;
  await writeStore((store) => {
    const run = store.runs.find((item) => item.id === runId);
    if (!run) {
      return;
    }

    for (const entry of entries) {
      const logRecord = {
        id: randomUUID(),
        runId,
        timestamp: ensureTimestamp(entry.timestamp) || new Date().toISOString(),
        level: (entry.level || 'info').toLowerCase(),
        message: entry.message || '',
        data: clone(entry.data ?? null)
      };
      store.runLogs.push(logRecord);
      inserted += 1;
    }

    // Keep logs capped to 2000 entries per run to avoid unbounded growth
    const runLogs = store.runLogs.filter((item) => item.runId === runId);
    if (runLogs.length > 2000) {
      const overflow = runLogs.length - 2000;
      const sorted = runLogs
        .slice()
        .sort((a, b) => new Date(a.timestamp || 0) - new Date(b.timestamp || 0));
      const toRemove = new Set(sorted.slice(0, overflow).map((item) => item.id));
      store.runLogs = store.runLogs.filter((item) => !toRemove.has(item.id));
    }
  });

  return { inserted };
}

export async function recordMemoryHits(runId, hits = []) {
  if (!Array.isArray(hits) || hits.length === 0) {
    return getRunById(runId);
  }

  let updated = false;
  await writeStore((store) => {
    const run = store.runs.find((item) => item.id === runId);
    if (!run) {
      return;
    }

    for (const hit of hits) {
      const id = hit.id || randomUUID();
      const record = {
        id,
        runId,
        memoryId: hit.memoryId,
        title: hit.title || null,
        snippet: hit.snippet || null,
        score: Number(hit.score) || 0,
        kind: hit.kind || 'memory',
        createdAt: ensureTimestamp(hit.createdAt) || new Date().toISOString()
      };

      const existingIndex = store.memoryHits.findIndex((item) => item.id === id);
      if (existingIndex >= 0) {
        store.memoryHits[existingIndex] = record;
      } else {
        store.memoryHits.push(record);
      }
      updated = true;
    }
  });

  if (!updated) {
    return null;
  }

  return getRunById(runId);
}

export async function createApproval({
  runId,
  requestedBy,
  reason,
  riskScore = 0
}) {
  const id = randomUUID();
  const now = new Date().toISOString();
  const approvalRecord = {
    id,
    runId,
    status: 'pending',
    requestedBy: requestedBy || 'system',
    requestedAt: now,
    reason: reason || null,
    decidedAt: null,
    decidedBy: null,
    decisionNote: null,
    riskScore: Number(riskScore) || 0
  };

  await writeStore((store) => {
    store.approvals.push(approvalRecord);
  });

  return normalizeApproval(approvalRecord);
}

export async function decideApproval(approvalId, { status, decidedBy, decisionNote }) {
  const normalizedStatus = status === 'approved' ? 'approved' : status === 'denied' ? 'denied' : null;
  if (!normalizedStatus) {
    const error = new Error('Invalid approval status. Use approved or denied.');
    error.status = 400;
    error.code = 'invalid_status';
    throw error;
  }

  let record = null;
  await writeStore((store) => {
    const approval = store.approvals.find((item) => item.id === approvalId);
    if (!approval) {
      return;
    }
    approval.status = normalizedStatus;
    approval.decidedAt = new Date().toISOString();
    approval.decidedBy = decidedBy || 'system';
    approval.decisionNote = decisionNote || null;
    record = clone(approval);
  });

  return record ? normalizeApproval(record) : null;
}

export async function listMemoryItems({ kind, search, limit = 25 } = {}) {
  return readStore((store) => {
    let items = store.memoryItems.slice();

    if (kind) {
      items = items.filter((item) => item.kind === kind);
    }
    if (search) {
      const query = search.toLowerCase();
      items = items.filter((item) => {
        return (
          (item.title || '').toLowerCase().includes(query) ||
          (item.snippet || '').toLowerCase().includes(query) ||
          (item.id || '').toLowerCase().includes(query)
        );
      });
    }

    items.sort((a, b) => new Date(b.createdAt || 0) - new Date(a.createdAt || 0));

    return items.slice(0, Number(limit) || 25).map((item) => ({
      id: item.id,
      kind: item.kind,
      title: item.title,
      snippet: item.snippet,
      importance: Number(item.importance) || 0,
      embedding: clone(item.embedding ?? null),
      createdAt: item.createdAt
    }));
  });
}

export async function upsertMemoryItems(items = []) {
  if (!Array.isArray(items) || items.length === 0) {
    return { updated: 0 };
  }

  let count = 0;
  await writeStore((store) => {
    for (const item of items) {
      const id = item.id || randomUUID();
      const record = {
        id,
        kind: item.kind || 'memory',
        title: item.title,
        snippet: item.snippet || null,
        importance: Number(item.importance) || 0,
        embedding: clone(item.embedding ?? null),
        createdAt: ensureTimestamp(item.createdAt) || new Date().toISOString()
      };

      const existingIndex = store.memoryItems.findIndex((entry) => entry.id === id);
      if (existingIndex >= 0) {
        store.memoryItems[existingIndex] = record;
      } else {
        store.memoryItems.push(record);
      }
      count += 1;
    }
  });

  return { updated: count };
}

export async function telemetrySummary({ window = 14 } = {}) {
  return readStore((store) => {
    const threshold = new Date(Date.now() - (Number(window) || 14) * 24 * 60 * 60 * 1000);

    const runs = store.runs.filter((run) => {
      const created = new Date(run.createdAt || 0);
      return created >= threshold;
    });

    const stats = runs.reduce(
      (acc, run) => {
        acc.total += 1;
        if (run.status === 'success') acc.success += 1;
        if (run.status === 'failed') acc.failed += 1;
        if (run.status === 'cancelled') acc.cancelled += 1;
        return acc;
      },
      { total: 0, success: 0, failed: 0, cancelled: 0 }
    );

    const service = store.telemetryDaily
      .slice()
      .sort((a, b) => new Date(b.date || 0) - new Date(a.date || 0))
      .slice(0, Number(window) || 14)
      .map((entry) => ({
        date: entry.date,
        runsTotal: Number(entry.runsTotal ?? entry.runs_total) || 0,
        runsSuccess: Number(entry.runsSuccess ?? entry.runs_success) || 0,
        latencyP50: Number(entry.latencyP50 ?? entry.latency_p50) || 0,
        latencyP95: Number(entry.latencyP95 ?? entry.latency_p95) || 0,
        latencyP99: Number(entry.latencyP99 ?? entry.latency_p99) || 0,
        failureTop: clone(entry.failureTop ?? entry.failure_top ?? []),
        tokensSaved: Number(entry.tokensSaved ?? entry.tokens_saved) || 0,
        tokensSpent: Number(entry.tokensSpent ?? entry.tokens_spent) || 0
      }));

    return {
      runs: stats,
      service
    };
  });
}

