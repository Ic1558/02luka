const fs = require('fs');
const path = require('path');
const memoryCore = require('../../memory/index.cjs');

const AUDIT_LOG_PATH = path.resolve(__dirname, '../../g/reports/memory_audit.log');

/**
 * @typedef {Object} RememberInput
 * @property {string} kind
 * @property {string} text
 * @property {Object} [meta]
 * @property {number} [importance]
 */

/**
 * Persist a memory item using the Phase 6.5 index with audit logging.
 * @param {RememberInput} input
 * @returns {ReturnType<memoryCore.remember>}
 */
function remember(input) {
  const normalized = normalizeInput(input);
  const result = memoryCore.remember(normalized);
  appendAuditLog({
    action: 'remember',
    payload: normalized,
    outcome: 'ok'
  });
  return result;
}

/**
 * Recall memories relevant to a query.
 * @param {{query: string, kind?: string, topK?: number}} params
 * @returns {ReturnType<memoryCore.recall>}
 */
function recall(params) {
  const result = memoryCore.recall(params);
  appendAuditLog({
    action: 'recall',
    payload: params,
    outcome: 'ok',
    meta: { returned: result.length }
  });
  return result;
}

/**
 * Get memory statistics from the core index.
 * @returns {ReturnType<memoryCore.stats>}
 */
function stats() {
  const result = memoryCore.stats();
  appendAuditLog({ action: 'stats', outcome: 'ok', meta: result });
  return result;
}

/**
 * Apply decay to memory importance scores.
 * @param {{halfLifeDays?: number}} [params]
 * @returns {ReturnType<memoryCore.decay>}
 */
function decay(params) {
  const result = memoryCore.decay(params || {});
  appendAuditLog({ action: 'decay', outcome: 'ok', meta: params || {} });
  return result;
}

/**
 * Run cleanup on low-importance or stale memories.
 * @param {{maxAgeDays?: number, minImportance?: number}} [params]
 * @returns {ReturnType<memoryCore.cleanup>}
 */
function cleanup(params) {
  const result = memoryCore.cleanup(params || {});
  appendAuditLog({ action: 'cleanup', outcome: 'ok', meta: params || {} });
  return result;
}

/**
 * Append audit events to disk.
 * @param {Object} record
 */
function appendAuditLog(record) {
  const line = JSON.stringify({
    timestamp: new Date().toISOString(),
    ...record
  });
  try {
    fs.appendFileSync(AUDIT_LOG_PATH, `${line}\n`, 'utf8');
  } catch (err) {
    // eslint-disable-next-line no-console
    console.warn('Unable to append memory audit log:', err.message);
  }
}

/**
 * Normalize input payload and enrich with heuristics.
 * @param {RememberInput} input
 * @returns {RememberInput & {importance: number, meta: Object}}
 */
function normalizeInput(input) {
  if (!input || typeof input.text !== 'string') {
    throw new Error('Memory text is required.');
  }
  const baseImportance = typeof input.importance === 'number' ? input.importance : estimateImportance(input.kind, input.text);
  const meta = {
    retentionHint: input.meta?.retentionHint || suggestRetention(input.kind),
    frequency: input.meta?.frequency || 0,
    lastAccess: new Date().toISOString(),
    ...(input.meta || {})
  };
  return {
    kind: input.kind || 'general',
    text: input.text,
    meta,
    importance: Math.max(0, Math.min(1, Number(baseImportance.toFixed(3))))
  };
}

/**
 * Estimate importance based on kind and content length.
 * @param {string} kind
 * @param {string} text
 * @returns {number}
 */
function estimateImportance(kind, text) {
  const base = text.length > 240 ? 0.6 : 0.4;
  const adjustments = {
    incident: 0.9,
    feedback: 0.5,
    plan: 0.7,
    summary: 0.6
  };
  return Math.min(1, adjustments[kind] ?? base);
}

/**
 * Suggest retention policy hints.
 * @param {string} kind
 * @returns {string}
 */
function suggestRetention(kind) {
  switch (kind) {
    case 'incident':
      return 'retain-365d';
    case 'feedback':
      return 'review-90d';
    case 'plan':
      return 'retain-180d';
    default:
      return 'review-120d';
  }
}

module.exports = {
  remember,
  recall,
  stats,
  decay,
  cleanup
};
