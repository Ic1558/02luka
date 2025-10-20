/**
 * Phase 7.2: Policy Engine
 * Risk assessment and approval gates for task execution
 *
 * Prevents dangerous operations from running without approval
 * Provides safety guardrails for automation
 */

const fs = require('fs');
const path = require('path');

// Dangerous patterns to block (belt & suspenders with skill-level checks)
const DANGEROUS_PATTERNS = [
  // Destructive file operations
  /rm\s+-rf\s+\/[^\/]/,           // rm -rf /something
  /rm\s+-rf\s+\~/,                // rm -rf ~/
  /rm\s+-rf\s+\*/,                // rm -rf *
  /:\)/,                          // Fork bomb
  /dd\s+if=/,                     // dd (disk destroyer)
  /mkfs/,                         // Format filesystem
  /fdisk/,                        // Partition manipulation

  // System-level operations
  /shutdown/,
  /reboot/,
  /halt/,
  /init\s+[06]/,

  // Permission bombs
  /chmod\s+(-R\s+)?777\s+\//,     // chmod 777 on root
  /chown\s+(-R\s+)?.*\s+\//,      // chown on root

  // Network attacks
  /curl.*evil/i,
  /wget.*evil/i,
  />\/dev\/tcp/,                  // Shell-based TCP connections

  // Code injection risks
  /eval\s*\(/,                    // JavaScript eval
  /exec\s*\(/,                    // Python/shell exec

  // Git force operations on main/master
  /git\s+push.*--force.*main/,
  /git\s+push.*--force.*master/,
  /git\s+push.*-f.*main/,
  /git\s+push.*-f.*master/
];

// Known safe patterns (allowlist)
const SAFE_PATTERNS = [
  /git\s+status/,
  /git\s+log/,
  /git\s+diff/,
  /git\s+show/,
  /ls\s+/,
  /cat\s+/,
  /echo\s+/,
  /node\s+.*\.cjs/,
  /bash\s+scripts\//
];

/**
 * Check if command contains dangerous patterns
 */
function scanCommand(cmd) {
  // Check if it's in safe list first
  if (SAFE_PATTERNS.some(pattern => pattern.test(cmd))) {
    return { dangerous: false };
  }

  // Check dangerous patterns
  for (const pattern of DANGEROUS_PATTERNS) {
    if (pattern.test(cmd)) {
      return {
        dangerous: true,
        pattern: pattern.toString(),
        reason: 'dangerous_pattern_detected'
      };
    }
  }

  return { dangerous: false };
}

/**
 * Calculate risk score for a task (0-100)
 */
function calculateRisk(task) {
  let score = 0;

  // Base risk from task declaration
  const declaredRisk = (task.risk || 'medium').toLowerCase();
  if (declaredRisk === 'high') score += 60;
  else if (declaredRisk === 'medium') score += 30;
  else score += 10;

  // Check steps for dangerous patterns
  for (const step of task.steps || []) {
    if (step.skill === 'bash' && step.args?.length) {
      const cmd = step.args.join(' ');
      const scan = scanCommand(cmd);
      if (scan.dangerous) {
        score += 70; // Major red flag
      }
    }

    // Git operations add some risk
    if (step.skill === 'git') {
      const args = step.args || [];
      if (args.includes('push')) score += 20;
      if (args.includes('--force') || args.includes('-f')) score += 30;
      if (args.includes('reset')) score += 15;
    }
  }

  // Priority urgency increases risk (might be reactive/hasty)
  if (task.priority === 'urgent') score += 15;

  return Math.min(100, score);
}

/**
 * Assess task and determine if it should be blocked
 */
function assess(task) {
  if (!task || !task.steps) {
    return {
      blocked: true,
      reason: 'invalid_task_structure',
      risk: 0
    };
  }

  const risk = calculateRisk(task);

  // Check for dangerous commands in bash steps
  for (const step of task.steps) {
    if (step.skill === 'bash' && step.args?.length) {
      const cmd = step.args.join(' ');
      const scan = scanCommand(cmd);

      if (scan.dangerous) {
        return {
          blocked: true,
          reason: 'dangerous_command_detected',
          risk,
          pattern: scan.pattern,
          command: cmd
        };
      }
    }
  }

  // Risk thresholds
  const declaredRisk = (task.risk || 'medium').toLowerCase();
  const needsApproval = risk >= 60 || declaredRisk === 'high' || task.priority === 'urgent';

  // Check approval env var
  const allowHigh = process.env.LOCAL_ALLOW_HIGH === '1';

  if (needsApproval && !allowHigh) {
    return {
      blocked: true,
      reason: 'approval_required',
      risk,
      message: `Task requires approval (risk=${risk}). Set LOCAL_ALLOW_HIGH=1 to proceed.`
    };
  }

  return {
    blocked: false,
    risk,
    approved: !needsApproval || allowHigh
  };
}

/**
 * Generate approval request message
 */
function approvalRequest(task) {
  const risk = calculateRisk(task);

  return {
    task_id: task.id,
    title: task.title,
    risk_score: risk,
    risk_level: task.risk,
    steps_count: (task.steps || []).length,
    message: `Task "${task.title}" requires approval (risk=${risk})`,
    approval_command: `LOCAL_ALLOW_HIGH=1 node agents/local/orchestrator.cjs --once`
  };
}

module.exports = {
  assess,
  calculateRisk,
  scanCommand,
  approvalRequest
};
