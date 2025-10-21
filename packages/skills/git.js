#!/usr/bin/env node
/**
 * CLS Git Skill - Local Git operations
 */

const { spawn } = require('child_process');

class GitSkill {
  constructor() {
    this.allowedActions = [
      'log', 'status', 'diff', 'show', 'ls-files', 'rev-parse',
      'branch', 'tag', 'remote', 'config', 'help'
    ];
  }

  /**
   * Execute Git command
   * @param {string} action - Git action to perform
   * @param {Array} args - Command arguments
   * @returns {Promise<Object>} Execution result
   */
  async execute(action, args = []) {
    // Safety check: only allow read-only operations
    if (!this.allowedActions.includes(action)) {
      throw new Error(`Git action '${action}' not allowed. Only read-only operations permitted.`);
    }

    return new Promise((resolve, reject) => {
      const child = spawn('git', [action, ...args], { 
        stdio: ['pipe', 'pipe', 'pipe'],
        cwd: process.cwd()
      });

      let stdout = '';
      let stderr = '';

      child.stdout.on('data', (data) => {
        stdout += data.toString();
      });

      child.stderr.on('data', (data) => {
        stderr += data.toString();
      });

      child.on('close', (code) => {
        if (code === 0) {
          resolve({ 
            success: true, 
            exitCode: code,
            output: stdout.trim(),
            action: action,
            args: args
          });
        } else {
          reject(new Error(`Git command failed (${code}): ${stderr}`));
        }
      });

      child.on('error', (err) => {
        reject(new Error(`Git execution error: ${err.message}`));
      });
    });
  }

  /**
   * Get allowed Git actions
   * @returns {Array} List of allowed actions
   */
  getAllowedActions() {
    return [...this.allowedActions];
  }
}

module.exports = GitSkill;
