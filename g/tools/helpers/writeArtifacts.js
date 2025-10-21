/**
 * Safe, fast writes for cloud-mirrored folders.
 * Strategy: write to tmp file near the target, then atomic rename (move).
 */
const fs = require('fs');
const path = require('path');
const os = require('os');

async function ensureDir(p) {
  await fs.promises.mkdir(p, { recursive: true });
}

async function writeOne(targetDir, name, data) {
  const finalPath = path.join(targetDir, name);
  const tmpDir = path.join(os.tmpdir(), '02luka-artifacts');
  await ensureDir(tmpDir);
  // Write into OS tmp first (always fast), then move into place.
  const tmpFile = path.join(tmpDir, `${Date.now()}_${Math.random().toString(16).slice(2)}_${name}`);
  await fs.promises.writeFile(tmpFile, data);
  await ensureDir(targetDir);
  await fs.promises.rename(tmpFile, finalPath);
  return finalPath;
}

async function writeArtifacts({ targetDir, artifacts, log = console }) {
  const results = [];
  for (const art of artifacts) {
    const dest = await writeOne(targetDir, art.name, art.data);
    log.log(`artifact: ${dest}`);
    results.push(dest);
  }
  return results;
}

module.exports = { writeArtifacts };
