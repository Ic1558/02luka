#!/usr/bin/env node
"use strict";

const http = require("http");
const fsp = require("fs/promises");
const path = require("path");

const DEFAULT_PORT = 4000;
const PORT = Number(process.env.PORT || process.env.BOSS_PORT || DEFAULT_PORT) || DEFAULT_PORT;
const DIST_DIR = process.env.OPS_DIST_DIR || path.join(__dirname, "..", "dist", "ops");
const JOBS_FILE = process.env.JOBS_FILE || path.join(DIST_DIR, "jobs.json");
const STATUS_FILE = process.env.STATUS_FILE || path.join(DIST_DIR, "status.html");
const BRANCHES_DIR = process.env.BOSS_BRANCHES_DIR || path.join(DIST_DIR, "branches");
const DEFAULT_BRANCH = process.env.DEFAULT_BRANCH || "main";

function sanitizeBranchName(rawBranch) {
  if (rawBranch === undefined || rawBranch === null) {
    return DEFAULT_BRANCH;
  }

  const trimmed = String(rawBranch).trim();
  if (trimmed === "") {
    return DEFAULT_BRANCH;
  }

  const segments = trimmed.split("/");
  const validSegments = [];

  for (const segment of segments) {
    if (!segment || segment === "." || segment === ".." || !/^[A-Za-z0-9._-]+$/.test(segment)) {
      return null;
    }
    validSegments.push(segment);
  }

  return validSegments.join("/");
}

async function listAvailableBranches() {
  const branches = new Set([DEFAULT_BRANCH]);

  try {
    const entries = await fsp.readdir(BRANCHES_DIR, { withFileTypes: true });
    for (const entry of entries) {
      if (entry.isDirectory()) {
        branches.add(entry.name);
      }
    }
  } catch (error) {
    if (error.code !== "ENOENT") {
      throw error;
    }
  }

  return Array.from(branches).sort((a, b) => a.localeCompare(b));
}

function createBranchError(statusCode, branchValue, availableBranches) {
  const err = new Error("branch_invalid");
  err.statusCode = statusCode;
  err.details = {
    message: `Branch '${branchValue}' is not available. Check all PR builds via /api/branches for valid options.`,
    requested_branch: branchValue,
    available_branches: availableBranches,
  };
  return err;
}

async function resolveBranchPaths(branchParam) {
  const sanitized = sanitizeBranchName(branchParam);

  if (!sanitized) {
    const available = await listAvailableBranches();
    throw createBranchError(400, branchParam, available);
  }

  if (sanitized === DEFAULT_BRANCH) {
    return {
      branchName: DEFAULT_BRANCH,
      jobsFile: JOBS_FILE,
      statusFile: STATUS_FILE,
    };
  }

  const branchDir = path.join(BRANCHES_DIR, sanitized);
  const jobsPath = path.join(branchDir, "jobs.json");
  const statusPath = path.join(branchDir, "status.html");

  try {
    await fsp.access(jobsPath);
  } catch (error) {
    if (error.code === "ENOENT") {
      const available = await listAvailableBranches();
      throw createBranchError(404, sanitized, available);
    }
    throw error;
  }

  return {
    branchName: sanitized,
    jobsFile: jobsPath,
    statusFile: statusPath,
  };
}

function sendJson(res, statusCode, payload, extraHeaders = {}) {
  const body = payload === undefined ? "" : JSON.stringify(payload);
  const headers = {
    "Content-Type": "application/json; charset=utf-8",
    "Cache-Control": "no-store",
    ...extraHeaders,
  };
  if (res.req.method === "HEAD") {
    res.writeHead(statusCode, headers);
    return res.end();
  }
  res.writeHead(statusCode, headers);
  res.end(body);
}

function sendHtml(res, statusCode, html) {
  const headers = {
    "Content-Type": "text/html; charset=utf-8",
    "Cache-Control": "no-store",
  };
  if (res.req.method === "HEAD") {
    res.writeHead(statusCode, headers);
    return res.end();
  }
  res.writeHead(statusCode, headers);
  res.end(html);
}

async function loadJobs(jobsFile) {
  let raw;
  try {
    raw = await fsp.readFile(jobsFile, "utf8");
  } catch (error) {
    const err = new Error("jobs_file_unavailable");
    err.statusCode = 503;
    err.details = { message: `Unable to read jobs file at ${jobsFile}`, cause: error.message };
    throw err;
  }

  let data;
  try {
    data = JSON.parse(raw);
  } catch (error) {
    const err = new Error("jobs_file_invalid_json");
    err.statusCode = 500;
    err.details = { message: "Jobs file is not valid JSON", cause: error.message };
    throw err;
  }

  if (!data || typeof data !== "object" || !Array.isArray(data.runs)) {
    const err = new Error("jobs_file_missing_runs");
    err.statusCode = 500;
    err.details = { message: "Jobs file missing required 'runs' array" };
    throw err;
  }

  return data;
}

function summarizeRuns(data) {
  const runs = data.runs || [];
  let success = 0;
  let failure = 0;
  let totalDuration = 0;
  let durationCount = 0;
  let totalSize = 0;
  let sizeCount = 0;

  for (const run of runs) {
    if (run && typeof run === "object") {
      if (String(run.status).toLowerCase() === "success") success += 1;
      else failure += 1;

      if (Number.isFinite(run.duration_ms)) {
        totalDuration += run.duration_ms;
        durationCount += 1;
      }

      if (Number.isFinite(run.total_size_bytes)) {
        totalSize += run.total_size_bytes;
        sizeCount += 1;
      }
    }
  }

  const averageDuration = durationCount > 0 ? totalDuration / durationCount : null;
  const averageSize = sizeCount > 0 ? totalSize / sizeCount : null;

  return {
    total_runs: runs.length,
    successful_runs: success,
    failed_runs: failure,
    average_duration_ms: averageDuration,
    average_size_bytes: averageSize,
    last_updated: data.last_updated || null,
    latest_run: runs[0] || null,
  };
}

async function getStatusPayload(branchContext) {
  const jobs = await loadJobs(branchContext.jobsFile);
  const summary = summarizeRuns(jobs);
  const status = summary.failed_runs > 0 ? "degraded" : "healthy";
  return {
    ok: true,
    status,
    updated_at: summary.last_updated,
    summary,
    branch: branchContext.branchName,
  };
}

async function serveStatusHtml(res, branchContext) {
  let html;
  try {
    html = await fsp.readFile(branchContext.statusFile, "utf8");
  } catch (error) {
    const message = `Status page not available at ${branchContext.statusFile}`;
    sendJson(res, 503, { ok: false, error: "status_page_unavailable", message, branch: branchContext.branchName });
    return;
  }
  sendHtml(res, 200, html);
}

async function handleRequest(req, res) {
  const url = new URL(req.url, `http://localhost:${PORT}`);
  const method = req.method.toUpperCase();
  const branchParam = url.searchParams.get("branch");
  let branchContextPromise = null;

  function ensureBranchContext() {
    if (!branchContextPromise) {
      branchContextPromise = resolveBranchPaths(branchParam);
    }
    return branchContextPromise;
  }

  if (method !== "GET" && method !== "HEAD") {
    return sendJson(res, 405, { ok: false, error: "method_not_allowed" }, { "Allow": "GET, HEAD" });
  }

  if (url.pathname === "/" || url.pathname === "/status") {
    try {
      const branchContext = await ensureBranchContext();
      return serveStatusHtml(res, branchContext);
    } catch (error) {
      const statusCode = error.statusCode || 500;
      return sendJson(res, statusCode, { ok: false, error: error.message || "status_unavailable", details: error.details });
    }
  }

  if (url.pathname === "/healthz" || url.pathname === "/health") {
    try {
      const branchContext = await ensureBranchContext();
      const payload = await getStatusPayload(branchContext);
      return sendJson(res, 200, {
        ...payload,
        service: "boss-api",
        port: PORT,
      });
    } catch (error) {
      const statusCode = error.statusCode || 500;
      return sendJson(res, statusCode, {
        ok: false,
        error: error.message || "health_check_failed",
        details: error.details || undefined,
      });
    }
  }

  if (url.pathname === "/api/jobs") {
    try {
      const branchContext = await ensureBranchContext();
      const jobs = await loadJobs(branchContext.jobsFile);
      return sendJson(res, 200, { ok: true, branch: branchContext.branchName, ...jobs });
    } catch (error) {
      const statusCode = error.statusCode || 500;
      return sendJson(res, statusCode, {
        ok: false,
        error: error.message || "jobs_unavailable",
        details: error.details || undefined,
      });
    }
  }

  if (url.pathname === "/api/status") {
    try {
      const branchContext = await ensureBranchContext();
      const payload = await getStatusPayload(branchContext);
      return sendJson(res, 200, payload);
    } catch (error) {
      const statusCode = error.statusCode || 500;
      return sendJson(res, statusCode, {
        ok: false,
        error: error.message || "status_unavailable",
        details: error.details || undefined,
      });
    }
  }

  if (url.pathname === "/api/branches") {
    try {
      const branches = await listAvailableBranches();
      return sendJson(res, 200, {
        ok: true,
        default_branch: DEFAULT_BRANCH,
        branches,
      });
    } catch (error) {
      const statusCode = error.statusCode || 500;
      return sendJson(res, statusCode, {
        ok: false,
        error: error.message || "branches_unavailable",
        details: error.details || undefined,
      });
    }
  }

  if (url.pathname === "/api/capabilities") {
    return sendJson(res, 200, {
      ok: true,
      service: "boss-api",
      capabilities: [
        { path: "/healthz", method: "GET", description: "Service health summary" },
        { path: "/status", method: "GET", description: "Rendered status dashboard" },
        { path: "/api/status", method: "GET", description: "Aggregated job summary" },
        { path: "/api/jobs", method: "GET", description: "Raw job run metadata" },
        { path: "/api/branches", method: "GET", description: "List available branches for PR builds" },
      ],
    });
  }

  return sendJson(res, 404, { ok: false, error: "not_found" });
}

const server = http.createServer((req, res) => {
  handleRequest(req, res).catch((error) => {
    console.error("Unexpected error while handling request", error);
    sendJson(res, 500, { ok: false, error: "internal_error" });
  });
});

server.listen(PORT, () => {
  console.log(`[${new Date().toISOString()}] boss-api listening on port ${PORT}`);
  console.log(`[${new Date().toISOString()}] Jobs file: ${JOBS_FILE}`);
  console.log(`[${new Date().toISOString()}] Status file: ${STATUS_FILE}`);
});

process.on("SIGTERM", () => {
  console.log(`[${new Date().toISOString()}] boss-api shutting down`);
  server.close(() => process.exit(0));
});

process.on("SIGINT", () => {
  console.log(`[${new Date().toISOString()}] boss-api received interrupt`);
  server.close(() => process.exit(0));
});
