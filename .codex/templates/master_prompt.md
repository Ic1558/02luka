# 🏆 02luka — Golden Master Prompt (for Codex in Cursor)

You are working inside the **02luka** monorepo on my local Google Drive Mirror.

## 0) Context Seed (read first)
- `.codex/PREPROMPT.md`
- `.codex/GUARDRAILS.md`
- `.codex/CONTEXT_SEED.md`
- `.codex/TASK_RECIPES.md`
- `f/ai_context/mapping.json` (resolver map)
- `g/tools/path_resolver.sh` (resolver)

## 1) Guardrails (non-negotiable)
- Resolve every path via: `bash g/tools/path_resolver.sh <namespace:key>` from repo root
- No absolute paths, no symlinks; never write to `a/ c/ o/ s/`
- Google Drive = Mirror: symlinks forbidden
- Small diffs; if unsure → create a query ticket in `human:inbox` and STOP
- Validate before commit; include CHANGE_ID + tags; append manifest + daily report

## 2) Defaults
- CONTEXT_ID = CU-2025-10-01
- CHANGE_ID  = CU-2025-10-01-boss-ui-api-v1
- TAGS       = #boss-api #boss-ui #resolver #preflight
- API base   = http://127.0.0.1:4000
- UI dev     = http://localhost:5173
- Validation = precommit (preflight + mapping guard; smoke if API/UI touched)

## 3) Confirm GOAL (echo back before editing)
Describe: files/endpoints/UI behavior, risks, validations, and planned diffs. Wait for OK.

## 4) Execute (after OK)
```bash
# implement minimal diffs
bash .codex/preflight.sh
bash g/tools/mapping_drift_guard.sh --validate
# if API/UI changed:
bash run/smoke_api_ui.sh

# record
# - Append run/change_units/${CONTEXT_ID}.yml
# - Append run/daily_reports/REPORT_$(date +%F).md

# commit & push (CLC gate runs)
git add -A
git commit -m "feat(api,ui): <summary> (CHANGE_ID: CU-2025-10-01-boss-ui-api-v1) #boss-api #boss-ui #resolver #preflight"
git push
# Optional: CLC_SKIP_SMOKE=1 git push  |  CLC_STRICT=1 git push
```

5) Resolver keys (examples)
	•	human:inbox → boss/inbox
	•	human:deliverables → boss/deliverables
	•	infra:path_resolver → g/tools/path_resolver.sh
	•	reports:runtime → run/
	•	status:system → run/system_status.v2.json
	•	codex:templates → .codex/templates/

6) Stop conditions

Any guardrail FAIL → stop, log to manifest, report logs. If API/UI offline, you may use CLC_SKIP_SMOKE=1 only with approval and record it.

7) Deliverables (show every run)
	•	Edited files list + diffs summary
	•	Validation results (preflight / drift_guard / smoke)
	•	Manifest snippet appended
	•	Daily report bullet
	•	Final commit message
