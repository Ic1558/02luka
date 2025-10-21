#!/usr/bin/env node
/**
 * CLS Bash Skill - Local shell execution with safety gates
 */

const { spawn } = require('child_process');
const { resolveShell } = require('./resolveShell');
const { assertAllowed } = require('../fs/secureFS');
const path = require('path');

class BashSkill {
  constructor() {
    this.shell = resolveShell();
    this.dangerousPatterns = [
      /rm\s+-rf\s+\//,           // rm -rf /
      /shutdown\s+-h\s+now/,     // shutdown -h now
      /reboot/,                   // reboot
      /dd\s+if=/,                // dd if= (disk operations)
      /mkfs/,                     // mkfs (format filesystem)
      /fdisk/,                    // fdisk
      /parted/,                   // parted
      /:(){ :|:& };:/,           // fork bomb
    ];
  }

  /**
   * Execute bash command with safety checks
   * @param {string} cmd - Command to execute
   * @param {Object} options - Execution options
   * @returns {Promise<Object>} Execution result
   */
  async execute(cmd, options = {}) {
    const { risk = 'low', allowHigh = false, allowWrite = false, paths = [] } = options;
    
    // Pre-flight path checks for write operations
    if (allowWrite && paths.length) {
      paths.forEach(p => assertAllowed(p));
    }
    
    // Safety gate: check for dangerous patterns
    if (this.isDangerous(cmd)) {
      if (risk === 'high' && allowHigh && process.env.LOCAL_ALLOW_HIGH === '1') {
        console.log('⚠️  HIGH RISK: Executing dangerous command with approval');
      } else {
        throw new Error(`BLOCKED: Dangerous command detected - ${cmd}`);
      }
    }

    return new Promise((resolve, reject) => {
      const child = spawn(this.shell, ['-c', cmd], { 
        stdio: 'inherit',
        cwd: process.cwd()
      });

      child.on('close', (code) => {
        if (code === 0) {
          resolve({ 
            success: true, 
            exitCode: code, 
            command: cmd,
            shell: this.shell 
          });
        } else {
          reject(new Error(`Command failed with exit code ${code}: ${cmd}`));
        }
      });

      child.on('error', (err) => {
        reject(new Error(`Shell execution error: ${err.message}`));
      });
    });
  }

  /**
   * Check if command contains dangerous patterns
   * @param {string} cmd - Command to check
   * @returns {boolean} True if dangerous
   */
  isDangerous(cmd) {
    return this.dangerousPatterns.some(pattern => pattern.test(cmd));
  }

  /**
   * Get available shell information
   * @returns {Object} Shell details
   */
  getShellInfo() {
    return {
      shell: this.shell,
      available: this.shell !== 'sh',
      candidates: [
        process.env.CLS_SHELL,
        process.env.SHELL,
        '/bin/bash',
        '/usr/bin/bash',
        '/bin/zsh',
        '/usr/bin/zsh',
        '/bin/sh'
      ]
    };
  }
}

// CLI interface
if (require.main === module) {
  const bash = new BashSkill();
  const cmd = process.argv[2];
  
  if (!cmd) {
    console.log('Usage: node packages/skills/bash.js "command"');
    console.log('Shell info:', bash.getShellInfo());
    process.exit(1);
  }

  bash.execute(cmd)
    .then(result => {
      console.log('✅ Command executed successfully:', result);
    })
    .catch(err => {
      console.error('❌ Command failed:', err.message);
      process.exit(1);
    });
}

module.exports = BashSkill;
