#!/usr/bin/env node
import fs from "fs/promises";
import path from "path";
import process from "process";
import { fileURLToPath } from "url";
import YAML from "yaml";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, "..");

const configPath = path.join(repoRoot, "config", "pr_score.yaml");

function fatal(message, error) {
  console.error(`::error ::${message}`);
  if (error) {
    console.error(error);
  }
  process.exit(1);
}

function globToRegExp(glob) {
  const specialChars = /[\\^$+.()|{}\[\]]/g;
  let pattern = glob.replace(specialChars, "\\$&");
  pattern = pattern.replace(/\*\*/g, "\u0000");
  pattern = pattern.replace(/\*/g, "[^/]*");
  pattern = pattern.replace(/\u0000/g, ".*");
  return new RegExp(`^${pattern}$`);
}

function pathMatches(pathname, patterns = []) {
  return patterns.some((regex) => regex.test(pathname));
}

function normalizePrefixes(prefixes = []) {
  return prefixes.map((prefix) => (prefix.endsWith("/") ? prefix : `${prefix}`));
}

async function loadConfig() {
  try {
    const raw = await fs.readFile(configPath, "utf8");
    const data = YAML.parse(raw);
    const compiled = { ...data };
    compiled.docs_tests = {
      ...data.docs_tests,
      regexes: (data.docs_tests?.patterns || []).map(globToRegExp),
    };
    compiled.reality_hooks = {
      ...data.reality_hooks,
      regexes: (data.reality_hooks?.patterns || []).map(globToRegExp),
    };
    compiled.scope_risk = {
      ...data.scope_risk,
      high_risk_paths: normalizePrefixes(data.scope_risk?.high_risk_paths || []),
      medium_risk_paths: normalizePrefixes(data.scope_risk?.medium_risk_paths || []),
    };
    compiled.governance = {
      ...data.governance,
      forbidden_paths: normalizePrefixes(data.governance?.forbidden_paths || []),
    };
    compiled.labels =
      data.labels || [
        { name: "score:90+", min: 90 },
        { name: "score:80-89", min: 80, max: 89.99 },
        { name: "score:70-79", min: 70, max: 79.99 },
        { name: "score:<=69", min: 0, max: 69.99 },
      ];
    return compiled;
  } catch (error) {
    fatal("Unable to read pr_score.yaml configuration", error);
  }
}

async function readEventPayload() {
  const eventPath = process.env.GITHUB_EVENT_PATH;
  if (!eventPath) {
    fatal("GITHUB_EVENT_PATH is not defined.");
  }
  try {
    const raw = await fs.readFile(eventPath, "utf8");
    return JSON.parse(raw);
  } catch (error) {
    fatal("Failed to read GitHub event payload", error);
  }
}

function getRepoInfo() {
  const repo = process.env.GITHUB_REPOSITORY;
  if (!repo) {
    fatal("GITHUB_REPOSITORY is not defined.");
  }
  const [owner, name] = repo.split("/");
  return { owner, repo: name };
}

function getHeaders(token) {
  return {
    Accept: "application/vnd.github+json",
    Authorization: `Bearer ${token}`,
    "X-GitHub-Api-Version": "2022-11-28",
  };
}

async function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function ghRequest(method, url, token, body, retries = 3) {
  let lastError;
  for (let attempt = 0; attempt < retries; attempt++) {
    try {
      const response = await fetch(url, {
        method,
        headers: {
          ...getHeaders(token),
          "Content-Type": body ? "application/json" : undefined,
        },
        body: body ? JSON.stringify(body) : undefined,
      });
      if (!response.ok) {
        const text = await response.text();
        // Retry on 5xx errors or rate limits
        if (response.status >= 500 || response.status === 429) {
          lastError = new Error(
            `GitHub API request failed: ${method} ${url} -> ${response.status} ${response.statusText}\n${text}`
          );
          if (attempt < retries - 1) {
            const delay = Math.min(1000 * Math.pow(2, attempt), 8000);
            console.error(`::warning ::Retrying after ${delay}ms (attempt ${attempt + 1}/${retries})...`);
            await sleep(delay);
            continue;
          }
        }
        fatal(`GitHub API request failed: ${method} ${url} -> ${response.status} ${response.statusText}\n${text}`);
      }
      if (response.status === 204) {
        return null;
      }
      return response.json();
    } catch (error) {
      lastError = error;
      if (attempt < retries - 1) {
        const delay = Math.min(1000 * Math.pow(2, attempt), 8000);
        console.error(`::warning ::Network error, retrying after ${delay}ms (attempt ${attempt + 1}/${retries})...`);
        await sleep(delay);
        continue;
      }
    }
  }
  fatal("GitHub API request failed after retries", lastError);
}

async function paginate(url, token) {
  let next = url;
  const results = [];
  while (next) {
    const response = await fetch(next, {
      headers: getHeaders(token),
    });
    if (!response.ok) {
      const text = await response.text();
      fatal(`Failed to paginate ${next}: ${response.status} ${response.statusText}\n${text}`);
    }
    const data = await response.json();
    results.push(...data);
    const link = response.headers.get("link");
    if (link && link.includes('rel="next"')) {
      const match = link.split(",").find((segment) => segment.includes('rel="next"'));
      next = match ? match.split(";")[0].trim().slice(1, -1) : null;
    } else {
      next = null;
    }
  }
  return results;
}

function evaluateScopeRisk(files, config) {
  let severity = "low";
  for (const file of files) {
    const filename = file.filename;
    if (config.high_risk_paths.some((prefix) => filename.startsWith(prefix))) {
      severity = "high";
      break;
    }
    if (
      severity !== "medium" &&
      config.medium_risk_paths.some((prefix) => filename.startsWith(prefix))
    ) {
      severity = "medium";
    }
  }
  const score = config.scores?.[severity] ?? 1;
  return { score, severity };
}

function evaluateChangeSize(pr, config) {
  const totalChanges = (pr.additions || 0) + (pr.deletions || 0);
  let band = "huge";
  if (totalChanges <= config.thresholds.small) {
    band = "small";
  } else if (totalChanges <= config.thresholds.medium) {
    band = "medium";
  } else if (totalChanges <= config.thresholds.large) {
    band = "large";
  }
  const score = config.scores?.[band] ?? 0;
  return { score, band, totalChanges };
}

function evaluateFreshness(pr, config) {
  const updatedAt = new Date(pr.updated_at);
  const now = new Date();
  const diffHours = (now - updatedAt) / (1000 * 60 * 60);
  const score = diffHours <= config.threshold_hours ? 1 : config.stale_score ?? 0;
  return { score, diffHours };
}

function evaluateDocsTests(files, config) {
  const matched = files.some((file) => pathMatches(file.filename, config.regexes));
  return { score: matched ? 1 : 0, matched };
}

function evaluateGovernance(files, config) {
  const violations = files
    .filter((file) => config.forbidden_paths.some((prefix) => file.filename.startsWith(prefix)))
    .map((file) => file.filename);
  return { score: violations.length === 0 ? 1 : 0, violations };
}

function evaluateRealityHooks(files, config) {
  const matchedFiles = files
    .filter((file) => pathMatches(file.filename, config.regexes))
    .map((file) => file.filename);
  return { score: matchedFiles.length > 0 ? 1 : 0, matchedFiles };
}

function evaluateCiStatus(statusState) {
  let score = 0;
  let stateLabel = statusState;
  switch (statusState) {
    case "success":
      score = 1;
      stateLabel = "success";
      break;
    case "failure":
    case "error":
      score = 0;
      break;
    case "pending":
    default:
      score = 0.5;
      stateLabel = statusState || "unknown";
      break;
  }
  return { score, stateLabel };
}

function evaluateMergeability(pr) {
  const state = pr.mergeable_state || "unknown";
  let score = 0;
  if (state === "clean" || state === "unstable") {
    score = state === "clean" ? 1 : 0.7;
  } else if (state === "has_hooks") {
    score = 0.5;
  } else {
    score = 0;
  }
  return { score, state };
}

function selectLabel(labels, score) {
  for (const bucket of labels) {
    const min = bucket.min ?? 0;
    const max = bucket.max ?? 100;
    if (score >= min && score <= max) {
      return bucket.name;
    }
  }
  return labels[labels.length - 1]?.name;
}

function formatScore(value) {
  return Number.parseFloat(value.toFixed(2));
}

function buildComment(score, breakdown, labelName, jsonPayload) {
  const lines = [];
  lines.push("<!-- pr-score -->");
  lines.push(`### Readiness Score: ${formatScore(score)} / 100`);
  lines.push("");
  lines.push("| Signal | Weight | Raw | Contribution | Notes |");
  lines.push("| --- | --- | --- | --- | --- |");
  for (const item of breakdown) {
    lines.push(
      `| ${item.name} | ${(item.weight * 100).toFixed(0)}% | ${item.raw.toFixed(2)} | ${item.contribution.toFixed(2)} | ${item.notes ?? ""} |`
    );
  }
  lines.push("");
  lines.push(`**Label:** \`${labelName}\``);
  lines.push("");
  lines.push("```json");
  lines.push(JSON.stringify(jsonPayload, null, 2));
  lines.push("```");
    return lines.join("\n");
}

async function ensureLabel(token, owner, repo, prNumber, labelName) {
  const urlBase = `https://api.github.com/repos/${owner}/${repo}`;
  const issueLabels = await paginate(`${urlBase}/issues/${prNumber}/labels?per_page=100`, token);
  const existingScoreLabels = issueLabels.filter((label) => label.name.startsWith("score:"));
  const hasTarget = existingScoreLabels.some((label) => label.name === labelName);
  for (const label of existingScoreLabels) {
    if (label.name !== labelName) {
      await ghRequest(
        "DELETE",
        `${urlBase}/issues/${prNumber}/labels/${encodeURIComponent(label.name)}`,
        token
      );
    }
  }
  if (!hasTarget) {
    await ghRequest("POST", `${urlBase}/issues/${prNumber}/labels`, token, { labels: [labelName] });
  }
}

async function upsertComment(token, owner, repo, prNumber, body) {
  const urlBase = `https://api.github.com/repos/${owner}/${repo}`;
  const comments = await paginate(`${urlBase}/issues/${prNumber}/comments?per_page=100`, token);
  const marker = "<!-- pr-score -->";
  const existing = comments.find((comment) => comment.body?.includes(marker));
  if (existing) {
    await ghRequest("PATCH", `${urlBase}/issues/comments/${existing.id}`, token, { body });
  } else {
    await ghRequest("POST", `${urlBase}/issues/${prNumber}/comments`, token, { body });
  }
}

(async function main() {
  const token = process.env.GITHUB_TOKEN || process.env.PAT;
  if (!token) {
    fatal("GITHUB_TOKEN (or PAT) must be provided to score the pull request.");
  }

  const config = await loadConfig();
  const event = await readEventPayload();
  if (!event.pull_request) {
    fatal("This workflow is expected to run on pull_request events.");
  }

  const prNumber = event.number || event.pull_request.number;
  const { owner, repo } = getRepoInfo();
  const prUrl = `https://api.github.com/repos/${owner}/${repo}/pulls/${prNumber}`;

  // Parallel fetch: get PR data first, then parallelize files and status
  const startTime = Date.now();
  const pr = await ghRequest("GET", prUrl, token);

  // Fetch files and status in parallel (both depend on pr.head.sha)
  const [files, status] = await Promise.all([
    paginate(`${prUrl}/files?per_page=100`, token),
    ghRequest(
      "GET",
      `https://api.github.com/repos/${owner}/${repo}/commits/${pr.head.sha}/status`,
      token
    ),
  ]);

  const ci = evaluateCiStatus(status.state);
  const scope = evaluateScopeRisk(files, config.scope_risk);
  const changes = evaluateChangeSize(pr, config.change_size);
  const mergeability = evaluateMergeability(pr);
  const freshness = evaluateFreshness(pr, config.freshness);
  const docsTests = evaluateDocsTests(files, config.docs_tests);
  const governance = evaluateGovernance(files, config.governance);
  const reality = evaluateRealityHooks(files, config.reality_hooks);

  const breakdown = [
    {
      key: "ci_status",
      name: "CI status",
      weight: config.weights.ci_status,
      raw: ci.score,
      contribution: ci.score * config.weights.ci_status * 100,
      notes: `state: ${ci.stateLabel}`,
    },
    {
      key: "scope_risk",
      name: "Scope risk",
      weight: config.weights.scope_risk,
      raw: scope.score,
      contribution: scope.score * config.weights.scope_risk * 100,
      notes: `severity: ${scope.severity}`,
    },
    {
      key: "change_size",
      name: "Change size",
      weight: config.weights.change_size,
      raw: changes.score,
      contribution: changes.score * config.weights.change_size * 100,
      notes: `${changes.totalChanges} total changes (${changes.band})`,
    },
    {
      key: "mergeability",
      name: "Mergeability",
      weight: config.weights.mergeability,
      raw: mergeability.score,
      contribution: mergeability.score * config.weights.mergeability * 100,
      notes: `state: ${mergeability.state}`,
    },
    {
      key: "freshness",
      name: "Freshness",
      weight: config.weights.freshness,
      raw: freshness.score,
      contribution: freshness.score * config.weights.freshness * 100,
      notes: `${freshness.diffHours.toFixed(1)}h since update`,
    },
    {
      key: "docs_tests",
      name: "Docs/tests",
      weight: config.weights.docs_tests,
      raw: docsTests.score,
      contribution: docsTests.score * config.weights.docs_tests * 100,
      notes: docsTests.matched ? "docs/tests updated" : "no docs/tests touched",
    },
    {
      key: "governance",
      name: "Governance",
      weight: config.weights.governance,
      raw: governance.score,
      contribution: governance.score * config.weights.governance * 100,
      notes: governance.violations.length
        ? `violations: ${governance.violations.join(", ")}`
        : "compliant",
    },
    {
      key: "reality_hooks",
      name: "Reality hooks",
      weight: config.weights.reality_hooks,
      raw: reality.score,
      contribution: reality.score * config.weights.reality_hooks * 100,
      notes: reality.matchedFiles.length
        ? `hook files: ${reality.matchedFiles.join(", ")}`
        : "no hooks detected",
    },
  ];

  const totalScore = breakdown.reduce((sum, item) => sum + item.contribution, 0);
  const labelName = selectLabel(config.labels, totalScore);

  const jsonPayload = {
    agent: "pr_score",
    repository: `${owner}/${repo}`,
    pull_number: prNumber,
    head_sha: pr.head.sha,
    score: formatScore(totalScore),
    breakdown: Object.fromEntries(
      breakdown.map((item) => [
        item.key,
        {
          weight: item.weight,
          raw: formatScore(item.raw),
          contribution: formatScore(item.contribution),
          notes: item.notes,
        },
      ])
    ),
    generated_at: new Date().toISOString(),
  };

  const commentBody = buildComment(totalScore, breakdown, labelName, jsonPayload);

  // Update label and comment in parallel (independent operations)
  await Promise.all([
    ensureLabel(token, owner, repo, prNumber, labelName),
    upsertComment(token, owner, repo, prNumber, commentBody),
  ]);

  // Output for GitHub Actions
  const finalScore = formatScore(totalScore);
  const executionTime = ((Date.now() - startTime) / 1000).toFixed(2);
  console.log(`Readiness score for PR #${prNumber}: ${finalScore} (computed in ${executionTime}s)`);
  console.log(
    `::notice title=PR Readiness Score::Score: ${finalScore}/100 | Label: ${labelName} | Time: ${executionTime}s`
  );

  // Write to GITHUB_OUTPUT if available
  const outputFile = process.env.GITHUB_OUTPUT;
  if (outputFile) {
    const outputs = [
      `score=${finalScore}`,
      `label=${labelName}`,
      `pr_number=${prNumber}`,
      `execution_time=${executionTime}`,
    ].join("\n");
    await fs.appendFile(outputFile, `${outputs}\n`);
  }

  // Write to GITHUB_STEP_SUMMARY if available
  const summaryFile = process.env.GITHUB_STEP_SUMMARY;
  if (summaryFile) {
    // Determine emoji based on score
    const emoji =
      finalScore >= 90 ? "🟢" : finalScore >= 80 ? "🟡" : finalScore >= 70 ? "🟠" : "🔴";
    const summaryLines = [
      `## ${emoji} PR Readiness Score: ${finalScore}/100`,
      "",
      `**Label:** \`${labelName}\` | **PR:** #${prNumber} | **Computed in:** ${executionTime}s`,
      "",
      "### Score Breakdown",
      "",
      "| Signal | Weight | Score | Contribution | Notes |",
      "| --- | --- | --- | --- | --- |",
      ...breakdown.map(
        (item) =>
          `| ${item.name} | ${(item.weight * 100).toFixed(0)}% | ${item.raw.toFixed(2)} | ${item.contribution.toFixed(2)} | ${item.notes || "-"} |`
      ),
      "",
      `**Total:** ${finalScore}/100`,
    ].join("\n");
    await fs.appendFile(summaryFile, `${summaryLines}\n`);
  }
})();
