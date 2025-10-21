#!/usr/bin/env node
/**
 * CLS Local Orchestrator - Task execution engine
 */

const fs = require('fs');
const path = require('path');
const BashSkill = require('../../packages/skills/bash.js');
const NodeSkill = require('../../packages/skills/node.js');
const GitSkill = require('../../packages/skills/git.js');

class CLSOrchestrator {
  constructor() {
    this.skills = {
      bash: new BashSkill(),
      node: new NodeSkill(),
      git: new GitSkill()
    };
    this.queuePath = 'queue';
    this.telemetryPath = 'g/telemetry';
    this.memoryPath = 'memory';
  }

  /**
   * Process all tasks in inbox
   */
  async processQueue() {
    const inboxPath = path.join(this.queuePath, 'inbox');
    const donePath = path.join(this.queuePath, 'done');
    const failedPath = path.join(this.queuePath, 'failed');

    // Ensure directories exist
    [inboxPath, donePath, failedPath, this.telemetryPath].forEach(dir => {
      if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
      }
    });

    const tasks = fs.readdirSync(inboxPath)
      .filter(file => file.endsWith('.json'))
      .map(file => ({
        file,
        data: JSON.parse(fs.readFileSync(path.join(inboxPath, file), 'utf8'))
      }));

    console.log(`🧠 CLS Processing ${tasks.length} tasks...`);

    for (const { file, data } of tasks) {
      try {
        await this.executeTask(data);
        this.moveTask(file, inboxPath, donePath);
        this.logTelemetry(data.id, 'PASS', data);
        console.log(`✅ Task ${data.id} completed successfully`);
      } catch (error) {
        this.moveTask(file, inboxPath, failedPath);
        this.logTelemetry(data.id, 'FAIL', data, error.message);
        console.log(`❌ Task ${data.id} failed: ${error.message}`);
      }
    }
  }

  /**
   * Validate filesystem scope for task
   */
  validateFsScope(task) {
    const rwOps = ["copy", "move", "write", "delete"];
    if (rwOps.includes(task.op) || task.allowWrite) {
      if (!Array.isArray(task.paths) || task.paths.length === 0) {
        throw new Error("Write op needs task.paths[] within CLS_FS_ALLOW");
      }
    }
  }

  /**
   * Execute a single task
   */
  async executeTask(task) {
    const { id, skill, cmd, code, action, args, risk, allowWrite, paths } = task;

    // Validate filesystem scope
    this.validateFsScope(task);

    switch (skill) {
      case 'bash':
        return await this.skills.bash.execute(cmd, { risk, allowHigh: true, allowWrite, paths });
      
      case 'node':
        return await this.skills.node.execute(code);
      
      case 'git':
        return await this.skills.git.execute(action, args);
      
      default:
        throw new Error(`Unknown skill: ${skill}`);
    }
  }

  /**
   * Move task between directories
   */
  moveTask(file, from, to) {
    const sourcePath = path.join(from, file);
    const destPath = path.join(to, file);
    
    if (fs.existsSync(sourcePath)) {
      fs.renameSync(sourcePath, destPath);
    }
  }

  /**
   * Log telemetry data
   */
  logTelemetry(taskId, status, task, error = null) {
    const timestamp = new Date().toISOString();
    const logEntry = {
      timestamp,
      taskId,
      status,
      skill: task.skill,
      command: task.cmd || task.code || `${task.action} ${task.args?.join(' ')}`,
      error: error,
      duration: Date.now() // Simple timestamp for now
    };

    const logFile = path.join(this.telemetryPath, `cls_${Date.now()}.log`);
    fs.writeFileSync(logFile, JSON.stringify(logEntry, null, 2));
  }

  /**
   * Get orchestrator status
   */
  getStatus() {
    return {
      skills: Object.keys(this.skills),
      queuePath: this.queuePath,
      telemetryPath: this.telemetryPath,
      shell: this.skills.bash.getShellInfo()
    };
  }
}

// CLI interface
if (require.main === module) {
  const orchestrator = new CLSOrchestrator();
  
  const command = process.argv[2];
  
  switch (command) {
    case '--status':
      console.log('CLS Orchestrator Status:', orchestrator.getStatus());
      break;
      
    case '--run':
      const cmd = process.argv[3];
      if (cmd) {
        orchestrator.skills.bash.execute(cmd)
          .then(result => console.log('✅', result))
          .catch(err => console.error('❌', err.message));
      }
      break;
      
    default:
      orchestrator.processQueue()
        .then(() => console.log('🎯 CLS Queue processing complete'))
        .catch(err => console.error('❌ CLS Error:', err.message));
  }
}

module.exports = CLSOrchestrator;