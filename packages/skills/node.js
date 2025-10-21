#!/usr/bin/env node
/**
 * CLS Node.js Skill - Local Node.js execution
 */

const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');

class NodeSkill {
  constructor() {
    this.tempDir = 'g/tmp';
  }

  /**
   * Execute Node.js code
   * @param {string} code - JavaScript code to execute
   * @returns {Promise<Object>} Execution result
   */
  async execute(code) {
    // Ensure temp directory exists
    if (!fs.existsSync(this.tempDir)) {
      fs.mkdirSync(this.tempDir, { recursive: true });
    }

    const tempFile = path.join(this.tempDir, `node_${Date.now()}.js`);
    
    try {
      // Write code to temporary file
      fs.writeFileSync(tempFile, code);
      
      return new Promise((resolve, reject) => {
        const child = spawn('node', [tempFile], { 
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
          // Clean up temp file
          try {
            fs.unlinkSync(tempFile);
          } catch (err) {
            // Ignore cleanup errors
          }

          if (code === 0) {
            resolve({ 
              success: true, 
              exitCode: code,
              output: stdout.trim(),
              code: code
            });
          } else {
            reject(new Error(`Node.js execution failed (${code}): ${stderr}`));
          }
        });

        child.on('error', (err) => {
          reject(new Error(`Node.js execution error: ${err.message}`));
        });
      });
    } catch (err) {
      throw new Error(`Failed to execute Node.js code: ${err.message}`);
    }
  }
}

module.exports = NodeSkill;
