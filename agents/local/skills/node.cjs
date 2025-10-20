#!/usr/bin/env node
/**
 * Phase 7.2: Node.js Skill Wrapper
 * Safe Node.js script execution
 *
 * Usage: node.cjs [script_path] [args...]
 *
 * Simply passes through to node with clean stdio
 * Timeout handled by orchestrator
 */

const { spawnSync } = require('child_process');

// Get arguments (script path + args)
const args = process.argv.slice(2);

if (args.length === 0) {
  console.error('Usage: node.cjs <script_path> [args...]');
  process.exit(1);
}

// Execute with inherited stdio
const result = spawnSync('node', args, {
  stdio: 'inherit',
  encoding: 'utf8'
});

// Exit with same code as child process
process.exit(result.status ?? 1);
