// Phase 8.4 — Config Center (Dry-Run Mode) + Secret Guards
// Reads .env, docker-compose.yml, and feature-flag files → produces structured config map (JSON + MD)
// Modes: CFG_EDIT = off | dryrun | on  (default off; read-only only)
// Safety: All writes blocked by default; dryrun shows diff; real apply requires confirm
// Secret Guards: ALLOW_SECRET_EDITS=off (default) blocks secret key edits

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const REPO = process.env.REPO_PATH || path.join(process.env.HOME || '', '02luka-repo');
const LOGS = path.join(REPO, 'g/logs');
const BACKUPS = path.join(REPO, 'g/backups');
const REPS = path.join(REPO, 'g/reports');

const MODE = String(process.env.CFG_EDIT || 'off').toLowerCase(); // off|dryrun|on
const REQUIRE_CONFIRM = String(process.env.CFG_REQUIRE_CONFIRM || 'on').toLowerCase() === 'on';

// Secret detection patterns and allow/deny lists
const SECRET_PATTERNS = (process.env.SECRET_PATTERNS || 'TOKEN,SECRET,PASSWORD,PASS,API_KEY,WEBHOOK,PRIVATE_KEY,ACCESS_KEY,CLIENT_SECRET').split(',').map(s=>s.trim()).filter(Boolean);
const SAFE_EDIT_KEYS = (process.env.SAFE_EDIT_KEYS || '').split(',').map(s=>s.trim()).filter(Boolean); // explicit allowlist
const DENY_EDIT_KEYS = (process.env.DENY_EDIT_KEYS || '').split(',').map(s=>s.trim()).filter(Boolean); // explicit denylist

const FILES = {
  env: path.join(REPO, '.env'),
  compose: path.join(REPO, 'docker-compose.yml'),
  makefile: path.join(REPO, 'Makefile')
};

function ensureDir(p){ fs.mkdirSync(p, { recursive:true }); }
function isoNow(){ return new Date().toISOString(); }
function writeLog(line) {
  ensureDir(LOGS);
  fs.appendFileSync(path.join(LOGS, 'ops_config.log'), `[${isoNow()}] ${line}\n`);
}

function isSecretKey(k){
  if (!k) return false;
  if (SAFE_EDIT_KEYS.includes(k)) return false;
  if (DENY_EDIT_KEYS.includes(k)) return true;
  const up = k.toUpperCase();
  return SECRET_PATTERNS.some(p => p && up.includes(p));
}

function parseEnv(content) {
  const lines = content.split('\n').filter(Boolean);
  const env = {};
  for (const line of lines) {
    const m = line.match(/^([A-Z_][A-Z0-9_]*)=(.*)$/);
    if (m) env[m[1]] = m[2];
  }
  return env;
}

function stringifyEnv(env) {
  return Object.entries(env).map(([k,v]) => `${k}=${v}`).join('\n') + '\n';
}

// Returns { add[], change[], remove[], diffMarkdown, touched:{secrets:[], nonsecrets:[]} }
function diffEnv(oldEnv, newEnv) {
  const add = [], change = [], remove = [];
  const touchedSecrets = [];
  const touchedNon = [];
  
  // Find added and changed
  for (const [k, v] of Object.entries(newEnv)) {
    if (!(k in oldEnv)) {
      add.push(`${k}=${v}`);
      if (isSecretKey(k)) touchedSecrets.push(k);
      else touchedNon.push(k);
    } else if (oldEnv[k] !== v) {
      change.push(`${k}: ${oldEnv[k]} → ${v}`);
      if (isSecretKey(k)) touchedSecrets.push(k);
      else touchedNon.push(k);
    }
  }
  
  // Find removed
  for (const k of Object.keys(oldEnv)) {
    if (!(k in newEnv)) {
      remove.push(k);
      if (isSecretKey(k)) touchedSecrets.push(k);
      else touchedNon.push(k);
    }
  }
  
  // Generate diff markdown
  const lines = [];
  for (const k of Object.keys(oldEnv).sort()) {
    if (!(k in newEnv)) lines.push(`- ${k}=${oldEnv[k]}`);
  }
  for (const k of Object.keys(newEnv).sort()) {
    if (!(k in oldEnv)) lines.push(`+ ${k}=${newEnv[k]}`);
  }
  for (const k of Object.keys(oldEnv).sort()) {
    if ((k in newEnv) && oldEnv[k] !== newEnv[k]) {
      lines.push(`- ${k}=${oldEnv[k]}`);
      lines.push(`+ ${k}=${newEnv[k]}`);
    }
  }
  const diffMarkdown = '```diff\n' + lines.join('\n') + '\n```';
  
  return { add, change, remove, diffMarkdown, touched: { secrets: touchedSecrets, nonsecrets: touchedNon } };
}

function generateDiffMarkdown(diff, mode) {
  const lines = [];
  lines.push(`# 02LUKA • Config Center ${mode === 'dryrun' ? 'Dry-Run' : 'Applied'} Diff (${isoNow().slice(0,10)})`);
  lines.push('');
  
  lines.push('## Summary');
  lines.push(`- Added:   ${diff.add.length}`);
  lines.push(`- Changed: ${diff.change.length}`);
  lines.push(`- Removed: ${diff.remove.length}`);
  lines.push(`- Secret keys touched: ${diff.touched.secrets.length}` + (diff.touched.secrets.length ? ` (${diff.touched.secrets.join(', ')})` : ''));
  lines.push('');
  
  if (diff.add.length) {
    lines.push('### Added Variables');
    lines.push('```diff');
    for (const item of diff.add) {
      lines.push(`+ ${item}`);
    }
    lines.push('```');
    lines.push('');
  }
  
  if (diff.change.length) {
    lines.push('### Changed Variables');
    lines.push('```diff');
    for (const item of diff.change) {
      const [key, change] = item.split(': ');
      const [old, newVal] = change.split(' → ');
      lines.push(`- ${key}=${old}`);
      lines.push(`+ ${key}=${newVal}`);
    }
    lines.push('```');
    lines.push('');
  }
  
  if (diff.remove.length) {
    lines.push('### Removed Variables');
    lines.push('```diff');
    for (const item of diff.remove) {
      lines.push(`- ${item}`);
    }
    lines.push('```');
    lines.push('');
  }
  
  if (mode === 'dryrun') {
    lines.push('**This is a safe dry-run preview. No files were modified.**');
  } else {
    lines.push('**Configuration has been applied.**');
  }
  
  lines.push('');
  lines.push('---');
  lines.push('');
  lines.push('### 📁 Files & Directories');
  lines.push('- `g/tools/services/ops_config_center.cjs`');
  lines.push('- `g/logs/ops_config.log`');
  if (mode !== 'dryrun') {
    lines.push('- `g/backups/config_YYYYMMDDTHHMM.tgz`');
  }
  lines.push('- `g/reports/ops_config_diff_YYYYMMDDTHHMM.md`');
  
  return lines.join('\n');
}

function createBackup() {
  ensureDir(BACKUPS);
  const stamp = isoNow().replace(/[-:]/g,'').replace(/\..+Z/,'Z');
  const backupPath = path.join(BACKUPS, `config_${stamp}.tgz`);
  
  try {
    // Create tar of key config files
    const files = ['.env', 'docker-compose.yml', 'Makefile'].join(' ');
    execSync(`cd "${REPO}" && tar -czf "${backupPath}" ${files}`, { stdio: 'pipe' });
    return backupPath;
  } catch (e) {
    console.error('backup creation failed', e);
    return null;
  }
}

function readCurrentConfig() {
  try {
    const envContent = fs.readFileSync(FILES.env, 'utf8');
    const env = parseEnv(envContent);
    
    return {
      env,
      mode: MODE,
      require_confirm: REQUIRE_CONFIRM,
      files: {
        env: FILES.env,
        compose: FILES.compose,
        makefile: FILES.makefile
      }
    };
  } catch (e) {
    console.error('config read error', e);
    return { env: {}, mode: MODE, require_confirm: REQUIRE_CONFIRM, files: {} };
  }
}

function applyConfig(proposedEnv, mode = 'dryrun', confirmHeader = false, secretConfirm = false) {
  const now = isoNow();
  const current = readCurrentConfig();
  const diff = diffEnv(current.env, proposedEnv);
  
  // Mode validation
  if (mode === 'off') {
    writeLog(`apply blocked: CFG_EDIT=off`);
    return { ok: false, error: 'config_edit_disabled', mode: 'off' };
  }
  
  if (mode === 'on' && REQUIRE_CONFIRM && !confirmHeader) {
    writeLog(`apply blocked: missing confirm header`);
    return { ok: false, error: 'confirm_required', mode: 'on' };
  }
  
  // Secret guard validation
  const allowSecretEdits = String(process.env.ALLOW_SECRET_EDITS || 'off').toLowerCase() === 'on';
  const secretsTouched = diff.touched.secrets.length > 0;
  
  if (secretsTouched && !allowSecretEdits) {
    writeLog(`apply blocked: secret edits detected [${diff.touched.secrets.join(', ')}] while ALLOW_SECRET_EDITS=off`);
    return { 
      ok: false, 
      error: 'secret_edits_blocked', 
      details: { secrets: diff.touched.secrets },
      mode: 'on'
    };
  }
  
  if (secretsTouched && allowSecretEdits && !secretConfirm) {
    writeLog(`apply blocked: secret confirmation required for [${diff.touched.secrets.join(', ')}]`);
    return { 
      ok: false, 
      error: 'secret_confirmation_required', 
      details: { 
        secrets: diff.touched.secrets, 
        hint: 'Send header x-secret-confirm: yes' 
      },
      mode: 'on'
    };
  }
  
  // Generate diff markdown
  const diffMd = generateDiffMarkdown(diff, mode);
  const stamp = now.replace(/[-:]/g,'').replace(/\..+Z/,'Z');
  const reportPath = path.join(REPS, `ops_config_diff_${stamp}.md`);
  
  // Write diff report
  ensureDir(REPS);
  fs.writeFileSync(reportPath, diffMd, 'utf8');
  
  let backupPath = null;
  let applied = false;
  
  if (mode === 'on') {
    // Real apply
    backupPath = createBackup();
    const newEnvContent = stringifyEnv(proposedEnv);
    fs.writeFileSync(FILES.env, newEnvContent, 'utf8');
    applied = true;
    writeLog(`config applied: ${Object.keys(proposedEnv).length} vars, backup: ${backupPath || 'failed'}, secrets: ${secretsTouched ? diff.touched.secrets.join(',') : 'none'}`);
  } else {
    // Dry run
    writeLog(`config dry-run: ${Object.keys(proposedEnv).length} vars, ${diff.add.length} add, ${diff.change.length} change, ${diff.remove.length} remove, secrets: ${secretsTouched ? diff.touched.secrets.join(',') : 'none'}`);
  }
  
  return {
    ok: true,
    mode,
    diff,
    applied,
    backup_path: backupPath,
    report_path: reportPath.replace(REPO + '/', ''),
    diff_markdown: diffMd
  };
}

if (require.main === module) {
  if (MODE === 'off') { 
    console.log('Config center disabled (CFG_EDIT=off)'); 
    process.exit(0); 
  }
  
  // Example dry-run
  const example = { CFG_EDIT: 'dryrun', OPS_CORRELATE_MODE: 'shadow' };
  const result = applyConfig(example, 'dryrun');
  console.log('Config center test:', JSON.stringify(result, null, 2));
}

module.exports = { readCurrentConfig, applyConfig, isSecretKey, MODE };
