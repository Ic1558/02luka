// packages/fs/secureFS.js
const fs = require("fs/promises");
const path = require("path");

const roots = (process.env.CLS_FS_ALLOW || "")
  .split(":").filter(Boolean).map(p => path.resolve(p));

function assertAllowed(p) {
  const abs = path.resolve(p);
  if (!roots.length) throw new Error("CLS_FS_ALLOW not set");
  const ok = roots.some(root => abs === root || abs.startsWith(root + path.sep));
  if (!ok) throw new Error(`Blocked path: ${abs} (outside allowlist)`);
  return abs;
}

async function mkdirp(p){ await fs.mkdir(assertAllowed(p), { recursive:true }); }
async function readFile(p, enc = "utf8"){ return fs.readFile(assertAllowed(p), enc); }
async function writeFile(p, data, enc = "utf8"){ return fs.writeFile(assertAllowed(p), data, enc); }
async function stat(p){ return fs.stat(assertAllowed(p)); }
async function readdir(p){ return fs.readdir(assertAllowed(p)); }
async function unlink(p){ return fs.unlink(assertAllowed(p)); }
async function rename(src, dst){ assertAllowed(src); assertAllowed(dst); return fs.rename(src, dst); }

module.exports = { roots, assertAllowed, mkdirp, readFile, writeFile, stat, readdir, unlink, rename };
