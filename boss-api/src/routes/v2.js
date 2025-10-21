import express from 'express';
import {
  addRunSteps,
  appendRunLogs,
  createApproval,
  createRun,
  decideApproval,
  getRunById,
  listMemoryItems,
  listRuns,
  recordMemoryHits,
  telemetrySummary,
  updateRun,
  upsertMemoryItems
} from '../lib/runStore.js';
import { publish, registerClient } from '../lib/eventBus.js';

const router = express.Router();

router.get('/runs', async (req, res, next) => {
  try {
    const { limit, status, agent, search } = req.query;
    const runs = await listRuns({
      limit: limit ? Number(limit) : undefined,
      status,
      agent,
      search
    });
    res.json({ runs });
  } catch (error) {
    next(error);
  }
});

router.post('/runs', async (req, res, next) => {
  try {
    const { title, agent, riskScore, summary, input, metadata } = req.body || {};
    if (!title || typeof title !== 'string') {
      return res.status(400).json({ error: 'title is required' });
    }
    const run = await createRun({ title, agent, riskScore, summary, input, metadata });
    publish({ type: 'run.created', run });
    res.status(201).json({ run });
  } catch (error) {
    next(error);
  }
});

router.get('/runs/:id', async (req, res, next) => {
  try {
    const { logs } = req.query;
    const includeLogs = logs ? Number(logs) : 200;
    const run = await getRunById(req.params.id, { includeLogs });
    if (!run) {
      return res.status(404).json({ error: 'Run not found' });
    }
    res.json({ run });
  } catch (error) {
    next(error);
  }
});

router.post('/runs/:id/status', async (req, res, next) => {
  try {
    const runId = req.params.id;
    const run = await updateRun(runId, req.body || {});
    if (!run) {
      return res.status(404).json({ error: 'Run not found' });
    }
    publish({ type: 'run.updated', runId, patch: req.body || {}, run });
    res.json({ run });
  } catch (error) {
    next(error);
  }
});

router.post('/runs/:id/steps', async (req, res, next) => {
  try {
    const runId = req.params.id;
    const { steps } = req.body || {};
    if (!Array.isArray(steps) || steps.length === 0) {
      return res.status(400).json({ error: 'steps array required' });
    }
    const run = await addRunSteps(runId, steps);
    if (!run) {
      return res.status(404).json({ error: 'Run not found' });
    }
    publish({ type: 'run.steps', runId, steps: run.steps });
    res.json({ run });
  } catch (error) {
    next(error);
  }
});

router.post('/runs/:id/logs', async (req, res, next) => {
  try {
    const runId = req.params.id;
    const { entries } = req.body || {};
    if (!Array.isArray(entries) || entries.length === 0) {
      return res.status(400).json({ error: 'entries array required' });
    }
    await appendRunLogs(runId, entries);
    publish({ type: 'run.logs', runId, entries });
    res.status(202).json({ accepted: true, inserted: entries.length });
  } catch (error) {
    next(error);
  }
});

router.post('/runs/:id/memory', async (req, res, next) => {
  try {
    const runId = req.params.id;
    const { hits } = req.body || {};
    if (!Array.isArray(hits) || hits.length === 0) {
      return res.status(400).json({ error: 'hits array required' });
    }
    const run = await recordMemoryHits(runId, hits);
    if (!run) {
      return res.status(404).json({ error: 'Run not found' });
    }
    publish({ type: 'run.memory', runId, memoryHits: run.memoryHits });
    res.json({ run });
  } catch (error) {
    next(error);
  }
});

router.post('/runs/:id/approvals', async (req, res, next) => {
  try {
    const runId = req.params.id;
    const { requestedBy, reason, riskScore } = req.body || {};
    const approval = await createApproval({ runId, requestedBy, reason, riskScore });
    publish({ type: 'approval.created', runId, approval });
    res.status(201).json({ approval });
  } catch (error) {
    next(error);
  }
});

router.post('/approvals/:id/decision', async (req, res, next) => {
  try {
    const approvalId = req.params.id;
    const { status, decidedBy, decisionNote } = req.body || {};
    const approval = await decideApproval(approvalId, { status, decidedBy, decisionNote });
    if (!approval) {
      return res.status(404).json({ error: 'Approval not found' });
    }
    publish({ type: 'approval.updated', approvalId, approval });
    res.json({ approval });
  } catch (error) {
    next(error);
  }
});

router.get('/memory/recall', async (req, res, next) => {
  try {
    const { kind, search, limit } = req.query;
    const items = await listMemoryItems({
      kind,
      search,
      limit: limit ? Number(limit) : undefined
    });
    res.json({ items });
  } catch (error) {
    next(error);
  }
});

router.post('/memory/index', async (req, res, next) => {
  try {
    const { items } = req.body || {};
    if (!Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ error: 'items array required' });
    }
    const result = await upsertMemoryItems(items);
    res.status(202).json(result);
  } catch (error) {
    next(error);
  }
});

router.get('/telemetry/summary', async (req, res, next) => {
  try {
    const { window } = req.query;
    const summary = await telemetrySummary({ window: window ? Number(window) : undefined });
    res.json({ summary });
  } catch (error) {
    next(error);
  }
});

router.get('/events/stream', (req, res) => {
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');
  res.flushHeaders?.();

  res.write('retry: 3000\n\n');
  registerClient(res);

  const keepAlive = setInterval(() => {
    res.write(': keep-alive\n\n');
  }, 15000);

  req.on('close', () => {
    clearInterval(keepAlive);
  });
});

export default router;

