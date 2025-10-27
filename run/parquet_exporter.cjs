#!/usr/bin/env node
"use strict";

const fs = require("fs");
const fsp = require("fs/promises");
const path = require("path");
const { spawn } = require("child_process");

const TAG = "parquet-exporter";

function log(message) {
  process.stdout.write(`[${TAG}] ${message}\n`);
}

function warn(message) {
  process.stderr.write(`[${TAG}] WARN: ${message}\n`);
}

function error(message) {
  process.stderr.write(`[${TAG}] ERROR: ${message}\n`);
}

function escapeSqlString(value) {
  return value.replace(/'/g, "''");
}

async function pathExists(targetPath) {
  try {
    await fsp.access(targetPath);
    return true;
  } catch (err) {
    if (err && (err.code === "ENOENT" || err.code === "ENOTDIR")) {
      return false;
    }
    throw err;
  }
}

function parseArgs() {
  const defaults = {
    inputDir: process.env.PARQUET_EXPORTER_INPUT,
    outputDir: process.env.PARQUET_EXPORTER_OUTPUT,
    filter: process.env.PARQUET_EXPORTER_FILTER,
    maxDepth: process.env.PARQUET_EXPORTER_MAX_DEPTH,
    duckdbBin: process.env.PARQUET_EXPORTER_DUCKDB_BIN || "duckdb",
    force: false,
    dryRun: false,
    manifest: process.env.PARQUET_EXPORTER_MANIFEST,
  };

  const args = process.argv.slice(2);
  const options = { ...defaults };

  function requireValue(flag, index) {
    if (index >= args.length) {
      throw new Error(`${flag} requires a value`);
    }
    return args[index];
  }

  for (let i = 0; i < args.length; i += 1) {
    const arg = args[i];
    switch (arg) {
      case "--input":
      case "--input-dir":
        options.inputDir = requireValue(arg, i + 1);
        i += 1;
        break;
      case "--output":
      case "--output-dir":
        options.outputDir = requireValue(arg, i + 1);
        i += 1;
        break;
      case "--manifest":
        options.manifest = requireValue(arg, i + 1);
        i += 1;
        break;
      case "--filter":
        options.filter = requireValue(arg, i + 1);
        i += 1;
        break;
      case "--max-depth":
        options.maxDepth = Number(requireValue(arg, i + 1));
        i += 1;
        break;
      case "--duckdb":
      case "--duckdb-bin":
        options.duckdbBin = requireValue(arg, i + 1);
        i += 1;
        break;
      case "--force":
        options.force = true;
        break;
      case "--dry-run":
        options.dryRun = true;
        break;
      case "--help":
        printHelp();
        process.exit(0);
        break;
      default:
        throw new Error(`Unknown argument: ${arg}`);
    }
  }

  const repoRoot = path.resolve(__dirname, "..");
  options.repoRoot = repoRoot;
  options.inputDir = path.resolve(repoRoot, options.inputDir || path.join("g", "reports"));
  options.outputDir = path.resolve(repoRoot, options.outputDir || path.join("g", "reports", "parquet"));
  options.manifest = path.resolve(
    repoRoot,
    options.manifest || path.join("g", "reports", "parquet", "export_manifest.json")
  );

  if (options.maxDepth === undefined || Number.isNaN(Number(options.maxDepth))) {
    options.maxDepth = 2;
  }

  options.filterRegex = buildFilterRegex(options.filter);

  return options;
}

function buildFilterRegex(filter) {
  const fallback = /^(query_perf.*\.(?:csv|json|jsonl))$/i;
  if (!filter) {
    return fallback;
  }
  try {
    return new RegExp(filter, "i");
  } catch (err) {
    throw new Error(`Invalid filter regex: ${filter}`);
  }
}

function printHelp() {
  log(`Usage: node run/parquet_exporter.cjs [options]\n\n` +
    `Options:\n` +
    `  --input <dir>           Source directory (default: g/reports)\n` +
    `  --output <dir>          Destination directory for parquet files (default: g/reports/parquet)\n` +
    `  --manifest <path>       Manifest output path (default: g/reports/parquet/export_manifest.json)\n` +
    `  --filter <regex>        Regex applied to relative source paths (default: query_perf*.{csv,json,jsonl})\n` +
    `  --max-depth <n>         Maximum directory depth to traverse (default: 2)\n` +
    `  --duckdb <path>         DuckDB binary to execute (default: duckdb)\n` +
    `  --force                 Re-export even if parquet file is up-to-date\n` +
    `  --dry-run               Simulate the export without calling DuckDB\n` +
    `  --help                  Show this message`);
}

async function runCommand(command, args) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, { stdio: ["ignore", "pipe", "pipe"] });
    let stdout = "";
    let stderr = "";

    child.stdout.on("data", (chunk) => {
      stdout += chunk.toString();
    });

    child.stderr.on("data", (chunk) => {
      stderr += chunk.toString();
    });

    child.once("error", (err) => {
      reject(err);
    });

    child.once("close", (code) => {
      if (code === 0) {
        resolve({ stdout, stderr, code });
      } else {
        const errorObj = new Error(`Command failed with exit code ${code}: ${command}`);
        errorObj.stdout = stdout;
        errorObj.stderr = stderr;
        errorObj.code = code;
        reject(errorObj);
      }
    });
  });
}

async function verifyDuckDBAvailable(binPath) {
  try {
    const result = await runCommand(binPath, ["--version"]);
    return result.stdout.trim() || "unknown";
  } catch (err) {
    if (err.code === "ENOENT") {
      throw new Error(`DuckDB binary not found: ${binPath}`);
    }
    throw new Error(`Failed to execute DuckDB (${binPath}): ${err.stderr || err.message}`);
  }
}

async function collectSources(baseDir, options) {
  const items = [];
  const outputRelative = path.relative(baseDir, options.outputDir);
  const ignoredPaths = new Set();
  if (!outputRelative.startsWith("..")) {
    ignoredPaths.add(path.normalize(outputRelative));
  }

  async function walk(currentDir, depth, relativeDir = "") {
    const entries = await fsp.readdir(currentDir, { withFileTypes: true });
    for (const entry of entries) {
      const relativePath = relativeDir ? path.join(relativeDir, entry.name) : entry.name;
      const fullPath = path.join(currentDir, entry.name);
      if (entry.isDirectory()) {
        const normalized = path.normalize(relativePath);
        if (ignoredPaths.has(normalized)) {
          continue;
        }
        if (depth < options.maxDepth) {
          await walk(fullPath, depth + 1, relativePath);
        }
      } else if (entry.isFile()) {
        if (options.filterRegex.test(relativePath)) {
          items.push({ fullPath, relativePath });
        }
      }
    }
  }

  await walk(baseDir, 0, "");
  items.sort((a, b) => a.relativePath.localeCompare(b.relativePath));
  return items;
}

function determineOutputPath(relativePath) {
  const ext = path.extname(relativePath);
  if (!ext) {
    return `${relativePath}.parquet`;
  }
  const base = relativePath.slice(0, -ext.length);
  const normalizedExt = ext.replace(/\./g, "").toLowerCase();
  return `${base}.${normalizedExt}.parquet`;
}

async function ensureDirectory(targetDir) {
  await fsp.mkdir(targetDir, { recursive: true });
}

async function exportFile(entry, options, manifest) {
  const { fullPath, relativePath } = entry;
  const sourceStats = await fsp.stat(fullPath);
  const outputRelative = determineOutputPath(relativePath);
  const outputPath = path.join(options.outputDir, outputRelative);
  const outputDir = path.dirname(outputPath);
  await ensureDirectory(outputDir);

  let outputExists = await pathExists(outputPath);
  let outputStats = null;
  if (outputExists) {
    outputStats = await fsp.stat(outputPath);
  }

  const summaryEntry = {
    source: path.relative(options.repoRoot, fullPath),
    sourceRelative: relativePath,
    sourceMTime: sourceStats.mtime.toISOString(),
    sourceSizeBytes: sourceStats.size,
    output: path.relative(options.repoRoot, outputPath),
    outputRelative,
    status: "skipped",
    message: "Up-to-date",
  };

  const needsExport =
    options.force ||
    !outputExists ||
    (outputStats && outputStats.mtimeMs < sourceStats.mtimeMs);

  if (!needsExport) {
    if (outputStats) {
      summaryEntry.outputMTime = outputStats.mtime.toISOString();
      summaryEntry.outputSizeBytes = outputStats.size;
    }
    manifest.exports.push(summaryEntry);
    return;
  }

  if (options.dryRun) {
    summaryEntry.status = "dry-run";
    summaryEntry.message = "Dry run — export skipped";
    manifest.exports.push(summaryEntry);
    return;
  }

  const ext = path.extname(fullPath).toLowerCase();
  let reader;
  if (ext === ".csv") {
    reader = `read_csv_auto('${escapeSqlString(fullPath)}')`;
  } else if (ext === ".json" || ext === ".jsonl") {
    reader = `read_json_auto('${escapeSqlString(fullPath)}')`;
  } else {
    summaryEntry.status = "ignored";
    summaryEntry.message = `Unsupported extension: ${ext}`;
    manifest.exports.push(summaryEntry);
    return;
  }

  const sql =
    `COPY (SELECT * FROM ${reader}) TO '${escapeSqlString(outputPath)}' ` +
    "(FORMAT 'parquet', COMPRESSION 'SNAPPY');";

  log(`Exporting ${relativePath} -> ${path.relative(options.repoRoot, outputPath)}`);
  await runCommand(options.duckdbBin, [":memory:", "-c", sql]);

  outputExists = true;
  outputStats = await fsp.stat(outputPath);

  summaryEntry.status = "exported";
  summaryEntry.message = "Export completed";
  summaryEntry.outputMTime = outputStats.mtime.toISOString();
  summaryEntry.outputSizeBytes = outputStats.size;
  manifest.exports.push(summaryEntry);
}

async function buildManifest(options) {
  const manifest = {
    generatedAt: new Date().toISOString(),
    repoRoot: options.repoRoot,
    inputDir: path.relative(options.repoRoot, options.inputDir),
    outputDir: path.relative(options.repoRoot, options.outputDir),
    duckdb: null,
    compression: "SNAPPY",
    dryRun: options.dryRun,
    filter: options.filterRegex.source,
    summary: {
      totalSources: 0,
      exported: 0,
      skipped: 0,
      dryRun: 0,
      ignored: 0,
      failed: 0,
    },
    exports: [],
  };

  if (!options.dryRun) {
    const version = await verifyDuckDBAvailable(options.duckdbBin);
    manifest.duckdb = { bin: options.duckdbBin, version };
  } else {
    manifest.duckdb = { bin: options.duckdbBin, version: "dry-run" };
  }

  await ensureDirectory(options.outputDir);
  const sources = await collectSources(options.inputDir, options);
  manifest.summary.totalSources = sources.length;

  for (const source of sources) {
    try {
      await exportFile(source, options, manifest);
    } catch (err) {
      error(`Failed to export ${source.relativePath}: ${err.message}`);
      manifest.exports.push({
        source: path.relative(options.repoRoot, source.fullPath),
        sourceRelative: source.relativePath,
        status: "failed",
        message: err.message,
      });
    }
  }

  for (const entry of manifest.exports) {
    switch (entry.status) {
      case "exported":
        manifest.summary.exported += 1;
        break;
      case "dry-run":
        manifest.summary.dryRun += 1;
        break;
      case "skipped":
        manifest.summary.skipped += 1;
        break;
      case "ignored":
        manifest.summary.ignored += 1;
        break;
      case "failed":
        manifest.summary.failed += 1;
        break;
      default:
        break;
    }
  }

  return manifest;
}

async function writeManifest(manifest, options) {
  await ensureDirectory(path.dirname(options.manifest));
  await fsp.writeFile(options.manifest, `${JSON.stringify(manifest, null, 2)}\n`, "utf8");
  log(`Manifest written to ${path.relative(options.repoRoot, options.manifest)}`);
}

async function main() {
  try {
    const options = parseArgs();
    log(`Starting Parquet export with DuckDB=${options.duckdbBin}`);
    const manifest = await buildManifest(options);
    await writeManifest(manifest, options);

    if (manifest.summary.failed > 0) {
      throw new Error(`${manifest.summary.failed} export(s) failed`);
    }

    if (manifest.summary.totalSources === 0) {
      warn("No source files matched the configured filter");
    }

    log(
      `Finished: total=${manifest.summary.totalSources}, exported=${manifest.summary.exported}, ` +
        `skipped=${manifest.summary.skipped}, dryRun=${manifest.summary.dryRun}`
    );
  } catch (err) {
    error(err.message || String(err));
    process.exitCode = 1;
  }
}

main();
