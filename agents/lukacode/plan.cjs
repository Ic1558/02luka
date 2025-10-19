#!/usr/bin/env node
const { readFileSync } = require('fs');
const { execSync } = require('child_process');
const path = require('path');

// Load memory system
const REPO_ROOT = process.env.REPO_ROOT || path.resolve(__dirname, '../..');
const memoryModule = require(path.join(REPO_ROOT, 'memory', 'index.cjs'));

const input = JSON.parse(readFileSync(0, 'utf8'));
const { runId, prompt, files = [] } = input;

// Recall relevant memories before planning
let relevantMemories = [];
try {
  relevantMemories = memoryModule.recall({
    query: prompt,
    topK: 3
  });
} catch (err) {
  // Memory system optional - continue if it fails
  console.error('Memory recall warning:', err.message);
}

const plan = {
  runId,
  status: 'ok',
  steps: [
    { id: 'analyze', action: 'analyze', target: 'prompt', priority: 1 },
    { id: 'execute', action: 'execute', target: 'files', priority: 2 }
  ],
  meta: {
    timestamp: new Date().toISOString(),
    agent: 'plan.cjs',
    relevantMemories: relevantMemories.map(m => ({
      kind: m.kind,
      text: m.text.slice(0, 100) + (m.text.length > 100 ? '...' : ''),
      similarity: m.similarity.toFixed(3)
    }))
  }
};

console.log(JSON.stringify(plan));
