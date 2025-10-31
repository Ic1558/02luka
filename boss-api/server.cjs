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

async function loadJobs() {
  let raw;
  try {
    raw = await fsp.readFile(JOBS_FILE, "utf8");
  } catch (error) {
    const err = new Error("jobs_file_unavailable");
    err.statusCode = 503;
    err.details = { message: `Unable to read jobs file at ${JOBS_FILE}`, cause: error.message };
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

async function getStatusPayload() {
  const jobs = await loadJobs();
  const summary = summarizeRuns(jobs);
  const status = summary.failed_runs > 0 ? "degraded" : "healthy";
  return {
    ok: true,
    status,
    updated_at: summary.last_updated,
    summary,
  };
}

async function serveStatusHtml(res) {
  let html;
  try {
    html = await fsp.readFile(STATUS_FILE, "utf8");
  } catch (error) {
    const message = `Status page not available at ${STATUS_FILE}`;
    sendJson(res, 503, { ok: false, error: "status_page_unavailable", message });
    return;
  }
  sendHtml(res, 200, html);
}

async function handleRequest(req, res) {
  const url = new URL(req.url, `http://localhost:${PORT}`);
  const method = req.method.toUpperCase();

  if (method !== "GET" && method !== "HEAD") {
    return sendJson(res, 405, { ok: false, error: "method_not_allowed" }, { "Allow": "GET, HEAD" });
  }

  if (url.pathname === "/" || url.pathname === "/status") {
    return serveStatusHtml(res);
  }

  if (url.pathname === "/healthz" || url.pathname === "/health") {
    try {
      const payload = await getStatusPayload();
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
      const jobs = await loadJobs();
      return sendJson(res, 200, { ok: true, ...jobs });
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
      const payload = await getStatusPayload();
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

  if (url.pathname === "/api/capabilities") {
    return sendJson(res, 200, {
      ok: true,
      service: "boss-api",
      capabilities: [
        { path: "/healthz", method: "GET", description: "Service health summary" },
        { path: "/status", method: "GET", description: "Rendered status dashboard" },
        { path: "/api/status", method: "GET", description: "Aggregated job summary" },
        { path: "/api/jobs", method: "GET", description: "Raw job run metadata" },
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
