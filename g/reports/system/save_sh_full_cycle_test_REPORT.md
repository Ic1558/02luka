# System Report — `tools/save.sh` Full-Cycle Harness

**Date:** 2025-11-15  
**Author:** Tools & Observability  
**Context:** Validate the refreshed `tools/save.sh` contract, MLS hook, and lane-specific harnesses.

---

## Overview
- Added structured logging + opt-in MLS telemetry to `tools/save.sh`.
- Built dedicated `full_cycle_cls.zsh` (Cursor lane) and `full_cycle_clc.zsh` (Claude lane) harnesses.
- Verified both harnesses on the work branch with MLS auto-recording enabled.

---

## Execution Log

| Lane | Command | Exit | Git Tree Delta | MLS Ledger | Snapshot Log |
| --- | --- | --- | --- | --- | --- |
| CLS | `tools/save_sh/full_cycle_cls.zsh` | `0` | No changes (status stayed dirty due to expected work-in-progress files) | `mls/ledger/2025-11-16.jsonl` contains `"save.sh full-cycle (CLS)"` entries | `logs/save_sh/tests/full_cycle_cls_20251115_222930.log` |
| CLC | `tools/save_sh/full_cycle_clc.zsh` | `0` | No changes (same working tree) | `mls/ledger/2025-11-16.jsonl` contains `"save.sh full-cycle (CLC)"` entries | `logs/save_sh/tests/full_cycle_clc_20251115_222934.log` |

Notes:
- Harnesses filter out ledger/log artifacts when asserting git stability.
- MLS entries tagged `lane:CLS` / `lane:CLC` with summary pointer to the generated snapshot log.

---

## MLS Evidence
```
$ tail -n 3 mls/ledger/2025-11-16.jsonl
… "title":"save.sh full-cycle (CLS)" …
… "title":"save.sh full-cycle (CLS)" …
… "title":"save.sh full-cycle (CLC)" …
```
Each record references `logs/save_sh/save_<timestamp>.log`, confirming opt-in telemetry works end-to-end.

---

## Follow-Ups
- 📌 Optional: wire the harnesses into CI later once automation policy allows read-only git operations.
- 📌 Consider rotating / pruning ledger data periodically (separate governance task).

**Status:** ✅ Full-cycle harness validated for both lanes.
