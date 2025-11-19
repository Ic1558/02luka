# Gemini Dry-Run Validation Layer (2025-11-19)

## Purpose

This document describes the mobile-safe Gemini dry-run validation layer.
It verifies routing metadata, handler importability, and minimal payload
shape **without executing any real Gemini work** or touching locked zones.

## Workflow

1. Run the dry-run script:
   ```bash
   zsh g/tools/gemini_dryrun_test.zsh
   ```
2. The script writes a disposable work order under `g/tests/gemini_dryrun/`.
3. Schema validation ensures:
   - `engine: gemini`
   - `routing.path: [liam, kim, dispatcher, gemini_handler]`
   - `locked_zone_allowed: false`
   - Minimal `input.instructions` and `input.target_files` are present.
4. Handler validation checks that `bridge.handlers.gemini_handler` exports
   `handle_wo`, `handle`, and `GeminiHandler`, and that the minimal task
   dictionary matches the handler contract.

## Expected Output Markers

- `DRY-RUN: HANDLER_IMPORT_OK` — Gemini handler imports successfully.
- `DRY-RUN: ROUTING_OK` — Routing metadata and locked-zone guardrails verified.
- `DRY-RUN: HANDLER_OK` — Minimal task dictionary is valid for the handler.

## Safety Notes

- No runtime changes or connector calls are made.
- Targets avoid locked zones (`/CLC`, `/CLS`, `AI:OP-001`, `bridge/core`).
- Generated files stay under `g/tests/gemini_dryrun/` and `logs/`.

## Troubleshooting

| Symptom | Check | Fix |
| --- | --- | --- |
| Missing `yq`/`yaml` module errors | Ensure Python has `pyyaml` (bundled in repo env) | `pip install pyyaml` if missing |
| `DRY-RUN: ROUTING_OK` missing | Verify `routing.path` matches `liam → kim → dispatcher → gemini_handler` | Re-run script after editing WO template |
| `DRY-RUN: HANDLER_OK` missing | Confirm `input.instructions` and `target_files` are populated | Update WO template to include minimal fields |

## Next Steps

- If all markers are present, the Gemini routing integration PR (#381) can
  proceed to real work orders.
- Keep this layer in place for future Gemini changes to avoid locked-zone
  leakage and handler regressions.
