#!/usr/bin/env node
const { readFileSync } = require('fs');
const { execSync } = require('child_process');

const input = JSON.parse(readFileSync(0, 'utf8'));
const { runId, prompt, files = [] } = input;

const plan = {
  runId,
  status: 'ok',
  steps: [
    { id: 'analyze', action: 'analyze', target: 'prompt', priority: 1 },
    { id: 'execute', action: 'execute', target: 'files', priority: 2 }
  ],
  meta: { timestamp: new Date().toISOString(), agent: 'plan.cjs' }
};

console.log(JSON.stringify(plan));
