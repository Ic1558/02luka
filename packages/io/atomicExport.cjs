// packages/io/atomicExport.cjs
// Shared utility for safe file writes to Google Drive paths
// Uses temp-then-move pattern to prevent blocking on cloud sync

const fs = require('fs');
const fsp = require('fs').promises;
const path = require('path');
const os = require('os');

function getDirs(targetDir, argv = process.argv, env = process.env) {
  const direct = env.EXPORT_DIRECT === '1' || argv.includes('--export-direct');
  const tmpRoot = env.EXPORT_TMP_DIR || path.join(os.tmpdir(), '02luka-exports');
  const tmpOut = direct ? targetDir : path.join(tmpRoot, String(process.pid));
  return { direct, tmpOut, finalOut: targetDir };
}

async function ensureDir(p) {
  await fsp.mkdir(p, { recursive: true });
}

async function atomicMove(src, dst) {
  await ensureDir(path.dirname(dst));
  await fsp.rename(src, dst); // atomic on same volume
}

async function writeArtifacts({ targetDir, artifacts, argv, env, log = console }) {
  const { direct, tmpOut, finalOut } = getDirs(targetDir, argv, env);
  log.log(`[export] mode=${direct ? 'direct' : 'temp-then-move'} → ${finalOut}`);
  await ensureDir(tmpOut);

  for (const { name, data } of artifacts) {
    const tmp = path.join(tmpOut, name);
    process.stdout.write(`  • writing ${name}... `);
    await fsp.writeFile(tmp, data, 'utf8');
    process.stdout.write('✓\n');
  }

  if (!direct) {
    process.stdout.write('  • staging → final (atomic move)... ');
    for (const { name } of artifacts) {
      await atomicMove(path.join(tmpOut, name), path.join(finalOut, name));
    }
    await fsp.rm(tmpOut, { recursive: true, force: true }).catch(() => {});
    process.stdout.write('✓\n');
  }
  log.log('[export] complete');
}

// Synchronous version for backwards compatibility (uses async internally but waits)
function writeArtifactsSync({ targetDir, artifacts, argv, env, log = console }) {
  return new Promise((resolve, reject) => {
    writeArtifacts({ targetDir, artifacts, argv, env, log })
      .then(resolve)
      .catch(reject);
  });
}

module.exports = { writeArtifacts, writeArtifactsSync, getDirs, ensureDir, atomicMove };
