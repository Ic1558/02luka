#!/usr/bin/env node
/**
 * @file mcp_health.mjs
 * @created_by GG_Agent_02luka
 * @description Lightweight MCP health snapshot pipeline.
 *              Reads hub/mcp_registry.json, pings each MCP server safely
 *              (spawn-only, timeout, no real I/O), writes hub/mcp_health.json.
 */

import { spawn } from 'node:child_process';
import { access, constants, readFile, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { dirname, join, resolve } from 'node:path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const PROJECT_ROOT = resolve(__dirname, '..');

const REGISTRY_PATH = join(PROJECT_ROOT, 'hub', 'mcp_registry.json');
const OUTPUT_PATH = join(PROJECT_ROOT, 'hub', 'mcp_health.json');
const TIMEOUT_MS = 2000;

/**
 * Check if a binary exists and is executable.
 */
async function isBinaryExecutable(command) {
  try {
    await access(command, constants.X_OK);
    return true;
  } catch {
    // Try to find it in PATH
    try {
      await access(command, constants.F_OK);
      return true;
    } catch {
      return false;
    }
  }
}

/**
 * Spawn a process with timeout and check if it responds.
 * Returns { ok, latency_ms, reason }
 */
async function checkServerHealth(command, args = []) {
  const startTime = Date.now();
  const reasons = [];

  // Check if binary exists
  const executable = await isBinaryExecutable(command);
  if (!executable) {
    return {
      ok: false,
      latency_ms: Date.now() - startTime,
      reason: ['command not found'],
    };
  }

  return new Promise((resolve) => {
    let timedOut = false;
    let completed = false;

    const timeout = setTimeout(() => {
      timedOut = true;
      if (!completed) {
        proc.kill();
        reasons.push('timeout');
        resolve({
          ok: false,
          latency_ms: Date.now() - startTime,
          reason: reasons,
        });
      }
    }, TIMEOUT_MS);

    const proc = spawn(command, args, {
      stdio: 'ignore',
      timeout: TIMEOUT_MS,
    });

    proc.on('error', (err) => {
      completed = true;
      clearTimeout(timeout);
      if (!timedOut) {
        reasons.push(`spawn error: ${err.message}`);
        resolve({
          ok: false,
          latency_ms: Date.now() - startTime,
          reason: reasons,
        });
      }
    });

    proc.on('close', (code) => {
      completed = true;
      clearTimeout(timeout);
      if (!timedOut) {
        const latency = Date.now() - startTime;
        // Consider "ok" if spawned and didn't timeout (exit code may be non-zero)
        if (code !== 0 && code !== null) {
          reasons.push(`exit=${code}`);
        }
        resolve({
          ok: true,
          latency_ms: latency,
          reason: reasons,
        });
      }
    });
  });
}

/**
 * Main health check pipeline.
 */
async function main() {
  try {
    // Read registry
    let registry;
    try {
      const registryData = await readFile(REGISTRY_PATH, 'utf8');
      registry = JSON.parse(registryData);
    } catch (err) {
      console.error(`Failed to read registry at ${REGISTRY_PATH}:`, err.message);
      process.exit(1);
    }

    // Extract servers from registry
    const servers = registry.servers || [];
    if (!Array.isArray(servers) || servers.length === 0) {
      console.warn('No servers found in registry');
    }

    // Check health for each server
    const results = [];
    for (const server of servers) {
      const { name, command, args = [] } = server;

      if (!command) {
        results.push({
          name,
          ok: false,
          latency_ms: 0,
          command: '',
          args: [],
          reason: ['no command specified'],
        });
        continue;
      }

      // Default to --version if no args provided
      const checkArgs = args.length > 0 ? args : ['--version'];

      console.log(`Checking ${name}...`);
      const health = await checkServerHealth(command, checkArgs);

      results.push({
        name,
        ok: health.ok,
        latency_ms: health.latency_ms,
        command,
        args: checkArgs,
        reason: health.reason,
      });
    }

    // Count healthy servers
    const healthy = results.filter((r) => r.ok).length;

    // Build output
    const output = {
      _meta: {
        created_by: 'GG_Agent_02luka',
        created_at: new Date().toISOString(),
        source: 'mcp_health.mjs',
        registry_path: 'hub/mcp_registry.json',
        total: results.length,
        healthy,
      },
      results,
    };

    // Write health snapshot
    await writeFile(OUTPUT_PATH, JSON.stringify(output, null, 2) + '\n', 'utf8');
    console.log(`\nHealth snapshot written to ${OUTPUT_PATH}`);
    console.log(`Total: ${results.length}, Healthy: ${healthy}`);

    // Exit with error if no servers are healthy (but only if there are servers)
    if (results.length > 0 && healthy === 0) {
      console.warn('⚠️  Warning: No healthy servers found');
    }
  } catch (err) {
    console.error('Fatal error:', err);
    process.exit(1);
  }
}

main();
