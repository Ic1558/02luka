# ChatGPT Native App Integration

This guide explains how to drive the **Luka Prompt Orchestrator** (`luka.html`) from the ChatGPT native desktop application while preserving full awareness of the local 02luka workspace.

## 1. Prerequisites
- Clone or sync the `02luka` repository locally.
- Ensure the local gateways that Luka expects are available (MCP Docker `5012`, MCP FS `8765`, Ollama `11434`).
- Install Python 3 so the repo can be served over HTTP.
- ChatGPT native app (macOS or Windows) with the "Browse"/"Custom interface" capability enabled.

## 2. Serve Luka Locally
Run Luka’s bundled helper to expose the HTML UI on `http://localhost:8080`:

```bash
cd /path/to/02luka
./run_local.sh
```

This uses `python3 -m http.server` under the hood. Keep the terminal window open while the ChatGPT app is connected.

> **Tip:** If port `8080` is busy, you can use `python3 -m http.server 9000` and then open `http://localhost:9000/luka.html` inside ChatGPT.

## 3. Wire the ChatGPT Native App
1. Open the ChatGPT app and start a new conversation.
2. Choose **Add Webpage / Open Link** (feature name varies by release).
3. Paste the served URL (e.g. `http://localhost:8080/luka.html`).
4. ChatGPT will now display Luka as an embedded panel. Interactions you perform in the Luka UI will be mirrored to ChatGPT, allowing you to delegate tasks through Luka while staying inside the native client.

If the app blocks `localhost`, toggle the "Allow local network" option in the ChatGPT app settings, or run `./tunnel` to expose a temporary HTTPS URL that you can paste instead.

## 4. Provide Local System Awareness
Once Luka is embedded, make sure every automation or delegated task can resolve real file paths and resources:

- **Context Seed Files:**
  - `.codex/CONTEXT_SEED.md`
  - `.codex/GUARDRAILS.md`
  - `.codex/TASK_RECIPES.md`
- **Prompt Templates:** `.codex/templates/master_prompt.md` (and companions).
- **Mapping Resolver:** `f/ai_context/mapping.json` enumerates logical namespaces.
- **Path Helper:** `g/tools/path_resolver.sh` translates keys such as `human:inbox` into concrete repo paths.

Share these paths or load their contents through Luka’s prompt library so ChatGPT understands the local topology before executing commands.

## 5. Retrieving Local Information
Inside Luka (and therefore inside ChatGPT), rely on the repo’s existing utilities instead of hardcoding paths:

```bash
# Resolve a path from a namespace key
bash g/tools/path_resolver.sh human:inbox

# Inspect current templates
ls .codex/templates

# Search the repo without full recursion
rg "CHANGE_ID" -n
```

These commands run in the workspace that Luka serves, so every response stays aligned with the repository layout that ChatGPT sees.

## 6. Delegation Workflow
1. **Start with the Master Prompt** – Insert the contents of `.codex/templates/master_prompt.md` via Luka’s prompt library.
2. **Confirm the GOAL** – Describe the task, affected files, and validation plan inside ChatGPT before editing.
3. **Use Luka for File Operations** – When ChatGPT needs a file, fetch it with Luka’s built-in file viewer or by issuing `cat`/`sed` commands from the prompt.
4. **Validate** – Run `.codex/preflight.sh` and any required scripts (`verify_system.sh`, `run/smoke_api_ui.sh`) directly from the Luka shell before committing.
5. **Commit & Summarise** – Follow the commit conventions in `.codex/templates/master_prompt.md` and mirror the summary back into ChatGPT.

## 7. Troubleshooting
| Symptom | Fix |
|---------|-----|
| ChatGPT cannot load `localhost` | Enable local network access in the app settings or expose Luka via `./tunnel`. |
| Luka loads but cannot reach gateways | Start the services (MCP Docker, FS MCP, Ollama) or update the gateway URLs in `index.html` if you are on non-default ports. |
| Prompt library shows "Unable to load" | Confirm you are serving the repo root (not a subdirectory) so `.codex/templates/master_prompt.md` is accessible. |

Once the setup above is in place, every Luka prompt executed inside ChatGPT has access to the same local information as when running Luka in a standalone browser.
