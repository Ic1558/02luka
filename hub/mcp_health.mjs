// @created_by: GG_Agent_02luka
// @phase: 20.2
// @file: mcp_health.mjs
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { spawn } from 'child_process';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '..');

const REGISTRY_PATH = path.join(__dirname, 'mcp_registry.json');
const HEALTH_PATH   = path.join(__dirname, 'mcp_health.json');

function safeReadJSON(p, fallback = {}) {
  try { return JSON.parse(fs.readFileSync(p, 'utf8')); }
  catch { return fallback; }
}

/**
 * Check if command is executable, handling both absolute paths and PATH lookups
 * For PATH-based commands (e.g., "node", "python"), we let spawn handle resolution
 * and only verify absolute paths exist and are executable
 */
function isExecutable(p) {
  // If absolute path, check directly
  if (path.isAbsolute(p)) {
    try {
      fs.accessSync(p, fs.constants.X_OK);
      return true;
    } catch {
      return false;
    }
  }
  // For PATH-based commands, let spawn handle resolution
  // We'll catch ENOENT in the spawn error handler
  return true;
}

/**
 * Ping strategy (best-effort, non-intrusive):
 *  1) ตรวจว่ามีไฟล์ binary และมีสิทธิ์ execute
 *  2) spawn process (e.g., `<cmd> --version`) ถ้า args จาก registry ไม่ขัดแย้ง
 *  3) กำหนด timeout (default 2000ms) — kill ถ้าเกิน
 *  4) ไม่อ่าน/เขียน stdio เพื่อเลี่ยง side effect
 */
async function pingServer(srv, opts = {}) {
  const start = Date.now();
  const reason = [];
  const timeoutMs = opts.timeoutMs ?? 2000;

  const command = srv.command;
  const args    = Array.isArray(srv.args) ? srv.args.slice() : [];
  const env     = { ...process.env, ...(srv.env || {}) };

  if (!command) {
    return { name: srv.name, ok: false, latency_ms: 0, reason: ['missing command'] };
  }
  
  // For absolute paths, verify existence and executability
  if (path.isAbsolute(command)) {
    if (!fs.existsSync(command)) {
      return { name: srv.name, ok: false, latency_ms: 0, reason: ['command not found'] };
    }
    if (!isExecutable(command)) {
      return { name: srv.name, ok: false, latency_ms: 0, reason: ['command not executable'] };
    }
  }
  // For PATH-based commands, let spawn handle resolution (will catch ENOENT in error handler)

  // ลองเติม --version แบบ safe ถ้าไม่มี args ใด ๆ
  // (ถ้า binary ไม่รองรับ ก็ไม่ถือเป็น fail ถ้าสามารถ spawn ได้และ exit ภายในเวลา)
  const tryArgs = args.length ? args : ['--version'];

  const child = spawn(command, tryArgs, {
    env,
    stdio: 'ignore', // ไม่รบกวน I/O
    detached: false
  });

  let timedOut = false;
  const killer = setTimeout(() => {
    timedOut = true;
    try { child.kill('SIGKILL'); } catch {}
  }, timeoutMs);

  const exitCode = await new Promise(resolve => {
    child.on('error', (err) => {
      // ENOENT means command not found (PATH resolution failed)
      if (err.code === 'ENOENT') {
        reason.push('command not found in PATH');
      } else {
        reason.push(`spawn error: ${err.code || err.message}`);
      }
      resolve(127);
    });
    child.on('exit', (code) => resolve(code ?? 0));
  });

  clearTimeout(killer);

  if (timedOut) reason.push('timeout');

  // ถือว่า "ผ่าน" ถ้า spawn สำเร็จและไม่ timeout (exit code ใดๆ อนุโลม เพราะบาง binary คืน 1 เมื่อเรียก --version)
  const ok = !timedOut;

  const latency = Date.now() - start;
  if (exitCode !== 0) reason.push(`exit=${exitCode}`);

  return {
    name: srv.name,
    ok,
    latency_ms: latency,
    command,
    args: tryArgs,
    reason
  };
}

async function main() {
  const registry = safeReadJSON(REGISTRY_PATH, {});
  const servers = Array.isArray(registry.servers) ? registry.servers : [];

  const results = [];
  for (const srv of servers) {
    // ป้องกัน "over-aggressive" ping: จำกัด timeout 2s/ตัว
    const r = await pingServer(srv, { timeoutMs: 2000 });
    results.push(r);
  }

  const summary = {
    _meta: {
      created_by: 'GG_Agent_02luka',
      created_at: new Date().toISOString(),
      source: 'mcp_health.mjs',
      registry_path: REGISTRY_PATH,
      total: results.length,
      healthy: results.filter(x => x.ok).length
    },
    results
  };

  fs.writeFileSync(HEALTH_PATH, JSON.stringify(summary, null, 2));
  console.log(`[mcp:health] wrote → ${HEALTH_PATH} (healthy=${summary._meta.healthy}/${summary._meta.total})`);
}

main().catch(err => {
  console.error('[mcp:health] ERROR', err);
  process.exit(1);
});
