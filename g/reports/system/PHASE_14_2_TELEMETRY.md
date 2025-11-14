# Phase 14.2 – Unified SOT Telemetry Schema

**Classification:** Strategic Integration Patch (SIP)  
**Deployed by:** CLS (Cognitive Local System Orchestrator)  
**Maintainer:** GG Core (02LUKA Automation)  
**Version:** v1.2-telemetry  
**Revision:** r1  
**Phase:** 14.2 – Unified SOT Telemetry  
**Timestamp:** 2025-11-06 05:11:39 +0700  
**WO-ID:** WO-251107-PHASE-14-RAG-UNIFICATION  
**Verified by:** CDC / CLC / GG SOT Audit Layer  
**Status:** Production ready  
**Evidence Hash:** 4a2ea85ade2390e6df12890136dc1ce042816009e42c7f0a52c0439cd7210ccd

## Summary

Unifies CLS / GG / CDC telemetry headers into a single canonical format and materializes `g/telemetry_unified/unified.jsonl` with a manifest.

## Artifacts

- `config/telemetry_unified.yaml` – mapping + rules
- `tools/telemetry_sync.zsh` – converter / normalizer
- `g/telemetry_unified/unified.jsonl` – unified output
- `g/telemetry_unified/manifest.json` – counts + timestamp

## Verification

- Run: `~/02luka/tools/telemetry_sync.zsh`
- Check: `tail -n+1 ~/02luka/g/telemetry_unified/manifest.json`
- Spot-check: `head -n 5 ~/02luka/g/telemetry_unified/unified.jsonl | jq '.'`

## Notes

- Principle: "configuration is data → edit the structure, not the text".
- Idempotent: safe to rerun; output overwritten deterministically.

