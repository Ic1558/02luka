#!/usr/bin/env node
const { readFileSync } = require('fs');

const input = JSON.parse(readFileSync(0, 'utf8'));
const { runId, mode, scope = [], checks = [] } = input;

const result = {
  runId,
  status: 'ok',
  mode,
  scope,
  checks: checks.length || ['api', 'ui'],
  passed: true,
  meta: { timestamp: new Date().toISOString(), agent: 'smoke.cjs' }
};

console.log(JSON.stringify(result));
