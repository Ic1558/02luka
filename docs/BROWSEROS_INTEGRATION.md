# BrowserOS Integration Guide

This document describes the BrowserOS action bridge that powers MCP tools, Redis fan-out, CLI fallback, and GG telemetry. It extends the Phase 7.6 stack (MCP → Redis → Shell → Merge → Perf logs) with a browser automation worker.

## Components

| Layer | Path | Description |
| --- | --- | --- |
| MCP Tools | `knowledge/mcp/browseros.cjs` | Defines `browseros.*` MCP tools, handles request/response via Redis, and offers a direct execution mode (`--direct`). |
| Redis Worker | `knowledge/bridge/browseros_worker.cjs` | Listens on `ai.action.request`, enforces policy, invokes BrowserOS HTTP IPC, publishes results to `ai.action.result`, and writes telemetry. |
| CLI Fallback | `tools/browseros.sh` | Sends JSON payloads to the MCP module in direct mode. Useful for manual debugging. |
| Telemetry | `knowledge/util/web_actions_log.cjs` | Appends `g/reports/web_actions.jsonl` and `g/reports/query_perf.jsonl`, tracks quotas, allowlists, and kill-switch state. |
| Safety Utilities | `knowledge/util/redact.cjs` | Masks emails, tokens, UUIDs, and card numbers before logs are written. |
| Redis Client | `knowledge/util/redis_client.cjs` | Lightweight RESP client (no external dependency) shared by the MCP module and worker. |
| Policy Files | `02luka/config/browseros.allow`, `02luka/config/browseros.off` | Domain allowlist and kill-switch toggles. |

## MCP Usage

```jsonc
{
  "tool": "browseros.workflow",
  "params": {
    "plan": [
      { "op": "navigate", "url": "https://example.com" },
      { "op": "type", "selector": "#q", "text": "Phase 7.6", "enter": true },
      { "op": "extract", "selectors": ["h1", ".summary"] }
    ],
    "allowDomains": ["example.com"],
    "timeoutMs": 45000
  }
}
```

The MCP runtime sends this payload to `knowledge/mcp/browseros.cjs`, which publishes the request to Redis (`ai.action.request`). The worker consumes the request, performs policy checks, executes the workflow against BrowserOS, logs the run, and publishes the response on `ai.action.result`.

### CLI

```
echo '{"tool":"browseros.workflow","params":{"plan":[{"op":"navigate","url":"https://example.com"}],"allowDomains":["example.com"]}}' \
  | tools/browseros.sh
```

This pipes the payload to the MCP module in `--direct` mode. The command respects the same kill-switch, quota, and allowlist checks and writes to the telemetry logs.

Set `BROWSEROS_CLI_CALLER` to override the caller label in logs:

```
BROWSEROS_CLI_CALLER=Mary tools/browseros.sh '{"tool":"browseros.navigate","params":{"url":"https://news.ycombinator.com","allowDomains":["news.ycombinator.com"]}}'
```

## Redis Channels

- Requests: `ai.action.request`
- Results: `ai.action.result`

The worker is safe to restart; each message is handled independently and publishes a correlated result (`id` matches the request ID).

## BrowserOS HTTP Endpoint

The worker and CLI expect a local HTTP endpoint that accepts `POST` payloads of the form `{ "tool": "browseros.workflow", "params": { ... } }`. Configure the target with `BROWSEROS_ENDPOINT` (default `http://127.0.0.1:8234/api/action`).

## Governance and Telemetry

Every invocation produces a sanitized JSON line at `g/reports/web_actions.jsonl` and a matching perf entry at `g/reports/query_perf.jsonl`. Entries include:

- `ts`, `id`, `caller`, `tool`
- Duration (`ms`), success flag, domain summary
- Sanitized result or error
- Metadata (blocked domains, quota usage, kill-switch source)

These logs feed the rollup scripts:

- `knowledge/web_actions_rollup.cjs` → `g/reports/web_actions_daily_YYYYMMDD.{json,csv}`
- `knowledge/web_actions_rollup_weekly.cjs` → `g/reports/web_actions_weekly_YYYYWW.{json,csv}`

## Safety Controls

- **Allowlist:** `02luka/config/browseros.allow` (comments with `#`). Supports exact domains (`example.com`), suffixes (`.example.com`), and simple wildcards (`*.gov`).
- **Kill-switch:** create `02luka/config/browseros.off` to reject all requests.
- **Quota:** `02luka/config/browseros.quota.json` (optional) overrides hourly per-caller limits. Defaults: `CLS` 200, `Mary/Paula/Lisa` 100, wildcard 60.
- **Redaction:** logs automatically mask email addresses, UUIDs, credit cards, and long tokens.
- **Dry-run:** `validateOnly: true` skips HTTP execution and records a dry-run entry.

## LaunchAgent

`g/fixed_launchagents/com.02luka.browseros.worker.plist` launches the worker under macOS launchd. It ensures the worker restarts and logs to `~/Library/Logs/02luka/browseros_worker.{out,err}`.

Example entry:

```xml
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>com.02luka.browseros.worker</string>
    <key>ProgramArguments</key>
    <array>
      <string>/bin/bash</string>
      <string>-lc</string>
      <string>cd "$HOME/dev/02luka-repo" &amp;&amp; REDIS_URL='redis://:changeme-02luka@127.0.0.1:6379/0' BROWSEROS_ENDPOINT='http://127.0.0.1:8234/api/action' exec node knowledge/bridge/browseros_worker.cjs</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <dict>
      <key>SuccessfulExit</key>
      <false/>
    </dict>
    <key>StandardOutPath</key>
    <string>$HOME/Library/Logs/02luka/browseros_worker.out</string>
    <key>StandardErrorPath</key>
    <string>$HOME/Library/Logs/02luka/browseros_worker.err</string>
  </dict>
</plist>
```

Adjust the Redis URL, BrowserOS endpoint, and repo path as needed.

## Troubleshooting

- Run `node knowledge/mcp/browseros.cjs --selftest` to verify allowlist/quota checks.
- Use `node knowledge/mcp/browseros.cjs --describe` to inspect tool metadata.
- Check `g/reports/web_actions.jsonl` for recent activity.
- Ensure `browseros.off` is absent and the target domain appears in `browseros.allow`.
