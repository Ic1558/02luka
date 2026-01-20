# Personal Assistant Flow v0.1

This flow provides a deterministic, fail-closed plan -> dry_run -> apply pipeline for professional document specs. It does not render templates or write outside the explicit output directory.

## Components
- `g/tools/pa_intake.py`: plan and dry_run entrypoint
- `g/tools/pa_apply.py`: apply verification using approve token
- `g/config/personal_assistant_paths.yaml`: allowlisted roots
- `tools/raycast/pa_plan.zsh`, `tools/raycast/pa_dry_run.zsh`, `tools/raycast/pa_apply.zsh`

## Allowlist
`g/config/personal_assistant_paths.yaml` defines:
- `project_roots`: allowed input file roots and target roots
- `output_roots`: allowed output directories for plan/dry_run/apply

All paths are expanded via `$HOME` and must be within these roots. Otherwise the CLI fails closed.

## Plan
Command:
```
python3 g/tools/pa_intake.py --mode plan --input-file examples/sample_project.json --output-dir /tmp/openwork_runs/run_001
```
Outputs:
- `plan.json` under `output-dir`
- stdout JSON summary

## Dry Run
Command:
```
python3 g/tools/pa_intake.py --mode dry_run --input-file examples/sample_project.json --output-dir /tmp/openwork_runs/run_001
```
Outputs (all under `output-dir`):
- `plan.json`
- `dry_run/doc_spec.json`
- `dry_run/validation.json`
- `dry_run/manifest.json`
- `approve_token.txt`

## Apply
Command:
```
python3 g/tools/pa_apply.py --approve-token /tmp/openwork_runs/run_001/approve_token.txt --output-dir /tmp/openwork_runs/run_001 --target-root /path/to/allowed/project
```
Outputs:
- `apply/apply_manifest.json`

Apply verifies the approve token by recomputing hashes from `plan.json` and dry-run artifacts. If anything mismatches, it fails closed.

## Determinism
- No timestamps or UUIDs are generated in the flow.
- Hashes use canonical JSON with sorted keys and UTF-8.

## Raycast
Each script accepts arguments and prints a short status line. Bind them as Script Commands in Raycast and assign hotkeys, passing arguments in the Raycast Script Command UI.

## Tests
```
pytest -q tests/test_personal_assistant_flow.py
```
