#!/usr/bin/env node
const { readFileSync } = require('fs');

const input = JSON.parse(readFileSync(0, 'utf8'));
const { runId, dryRun = false, summary, patches = [] } = input;

const result = {
  runId,
  status: 'ok',
  dryRun,
  applied: dryRun ? 0 : patches.length,
  patches: patches.map(p => ({ ...p, status: dryRun ? 'preview' : 'applied' })),
  meta: { timestamp: new Date().toISOString(), agent: 'patch.cjs' }
};

console.log(JSON.stringify(result));
