import {
  addRunSteps,
  appendRunLogs,
  createApproval,
  createRun,
  decideApproval,
  listRuns,
  recordMemoryHits,
  updateRun,
  upsertMemoryItems
} from '../src/lib/runStore.js';
import { readStore, writeStore } from '../src/lib/db.js';

function iso(offsetMinutes = 0) {
  return new Date(Date.now() + offsetMinutes * 60_000).toISOString();
}

async function runExists(key) {
  const runs = await listRuns({ limit: 200 });
  return runs.some((run) => run.metadata?.key === key);
}

async function seedMemory() {
  await upsertMemoryItems([
    {
      id: 'memo-shadow-deploy',
      kind: 'playbook',
      title: 'Shadow deploy procedure',
      snippet: 'Deploy behind feature flag, mirror traffic at 5%, validate metrics before promote.',
      importance: 5,
      createdAt: iso(-2880)
    },
    {
      id: 'memo-diff-checklist',
      kind: 'checklist',
      title: 'Risk approval checklist',
      snippet: 'Capture diff, list blast radius, confirm rollback, tag approver with summary.',
      importance: 4,
      createdAt: iso(-1440)
    },
    {
      id: 'memo-throttle',
      kind: 'memo',
      title: 'Embedding throttle guidance',
      snippet: 'Limit parallel embeddings to 4 workers; exponential backoff on HTTP 429.',
      importance: 3,
      createdAt: iso(-900)
    }
  ]);
}

async function seedSuccessRun() {
  if (await runExists('demo-success')) return;

  const startedAt = iso(-170);
  const completedAt = iso(-120);

  const run = await createRun({
    title: 'Shadow Deploy — Bridge API',
    agent: 'CLS',
    riskScore: 0.72,
    summary: 'Shipped bridge API shadow deploy with live traffic guardrails.',
    metadata: { demo: true, key: 'demo-success' }
  });

  await updateRun(run.id, {
    status: 'running',
    startedAt
  });

  await addRunSteps(run.id, [
    {
      id: 'demo-success-step-1',
      idx: 1,
      title: 'Queue deployment job',
      status: 'success',
      startedAt,
      completedAt: iso(-165),
      log: 'Queued deploy via shipit pipeline with canary tag.'
    },
    {
      id: 'demo-success-step-2',
      idx: 2,
      title: 'Mirror traffic at 5%',
      status: 'success',
      startedAt: iso(-165),
      completedAt: iso(-150),
      log: 'Mirror configured: bridge-api@latest to bridge-api@shadow.'
    },
    {
      id: 'demo-success-step-3',
      idx: 3,
      title: 'Validate telemetry',
      status: 'success',
      startedAt: iso(-150),
      completedAt: iso(-130),
      log: 'p95 latency stable at 480ms, error rate < 0.1%.'
    },
    {
      id: 'demo-success-step-4',
      idx: 4,
      title: 'Promote to 100%',
      status: 'success',
      startedAt: iso(-130),
      completedAt,
      log: 'Cutover completed, monitoring steady for 5 minutes.'
    }
  ]);

  await appendRunLogs(run.id, [
    { timestamp: startedAt, level: 'info', message: 'Starting deploy workflow with risk score 0.72' },
    { timestamp: iso(-162), level: 'info', message: 'Shipit response: job=bridge-7121 queued' },
    { timestamp: iso(-149), level: 'info', message: 'Metrics: latency=478ms p95, success_rate=99.4%' },
    { timestamp: iso(-133), level: 'warn', message: 'One retry detected during canary ramp. Auto-resolved.' },
    { timestamp: completedAt, level: 'info', message: 'Deployment promoted to 100% traffic.' }
  ]);

  await recordMemoryHits(run.id, [
    {
      id: 'demo-memory-1',
      memoryId: 'memo-shadow-deploy',
      title: 'Shadow deploy procedure',
      snippet: '1) queue canary 2) mirror 5% 3) guardrail check 4) promote when stable.',
      score: 0.92,
      kind: 'playbook',
      createdAt: iso(-151)
    },
    {
      id: 'demo-memory-2',
      memoryId: 'memo-diff-checklist',
      title: 'Risk approval checklist',
      snippet: 'Capture rollback plan and notify approver before promote.',
      score: 0.81,
      kind: 'memo',
      createdAt: iso(-148)
    }
  ]);

  const approval = await createApproval({
    runId: run.id,
    requestedBy: 'CLS',
    reason: 'Production cutover requires approver sign-off.',
    riskScore: 0.72
  });

  await decideApproval(approval.id, {
    status: 'approved',
    decidedBy: 'operator',
    decisionNote: 'Guardrails cleared, cutover permitted.'
  });

  await updateRun(run.id, {
    status: 'success',
    completedAt,
    durationMs: new Date(completedAt) - new Date(startedAt),
    tokensUsed: 1823,
    tokensSaved: 940
  });
}

async function seedFailedRun() {
  if (await runExists('demo-failure')) return;

  const startedAt = iso(-85);
  const failedAt = iso(-60);

  const run = await createRun({
    title: 'Playbook: Refresh knowledge index',
    agent: 'Codex',
    riskScore: 0.28,
    summary: 'Nightly index refresh failed during embedding batch.',
    metadata: { demo: true, key: 'demo-failure' }
  });

  await updateRun(run.id, { status: 'running', startedAt });

  await addRunSteps(run.id, [
    {
      id: 'demo-failure-step-1',
      idx: 1,
      title: 'Extract latest docs',
      status: 'success',
      startedAt,
      completedAt: iso(-78),
      log: 'Collected 124 docs from workspace sync.'
    },
    {
      id: 'demo-failure-step-2',
      idx: 2,
      title: 'Generate embeddings',
      status: 'failed',
      startedAt: iso(-78),
      completedAt: failedAt,
      log: 'OpenAI rate limit exceeded after 80 embeddings. Abort.'
    }
  ]);

  await appendRunLogs(run.id, [
    { timestamp: startedAt, level: 'info', message: 'Refreshing vector index from nightly batch.' },
    { timestamp: iso(-76), level: 'info', message: 'Batch progress 64/124 embeddings.' },
    { timestamp: iso(-65), level: 'warn', message: 'Rate limit near threshold, slowing requests.' },
    { timestamp: failedAt, level: 'error', message: 'OpenAI: Rate limit exceeded. Retry after 60s.' }
  ]);

  await recordMemoryHits(run.id, [
    {
      id: 'demo-memory-3',
      memoryId: 'memo-throttle',
      title: 'Embedding throttle guidance',
      snippet: 'Use 4 parallel workers max; exponential backoff on 429.',
      score: 0.76,
      kind: 'memo',
      createdAt: iso(-70)
    }
  ]);

  await updateRun(run.id, {
    status: 'failed',
    completedAt: failedAt,
    durationMs: new Date(failedAt) - new Date(startedAt),
    tokensUsed: 640,
    tokensSaved: 210
  });
}

async function seedTelemetry() {
  await writeStore((store) => {
    const entry = {
      date: new Date().toISOString().slice(0, 10),
      runsTotal: 42,
      runsSuccess: 37,
      latencyP50: 1.9,
      latencyP95: 3.2,
      latencyP99: 6.5,
      failureTop: [{ label: 'Embedding batch', count: 3 }],
      tokensSaved: 12450,
      tokensSpent: 3680
    };

    const existingIndex = store.telemetryDaily.findIndex((item) => item.date === entry.date);
    if (existingIndex >= 0) {
      store.telemetryDaily[existingIndex] = entry;
    } else {
      store.telemetryDaily.push(entry);
    }
  });
}

async function main() {
  await seedMemory();
  await seedSuccessRun();
  await seedFailedRun();
  await seedTelemetry();
  console.log('Demo data ready.');
}

main().catch((error) => {
  console.error('Failed to seed demo data', error);
  process.exitCode = 1;
});

